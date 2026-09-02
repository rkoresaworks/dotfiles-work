#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Set Resolution
# @raycast.mode silent
# @raycast.argument1 { "type": "dropdown", "placeholder": "解像度", "data": [{"title": "1920x1080 (HiDPI)", "value": "1920x1080:on"}, {"title": "2048x1152 (HiDPI)", "value": "2048x1152:on"}, {"title": "2304x1296 (HiDPI)", "value": "2304x1296:on"}, {"title": "2560x1440 (HiDPI)", "value": "2560x1440:on"}, {"title": "3008x1692 (HiDPI)", "value": "3008x1692:on"}, {"title": "3360x1890 (ネイティブ)", "value": "3360x1890:off"}, {"title": "3840x2160 (最大)", "value": "3840x2160:off"}] }

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName Display

# メイン(27インチ)の解像度を切り替え、同時にサブ(10インチ)を
# メイン直下・水平中央に配置する。1回の displayplacer 呼び出しで
# 両方適用するため、切替後の配置ズレが起きない。

set -euo pipefail

MAIN_ID="3C03D217-D284-4E17-9FA0-AB9CD0043763"
SUB_ID="AC3098BB-3176-4CCC-ADEB-95663CFB8BFB"

CHOICE="$1"
MAIN_RES="${CHOICE%:*}"
MAIN_SCALING="${CHOICE##*:}"

DISPLAYPLACER="$(command -v displayplacer || echo /opt/homebrew/bin/displayplacer)"

LIST="$("$DISPLAYPLACER" list)"

# サブの現在モード "WxH hz scaling" を取得
read -r SUB_RES SUB_HZ SUB_SCALING <<< "$(echo "$LIST" | awk -v id="$SUB_ID" '
  $0 ~ "Persistent screen id: " id { found = 1 }
  found && /^Resolution:/ { res = $2 }
  found && /^Hertz:/ { hz = $2 }
  found && /^Scaling:/ { print res, hz, $2; exit }
')"

if [[ -z "${SUB_RES:-}" ]]; then
  echo "サブディスプレイが見つからない"
  exit 1
fi

MAIN_W="${MAIN_RES%x*}"
MAIN_H="${MAIN_RES#*x}"
SUB_W="${SUB_RES%x*}"

X=$(( (MAIN_W - SUB_W) / 2 ))
Y="$MAIN_H"

# 解像度切替中は AeroSpace の全ウィンドウ再タイルに borders の枠追従描画が
# 重なって jank が増えるため、borders を一時停止する。EXIT trap で必ず再開
pkill -STOP -x borders 2>/dev/null || true
trap 'pkill -CONT -x borders 2>/dev/null || true' EXIT

"$DISPLAYPLACER" \
  "id:$MAIN_ID res:$MAIN_RES hz:60 scaling:$MAIN_SCALING origin:(0,0) degree:0" \
  "id:$SUB_ID res:$SUB_RES hz:$SUB_HZ scaling:$SUB_SCALING origin:($X,$Y) degree:0"

# AeroSpace の再タイル完了を待ってから枠描画再開（trap が CONT を送る）
sleep 2

echo "メイン $MAIN_RES / サブ ($X,$Y)"
