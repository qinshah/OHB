#!/usr/bin/env python3
"""窗口尺寸矩阵断言助手：解析布局树 JSON，判定列数 / 导航形态 / 视频页分栏。

被 scripts/window-matrix.sh 调用，也可单独用于人工复核：
  python3 scripts/window_layout_check.py home  --layout home_layout.json  --rect-w 1412 --density 1.25
  python3 scripts/window_layout_check.py video --layout video_layout.json --rect-w 1612 --density 1.25

支持两种布局树格式：`devecocli ui layout --format json`（bounds 为数组）与
`hdc shell uitest dumpLayout`（attributes + 字符串 bounds），便于对比排查。
退出码 0 = 断言通过，1 = 失败；stdout 打印一行 JSON 结论供脚本记录。
断点与列数映射须与 entry/src/main/ets/common/window/WindowLayout.ets 保持一致。
"""
import argparse
import json
import re
import sys

MD_MIN = 600
LG_MIN = 840
XL_MIN = 1200
CARD_MAX_WIDTH = 240


def grid_columns(width_vp: float) -> int:
    if width_vp >= XL_MIN:
        return 6
    if width_vp >= LG_MIN:
        return 4
    if width_vp >= MD_MIN:
        return 3
    return 2


def parse_bounds(raw):
    if isinstance(raw, (list, tuple)) and len(raw) == 4:
        return tuple(int(v) for v in raw)
    m = re.findall(r'-?\d+', raw or '')
    if len(m) != 4:
        return None
    return tuple(int(v) for v in m)


def normalize(node):
    """统一为 {id, type, bounds(tuple), children[...]}"""
    attrs = node.get('attributes', node)
    return {
        'id': attrs.get('id', '') or '',
        'type': attrs.get('type', '') or '',
        'bounds': parse_bounds(attrs.get('bounds')),
        'text': attrs.get('text', '') or '',
        'children': [normalize(c) for c in node.get('children', [])],
    }


def walk(node):
    yield node
    for child in node['children']:
        yield from walk(child)


def load(path):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    # CLI 会在 JSON 前打印进度行（"- Dumping layout…"），从首个括号开始解析
    opens = [p for p in (text.find('['), text.find('{')) if p != -1]
    data = json.loads(text[min(opens):])
    items = data if isinstance(data, list) else [data]
    return [normalize(n) for n in items]


def find_by_id(roots, wanted):
    for root in roots:
        for node in walk(root):
            if node['id'] == wanted:
                return node
    return None


def first_row(items):
    """首行 = top 与最小 top 相差 <= 4px 的项；列数取其不同 x 起点数"""
    if not items:
        return 0, 0
    top = min(b[1] for b in items)
    row = [b for b in items if abs(b[1] - top) <= 4]
    return len({b[0] for b in row}), max(b[2] - b[0] for b in row)


def first_row_cards(items):
    """首行卡片「渲染宽度」：ListItem → Column → 直接子节点里最宽者（避开 List 的列间距/内边距）"""
    if not items:
        return 0
    top = min(b['bounds'][1] for b in items)
    row = [b for b in items if abs(b['bounds'][1] - top) <= 4]
    widths = []
    for item in row:
        inner = [c['bounds'][2] - c['bounds'][0] for c in _descendant_columns(item)
                 if c['bounds']]
        if inner:
            widths.append(max(inner))
    return max(widths) if widths else 0


def _descendant_columns(item):
    """取 ListItem 内第一个 Column 的直接子节点（卡片内容层）"""
    stack = list(item['children'])
    while stack:
        node = stack.pop(0)
        if node['type'] == 'Column':
            return node['children']
        stack.extend(node['children'])
    return []


def check_home(roots, rect_w, density):
    feed = find_by_id(roots, 'home_feed')
    if feed is None:
        return fail('home_feed 节点不存在（首页未加载或 id 丢失）')
    items = [c for c in feed['children'] if c['type'] == 'ListItem' and c['bounds']]
    columns, slot_px = first_row([c['bounds'] for c in items])
    card_px = first_row_cards(items)
    width_vp = rect_w / density
    expected = grid_columns(width_vp)
    wide = width_vp >= LG_MIN
    rail = find_by_id(roots, 'home_side_rail')
    bar = find_by_id(roots, 'home_partition_bar')
    problems = []
    if columns != expected:
        problems.append(f'列数 {columns} != 期望 {expected}（窗口 {width_vp:.1f}vp）')
    slot_vp = slot_px / density
    card_vp = card_px / density
    if card_vp > CARD_MAX_WIDTH + 1:
        problems.append(f'卡片渲染宽 {card_vp:.1f}vp 超过 CARD_MAX_WIDTH({CARD_MAX_WIDTH})')
    if wide and rail is None:
        problems.append('宽屏应出现 home_side_rail')
    if wide and bar is not None:
        problems.append('宽屏不应出现 home_partition_bar')
    if not wide and rail is not None:
        problems.append('窄屏不应出现 home_side_rail')
    if not wide and bar is None:
        problems.append('窄屏应出现 home_partition_bar')
    return verdict(problems, {
        'widthVp': round(width_vp, 1), 'columns': columns, 'expectedColumns': expected,
        'slotWidthVp': round(slot_vp, 1), 'cardWidthVp': round(card_vp, 1),
        'sideRail': rail is not None,
        'partitionBar': bar is not None
    })


def collect_times(node):
    """播放器子树里的 mm:ss 文本（依次为当前时间、总时长）"""
    found = []

    def rec(n):
        if n['type'] == 'Text' and re.fullmatch(r'\d{1,2}:\d{2}', n['text']):
            found.append(n['text'])
        for c in n['children']:
            rec(c)

    rec(node)
    return found


def check_video(roots, rect_w, density):
    width_vp = rect_w / density
    wide = width_vp >= LG_MIN
    player = find_by_id(roots, 'video_player')
    related = find_by_id(roots, 'video_related')
    comments = find_by_id(roots, 'video_comments')
    if player is None:
        return fail('video_player 节点不存在（未进入视频页）')
    problems = []
    if wide:
        if related is None or comments is None:
            problems.append(f'宽屏分栏缺失：related={related is not None} comments={comments is not None}')
        else:
            r, c, p = related['bounds'], comments['bounds'], player['bounds']
            if r[2] > c[0]:
                problems.append(f'推荐与评论 x 区间重叠：{r} vs {c}')
            if p[3] > r[1]:
                problems.append(f'推荐区未在播放器下方：player={p} related={r}')
    elif related is not None and comments is not None:
        problems.append('窄屏不应同时出现 video_related 与 video_comments（应为堆叠 Tabs）')
    times = collect_times(player)
    if len(times) < 2:
        problems.append(f'播放器未显示时间文本（times={times}）')
    elif times[1] == '00:00':
        problems.append(f'播放器总时长仍为 00:00，取流/起播未完成（times={times}）')
    return verdict(problems, {
        'widthVp': round(width_vp, 1), 'wide': wide, 'player': player['bounds'],
        'playerTimes': times[:2],
        'related': related['bounds'] if related else None,
        'comments': comments['bounds'] if comments else None
    })


def verdict(problems, detail):
    return not problems, {'ok': not problems, 'detail': detail, 'problems': problems}


def fail(msg):
    return False, {'ok': False, 'detail': {}, 'problems': [msg]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('kind', choices=['home', 'video'])
    ap.add_argument('--layout', required=True)
    ap.add_argument('--rect-w', required=True, type=int)
    ap.add_argument('--density', type=float, default=1.25)
    args = ap.parse_args()

    roots = load(args.layout)
    fn = check_home if args.kind == 'home' else check_video
    ok, report = fn(roots, args.rect_w, args.density)
    print(json.dumps(report, ensure_ascii=False))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
