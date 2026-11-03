#!/usr/bin/env bash
# 第六輪 §6.3：間距 × 縱深全因子篩選（核心剋制 6 條＋聯賽 4800 場），外加格子基準。
# 用法：SHARDS=17 tools/free_screen.sh <輸出資料夾>
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${1:?輸出資料夾}"; SHARDS="${SHARDS:-17}"; GODOT="${GODOT:-godot}"
mkdir -p "$OUT"
for cfg in ${CFGS:-grid 1000,6000 1000,7000 1000,7500 800,6000 800,7000 800,7500 600,6000 600,7000 600,7500}; do
  d="$OUT/${cfg/,/_}"; mkdir -p "$d"; rm -f "$d"/*.jsonl
  fa=""; [ "$cfg" != grid ] && fa="--free=$cfg"
  pids=()
  for ((s=0; s<SHARDS; s++)); do
    ( "$GODOT" --headless --path . --script res://tools/unit_eval.gd -- --mode=core --shard=$s --shards=$SHARDS $fa 2>&1 | grep '^R ' | sed 's/^R //' > "$d/core_$s.jsonl"
      "$GODOT" --headless --path . --script res://tools/balance2.gd -- --mode=league --shard=$s --shards=$SHARDS $fa 2>&1 | grep '^R ' | sed 's/^R //' > "$d/league_$s.jsonl" ) &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p"; done
  echo "· $cfg 完成 $(cat "$d"/core_*.jsonl | wc -l) 核心、$(cat "$d"/league_*.jsonl | wc -l) 聯賽"
done
echo SCREENDONE
