#!/usr/bin/env bash
# 实时窄↔宽切换回归：拖窗口边缘改变尺寸（不重启应用），断言
#   1) 选中分区不丢（首页首屏第一张卡片标题不变）
#   2) 不重复请求首屏（hilog 里 `feed loadFirst` 计数不变）
#   3) 侧边导航 / 顶部分区栏随宽度互斥切换
#   4) 视频页切换形态不丢播放进度（播放器时间文本继续前进）
#
# 用法：scripts/window-live-toggle.sh [-d <serial>] [-o out/window-live]
# 退出码：0 = 全部通过；1 = 有断言失败。
set -uo pipefail

BUNDLE=com.dev4harmony.ohb
ABILITY=EntryAbility
WIN_MATCH=ohb
SERIAL=${SERIAL:-192.168.43.11:10178}
OUT=out/window-live
HDC=${HDC:-$(command -v hdc || echo /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc)}

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device) SERIAL=$2; shift 2 ;;
    -o|--out)    OUT=$2; shift 2 ;;
    -h|--help)   sed -n '2,10p' "$0"; exit 0 ;;
    *)           echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"; rm -f "$OUT"/*.json
PROBLEMS=()
log()  { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*"; }
bad()  { PROBLEMS+=("$1"); log "FAIL $1"; }
sh_exec() { "$HDC" -t "$SERIAL" shell "$@"; }

rect() {
  sh_exec "hidumper -s WindowManagerService -a '-a'" 2>/dev/null | grep -m1 "^${WIN_MATCH}" \
    | sed -n 's/.*\[[ ]*\([0-9-]*\)[ ]*\([0-9-]*\)[ ]*\([0-9-]*\)[ ]*\([0-9-]*\)[ ]*\].*/\1 \2 \3 \4/p'
}
wid() {
  devecocli ui window list --device "$SERIAL" --format json 2>/dev/null \
    | python3 -c "
import json,sys
t=sys.stdin.read()
for w in json.loads(t[t.find('['):]):
    if str(w.get('name','')).startswith('$WIN_MATCH'):
        print(w['id']); break
"
}
# layout <dest> ：抓取当前布局树
layout() { devecocli ui layout --device "$SERIAL" --format json --mode full --window "$(wid)" > "$1" 2>/dev/null; }
# drag_width <目标宽px> ：拖窗口右边缘到目标宽度
drag_width() {
  local target=$1 r x y w h edge
  r=$(rect); x=$(echo "$r" | awk '{print $1}'); y=$(echo "$r" | awk '{print $2}'); w=$(echo "$r" | awk '{print $3}'); h=$(echo "$r" | awk '{print $4}')
  edge=$((x + w - 2))
  devecocli ui drag "$edge" $((y + h / 2)) "$((x + target - 2))" $((y + h / 2)) --device "$SERIAL" --speed 4000 >/dev/null 2>&1
  sleep 2
}
# 首页首张卡片标题（取该卡片里最长的文本，避开时长/播放量等短文本）
first_title() {
  python3 - "$1" <<'PY'
import json, sys
t = open(sys.argv[1], encoding='utf-8').read()
o = min(p for p in (t.find('['), t.find('{')) if p != -1)
data = json.loads(t[o:])
texts = []
def collect(n):
    for c in n.get('children', []):
        if c.get('type') == 'Text' and c.get('text'):
            texts.append(c['text'])
        collect(c)
def walk(n):
    if n.get('id') == 'home_feed' and not texts:
        for c in n.get('children', []):
            if c.get('type') == 'ListItem':
                collect(c); return
    for c in n.get('children', []):
        walk(c)
for r in (data if isinstance(data, list) else [data]):
    walk(r)
print(max(texts, key=len) if texts else '')
PY
}
has_id() { grep -q "\"id\": \"$1\"" "$2"; }
# 播放器时间文本（mm:ss）
player_time() {
  python3 - "$1" <<'PY'
import json, re, sys
t = open(sys.argv[1], encoding='utf-8').read()
o = min(p for p in (t.find('['), t.find('{')) if p != -1)
data = json.loads(t[o:])
found = []
def walk(n):
    if n.get('id') == 'video_player':
        def collect(m):
            txt = m.get('text') or ''
            if re.fullmatch(r'\d{1,2}:\d{2}', txt):
                found.append(txt)
            for c in m.get('children', []):
                collect(c)
        collect(n)
    for c in n.get('children', []):
        walk(c)
for r in (data if isinstance(data, list) else [data]):
    walk(r)
print(found[0] if found else '')
PY
}
to_secs() { local m=${1%%:*} s=${1##*:}; echo $((10#$m * 60 + 10#$s)); }
# hilog 是环形缓冲，跑久了旧行会被挤掉导致计数"变小"；先清缓冲再按绝对值断言
reset_logs() { sh_exec "hilog -r" >/dev/null 2>&1; sleep 1; }
count_of() { sh_exec "hilog -x | grep -c '$1'" 2>/dev/null | tr -d '\r'; }

log "设备 $SERIAL ｜输出 $OUT"
sh_exec "aa force-stop $BUNDLE" >/dev/null 2>&1
sh_exec "aa start -a $ABILITY -b $BUNDLE --ps ohbTestWindow 1400x900" >/dev/null 2>&1
sleep 6

# 选中「热门」分区（侧边栏第 3 项）
devecocli ui click 60 193 --device "$SERIAL" >/dev/null 2>&1
sleep 4
layout "$OUT/step1_wide.json"
if ! has_id home_side_rail "$OUT/step1_wide.json" || has_id home_partition_bar "$OUT/step1_wide.json"; then
  bad '宽窗(1400)应为侧边导航且顶部分区栏不可见'
fi
reset_logs
title_wide=$(first_title "$OUT/step1_wide.json")
count_before=$(count_of 'feed loadFirst')
log "宽窗 热门首卡：${title_wide} ｜feed loadFirst 计数 $count_before"
[ -n "$title_wide" ] || bad '宽窗未取到首卡标题'

drag_width 700
layout "$OUT/step2_narrow.json"
rect_now=$(rect); log "拖窄后 WindowRect：$(echo "$rect_now" | awk '{print $3}')x$(echo "$rect_now" | awk '{print $4}')"
if ! has_id home_partition_bar "$OUT/step2_narrow.json" || has_id home_side_rail "$OUT/step2_narrow.json"; then
  bad '窄窗(700)应回到顶部分区栏且侧边导航不可见'
fi
title_narrow=$(first_title "$OUT/step2_narrow.json")
count_narrow=$(count_of 'feed loadFirst')
log "窄窗首卡：${title_narrow} ｜feed loadFirst 计数 $count_narrow"
[ "$title_wide" = "$title_narrow" ] || bad "窄窗选中分区丢失：$title_wide → $title_narrow"
[ "$count_before" = "$count_narrow" ] || bad "窄窗重复请求首屏：$count_before → $count_narrow"

drag_width 1400
layout "$OUT/step3_back_wide.json"
if ! has_id home_side_rail "$OUT/step3_back_wide.json" || has_id home_partition_bar "$OUT/step3_back_wide.json"; then
  bad '回到宽窗未恢复侧边导航'
fi
title_back=$(first_title "$OUT/step3_back_wide.json")
count_back=$(count_of 'feed loadFirst')
log "回到宽窗首卡：${title_back} ｜feed loadFirst 计数 $count_back"
[ "$title_wide" = "$title_back" ] || bad "来回切换后选中分区丢失：$title_wide → $title_back"
[ "$count_before" = "$count_back" ] || bad "来回切换后重复请求首屏：$count_before → $count_back"

# 视频页：窄→宽切换不丢播放进度（评论计数从这里重新起算）
reset_logs
drag_width 700
sleep 1
center=$(python3 - "$OUT/step3_back_wide.json" <<'PY'
import json, sys
t = open(sys.argv[1], encoding='utf-8').read()
o = min(p for p in (t.find('['), t.find('{')) if p != -1)
data = json.loads(t[o:])
box = []
def walk(n):
    if n.get('id') == 'home_feed' and not box:
        for c in n.get('children', []):
            b = c.get('bounds')
            if c.get('type') == 'ListItem' and b:
                box.append(b); return
    for c in n.get('children', []):
        walk(c)
for r in (data if isinstance(data, list) else [data]):
    walk(r)
if box:
    x1, y1, x2, y2 = box[0]
    print((x1 + x2) // 2, (y1 + y2) // 2)
PY
)
[ -n "$center" ] || bad '取不到首页卡片坐标'
devecocli ui click ${center} --device "$SERIAL" >/dev/null 2>&1
sleep 8
layout "$OUT/step4_video_narrow.json"
if has_id video_comments "$OUT/step4_video_narrow.json"; then
  bad '窄窗视频页不应出现 video_comments（应为堆叠 Tabs）'
fi
t1=$(player_time "$OUT/step4_video_narrow.json")
comment_before=$(count_of 'comment loadOnce')
log "窄窗视频页时间：${t1} ｜comment loadOnce 计数 $comment_before"
[ -n "$t1" ] || bad '窄窗未取到播放器时间文本'

drag_width 1400
sleep 3
layout "$OUT/step5_video_wide.json"
if ! has_id video_related "$OUT/step5_video_wide.json" || ! has_id video_comments "$OUT/step5_video_wide.json"; then
  bad '宽窗视频页未出现左右分栏（video_related / video_comments）'
fi
t2=$(player_time "$OUT/step5_video_wide.json")
comment_after=$(count_of 'comment loadOnce')
log "宽窗视频页时间：${t2} ｜comment loadOnce 计数 $comment_after"
[ "$comment_after" -le $((comment_before + 1)) ] || bad "切宽后评论重复加载：$comment_before → $comment_after"
if [ -n "$t1" ] && [ -n "$t2" ]; then
  s1=$(to_secs "$t1"); s2=$(to_secs "$t2")
  [ "$s2" -ge "$s1" ] || bad "切宽后播放进度回退：$t1 → $t2"
  [ "$s2" -gt 0 ] || bad "切宽后播放被重置到 00:00"
fi

sh_exec "aa force-stop $BUNDLE" >/dev/null 2>&1

if [ ${#PROBLEMS[@]} -eq 0 ]; then
  log '实时切换回归全部通过'
  exit 0
fi
printf '%s\n' "${PROBLEMS[@]}" > "$OUT/failures.txt"
log "失败 ${#PROBLEMS[@]} 项，明细 $OUT/failures.txt"
exit 1
