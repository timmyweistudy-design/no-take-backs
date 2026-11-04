#!/usr/bin/env bash
# 平衡驗收：tools/fantasy_eval.sh <mode> <輸出檔> [其他參數]。SHARDS 預設 4。
cd "$(dirname "$0")/.."
M="$1"; O="$2"; shift 2
S="${SHARDS:-4}"; G="${GODOT:-godot}"
: > "$O"
for i in $(seq 0 $((S-1))); do
  "$G" --headless --path . --script res://tools/fantasy_eval.gd -- --mode="$M" --shard=$i --shards=$S "$@" 2>/dev/null | grep -aE '^[RCAX] ' >> "$O" &
done
wait
