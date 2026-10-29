#!/usr/bin/env bash
# 窗口尺寸矩阵：逐个尺寸启动应用、采集截图 + 布局树 + WindowRect，并断言首页列数与视频页分栏。
#
# 用法：
#   scripts/window-matrix.sh                       # 默认 5 档宽度 + 视频页检查
#   scripts/window-matrix.sh -s "900x900 1600x900" # 只跑指定尺寸
#   scripts/window-matrix.sh --no-video            # 只采首页
#   scripts/window-matrix.sh -o out/matrix-run2 -d <serial> --density 1.25 --tolerance 40
#   scripts/window-matrix.sh --extra-params "--ps ohbShell index"   # 强制选入口壳（index|hds）
#   scripts/window-matrix.sh --no-inject -s 1300x900             # 只用拖拽兜底通道调窗口
#
# 尺寸注入依赖调试构建的 WindowTestHook（aa start --ps ohbTestWindow WxH，仅 DEBUG 生效）；
# 注意：请求尺寸是「内容尺寸」，超过屏幕会让窗口溢出到屏外。要采集系统最大化那一档，
# 用 `--no-inject -s 1920x1080 --decoration 0 --tolerance 0`（冷启动默认即最大化）。
# 若实测 WindowRect 与目标宽偏差超过 --tolerance，则回落到 `devecocli ui drag` 拖窗口右边缘，
# 再次校验；仍不达标就把该尺寸记为失败并继续跑下一档。
#
# 退出码：0 = 全部通过；1 = 有失败项（明细见 <out>/failures.txt）。
set -uo pipefail

BUNDLE=com.dev4harmony.ohb
ABILITY=EntryAbility
WIN_MATCH=ohb
SERIAL=${SERIAL:-192.168.43.11:10178}
SIZES="400x900 700x900 900x900 1300x900 1600x900"
OUT=out/window-matrix
DENSITY=1.25
TOLERANCE=40
# 窗口装饰边（outer rect 比 resize 请求的内容尺寸多出的像素）
DECORATION=12
# 不传尺寸注入参数（用于单独验证拖拽兜底通道）
NO_INJECT=0
WITH_VIDEO=1
EXTRA_PARAMS=''
HDC=${HDC:-$(command -v hdc || echo /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc)}
HERE=$(cd "$(dirname "$0")" && pwd)

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device)   SERIAL=$2; shift 2 ;;
    -s|--sizes)    SIZES=$2; shift 2 ;;
    -o|--out)      OUT=$2; shift 2 ;;
    --density)     DENSITY=$2; shift 2 ;;
    --tolerance)   TOLERANCE=$2; shift 2 ;;
    --decoration)  DECORATION=$2; shift 2 ;;
    --no-inject)   NO_INJECT=1; shift ;;
    --no-video)    WITH_VIDEO=0; shift ;;
    --extra-params) EXTRA_PARAMS=$2; shift 2 ;;
    -h|--help)     sed -n '2,16p' "$0"; exit 0 ;;
    *)             echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

FAILURES=()
FAILED_SIZES=()

log()  { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*"; }
fail() { FAILURES+=("$1: $2"); FAILED_SIZES+=("$1"); log "FAIL $1 — $2"; }

# 设备连接自愈：TCP 掉线时 kill/start/tconn 一次
reconnect() {
  log "重连 $SERIAL"
  echo "$CUR_SPEC reconnect" >> "$OUT/reconnects.txt"
  "$HDC" kill >/dev/null 2>&1
  sleep 1
  "$HDC" start >/dev/null 2>&1
  sleep 1
  "$HDC" tconn "$SERIAL" >/dev/null 2>&1
  sleep 1
}

sh_exec() { "$HDC" -t "$SERIAL" shell "$@"; }

# 读 ohb 窗口的 WindowRect：输出 "x y w h"
window_rect() {
  sh_exec "hidumper -s WindowManagerService -a '-a'" 2>/dev/null \
    | grep -m1 "^${WIN_MATCH}" \
    | sed -n 's/.*\[[ ]*\(-\{0,1\}[0-9]*\)[ ]*\(-\{0,1\}[0-9]*\)[ ]*\(-\{0,1\}[0-9]*\)[ ]*\(-\{0,1\}[0-9]*\)[ ]*\].*/\1 \2 \3 \4/p'
}

window_id() {
  devecocli ui window list --device "$SERIAL" --format json 2>/dev/null \
    | python3 -c "
import json,sys
t=sys.stdin.read(); i=t.find('[')
for w in json.loads(t[i:]):
    if str(w.get('name','')).startswith('$WIN_MATCH'):
        print(w['id']); break
"
}

# 采集布局树到文件；等待包含指定 id（超时返回 1）
wait_layout() {
  local wid=$1 want=$2 dest=$3 deadline=$((SECONDS + 30))
  while [ $SECONDS -lt $deadline ]; do
    devecocli ui layout --device "$SERIAL" --format json --mode full --window "$wid" > "$dest" 2>/dev/null
    if [ -s "$dest" ] && grep -q "\"id\": \"$want\"" "$dest"; then return 0; fi
    sleep 2
  done
  return 1
}

# 从布局树里取 home_feed 首个 ListItem 的中心点（"x y"），用于点进视频页
first_card_center() {
  python3 - "$1" <<'PY'
import json, sys
text = open(sys.argv[1], encoding='utf-8').read()
opens = [p for p in (text.find('['), text.find('{')) if p != -1]
data = json.loads(text[min(opens):])
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
}

run_size() {
  local spec=$1 req_w req_h dir rect rw rh wid expected delta
  CUR_SPEC=$spec
  req_w=${spec%x*}; req_h=${spec#*x}
  dir="$OUT/$spec"
  mkdir -p "$dir"

  local inject="--ps ohbTestWindow $spec"
  [ "$NO_INJECT" = "1" ] && inject=''

  sh_exec "aa force-stop $BUNDLE" >/dev/null 2>&1
  sh_exec "aa start -a $ABILITY -b $BUNDLE $inject $EXTRA_PARAMS" >/dev/null 2>&1
  sleep 4

  rect=$(window_rect)
  if [ -z "$rect" ]; then
    reconnect
    sh_exec "aa start -a $ABILITY -b $BUNDLE $inject $EXTRA_PARAMS" >/dev/null 2>&1
    sleep 4
    rect=$(window_rect)
  fi
  if [ -z "$rect" ]; then fail "$spec" "读不到 WindowRect（窗口未创建）"; return; fi
  rw=$(echo "$rect" | awk '{print $3}'); rh=$(echo "$rect" | awk '{print $4}')
  echo "$rect" > "$dir/windowrect.txt"
  # 实测的是 outer rect（含标题栏/边框），期望值 = 请求的内容尺寸 + 装饰边
  expected=$((req_w + DECORATION))
  log "$spec → WindowRect ${rw}x${rh}（期望宽 ${expected}，请求 ${req_w}x${req_h} + 装饰 ${DECORATION}）"

  # 偏差过大说明 resize 注入没生效：回落到拖窗口右边缘。该 WM 小于 ~60px 的位移不响应，
  # 且行程有缩放误差，因此残余误差过小时加倍/兜到 60px 再拖，最多 6 轮，精度下限 60px。
  delta=$((rw - expected)); [ $delta -lt 0 ] && delta=$((-delta))
  if [ $delta -gt $TOLERANCE ]; then
    log "$spec 偏差 ${delta}px > 容差 ${TOLERANCE}px，改用拖拽右边缘兜底（精度下限 60px）"
    local x y attempt prev err move edge floor
    x=$(echo "$rect" | awk '{print $1}'); y=$(echo "$rect" | awk '{print $2}')
    prev=-1
    floor=60
    for attempt in 1 2 3 4 5 6; do
      err=$((expected - rw))
      move=$((err))
      [ ${move#-} -lt $floor ] && move=$((err * 2))
      [ ${move#-} -lt $floor ] && move=$floor
      edge=$((x + rw - 2))
      devecocli ui drag "$edge" $((y + rh / 2)) "$((edge + move))" $((y + rh / 2)) --device "$SERIAL" --speed 3000 >/dev/null 2>&1
      sleep 2
      rect=$(window_rect); rw=$(echo "$rect" | awk '{print $3}')
      echo "$rect" > "$dir/windowrect.txt"
      delta=$((rw - expected)); [ $delta -lt 0 ] && delta=$((-delta))
      log "$spec 拖拽第 $attempt 轮（请求位移 ${move}px）→ ${rw}px（偏差 ${delta}px）"
      [ $delta -le $TOLERANCE ] && break
      [ $delta -le $floor ] && { log "$spec 已达拖拽精度下限，按实测宽度 ${rw}px 继续断言"; break; }
      [ "$rw" = "$prev" ] && break
      prev=$rw
    done
    if [ $delta -gt $floor ]; then
      fail "$spec" "拖拽兜底后宽度仍为 ${rw}px（期望 ${expected}，偏差 ${delta}px > 精度下限 ${floor}px）"
      return
    fi
  fi

  wid=$(window_id)
  if [ -z "$wid" ]; then fail "$spec" "窗口 id 取不到"; return; fi

  if ! wait_layout "$wid" home_feed "$dir/home_layout.json"; then
    fail "$spec" "首页布局树里等不到 home_feed"
    return
  fi
  devecocli ui screenshot --device "$SERIAL" --path "$dir/home.png" >/dev/null 2>&1
  if ! python3 "$HERE/window_layout_check.py" home --layout "$dir/home_layout.json" \
       --rect-w "$rw" --density "$DENSITY" > "$dir/home_check.json"; then
    fail "$spec" "首页断言失败 $(python3 -c "import json;print('; '.join(json.load(open('$dir/home_check.json'))['problems']))" 2>/dev/null)"
    return
  fi
  log "$spec 首页 $(cat "$dir/home_check.json")"

  if [ "$WITH_VIDEO" = "1" ]; then
    local center
    center=$(first_card_center "$dir/home_layout.json")
    if [ -z "$center" ]; then fail "$spec" "首页无卡片可点（feed 为空？）"; return; fi
    devecocli ui click ${center} --device "$SERIAL" >/dev/null 2>&1
    sleep 3
    wid=$(window_id)
    if ! wait_layout "$wid" video_player "$dir/video_layout.json"; then
      fail "$spec" "点击卡片后等不到 video_player"
      return
    fi
    # 取流快慢不定：轮询到播放器报出总时长为止（最多 ~24s），再截图与断言
    local tries=0
    while [ $tries -lt 8 ]; do
      wid=$(window_id)
      devecocli ui layout --device "$SERIAL" --format json --mode full --window "$wid" > "$dir/video_layout.json" 2>/dev/null
      python3 "$HERE/window_layout_check.py" video --layout "$dir/video_layout.json" \
        --rect-w "$rw" --density "$DENSITY" > "$dir/video_check.json" && break
      grep -q '总时长仍为' "$dir/video_check.json" || break
      tries=$((tries + 1))
      sleep 3
    done
    devecocli ui screenshot --device "$SERIAL" --path "$dir/video.png" >/dev/null 2>&1
    if ! [ -s "$dir/video_check.json" ] || ! grep -q '"ok": true' "$dir/video_check.json"; then
      fail "$spec" "视频页断言失败 $(python3 -c "import json;print('; '.join(json.load(open('$dir/video_check.json'))['problems']))" 2>/dev/null)"
      return
    fi
    log "$spec 视频页 $(cat "$dir/video_check.json")"
  fi
}

rm -rf "$OUT"
mkdir -p "$OUT"
log "设备 $SERIAL ｜尺寸表 [$SIZES] ｜密度 $DENSITY ｜容差 ${TOLERANCE}px ｜输出 $OUT"

for spec in $SIZES; do
  run_size "$spec"
done

sh_exec "aa force-stop $BUNDLE" >/dev/null 2>&1

if [ ${#FAILURES[@]} -eq 0 ]; then
  : > "$OUT/failures.txt"
  log "全部尺寸通过，失败汇总为空：$OUT/failures.txt"
  exit 0
fi
printf '%s\n' "${FAILURES[@]}" > "$OUT/failures.txt"
log "失败 ${#FAILURES[@]} 项："
printf '  %s\n' "${FAILURES[@]}"
exit 1
