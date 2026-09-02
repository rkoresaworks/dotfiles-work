#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Center Displays
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName Display

# 上下配置で中心揃え: メイン(27インチ)の下にサブ(10インチ)を水平中央で配置。
# メインの解像度が変わっても現在値から origin を再計算するため、
# 解像度切替後に実行すればズレが直る。

set -euo pipefail

MAIN_ID="3C03D217-D284-4E17-9FA0-AB9CD0043763"
SUB_ID="AC3098BB-3176-4CCC-ADEB-95663CFB8BFB"

DISPLAYPLACER="$(command -v displayplacer || echo /opt/homebrew/bin/displayplacer)"

LIST="$("$DISPLAYPLACER" list)"

# 指定 id のブロックから現在の "WxH hz scaling" を取り出す
current_mode() {
  echo "$LIST" | awk -v id="$1" '
    $0 ~ "Persistent screen id: " id { found = 1 }
    found && /^Resolution:/ { res = $2 }
    found && /^Hertz:/ { hz = $2 }
    found && /^Scaling:/ { print res, hz, $2; exit }
  '
}

read -r MAIN_RES MAIN_HZ MAIN_SCALING <<< "$(current_mode "$MAIN_ID")"
read -r SUB_RES SUB_HZ SUB_SCALING <<< "$(current_mode "$SUB_ID")"

if [[ -z "${MAIN_RES:-}" || -z "${SUB_RES:-}" ]]; then
  echo "ディスプレイが見つからない (main=${MAIN_RES:-?} sub=${SUB_RES:-?})"
  exit 1
fi

MAIN_W="${MAIN_RES%x*}"
MAIN_H="${MAIN_RES#*x}"
SUB_W="${SUB_RES%x*}"

X=$(( (MAIN_W - SUB_W) / 2 ))
Y="$MAIN_H"

"$DISPLAYPLACER" \
  "id:$MAIN_ID res:$MAIN_RES hz:$MAIN_HZ scaling:$MAIN_SCALING origin:(0,0) degree:0" \
  "id:$SUB_ID res:$SUB_RES hz:$SUB_HZ scaling:$SUB_SCALING origin:($X,$Y) degree:0"

echo "サブを ($X,$Y) に配置"
