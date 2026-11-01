#!/usr/bin/env bash
# 平衡工具 2.0 多行程分片執行器（優化方案 L2）。
# 用法：tools/balance.sh [輸出資料夾] [模式...]
#   預設模式：matrix league turns:cap10 turns:snake5 turns:snake5c search
# 每個模式開 SHARDS 個 headless 行程（預設 16），每片寫自己的檔案，最後 balance_report.py 依場次合併、檢查紅線。
# 結束碼：0＝紅線全過；1＝有紅線失敗；2＝執行錯誤（任何一片失敗、零筆結果都算錯）。
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-../docs/balance-runs/latest}"
shift || true
MODES=("$@")
[ ${#MODES[@]} -eq 0 ] && MODES=(matrix league turns:cap10 turns:snake5 turns:snake5c search)
SHARDS="${SHARDS:-16}"
GODOT="${GODOT:-godot}"
mkdir -p "$OUT"
rm -f "$OUT"/*.jsonl
t0=$(date +%s)
fail=0
for m in "${MODES[@]}"; do
  mode="${m%%:*}"; extra=""
  [ "$mode" = "turns" ] && extra="--rule=${m#*:}"
  pids=()
  for ((s=0; s<SHARDS; s++)); do
    "$GODOT" --headless --path . --script res://tools/balance2.gd -- "--mode=$mode" "--shard=$s" "--shards=$SHARDS" $extra \
      > "$OUT/${m/:/_}_$s.raw" 2>&1 &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || fail=1; done
  for ((s=0; s<SHARDS; s++)); do
    grep '^R ' "$OUT/${m/:/_}_$s.raw" | sed 's/^R //' > "$OUT/${m/:/_}_$s.jsonl"
    if grep -q 'SCRIPT ERROR\|Parse Error' "$OUT/${m/:/_}_$s.raw"; then echo "✗ $m 第 $s 片有腳本錯誤" >&2; fail=1; fi
    rm -f "$OUT/${m/:/_}_$s.raw"
  done
  echo "· $m 完成（累計 $(( $(date +%s) - t0 )) 秒）"
done
# 搜尋到保留池勝率 >65% 的陣型 → 自動對第一名做反制搜尋
if [[ " ${MODES[*]} " == *" search "* ]]; then
  top=$(cat "$OUT"/search_*.jsonl | python3 -c "import sys,json; r=sorted((json.loads(l) for l in sys.stdin if l.strip()), key=lambda x:-x['fit_holdout']); print(r[0]['code'] if r and r[0]['fit_holdout']>0.65 else '')")
  if [ -n "$top" ]; then
    MODES+=("countersearch")
    pids=()
    for ((s=0; s<SHARDS; s++)); do
      "$GODOT" --headless --path . --script res://tools/balance2.gd -- --mode=countersearch "--shard=$s" "--shards=$SHARDS" "--target=$top" > "$OUT/countersearch_$s.raw" 2>&1 &
      pids+=($!)
    done
    for p in "${pids[@]}"; do wait "$p" || fail=1; done
    for ((s=0; s<SHARDS; s++)); do
      grep '^R ' "$OUT/countersearch_$s.raw" | sed 's/^R //' > "$OUT/countersearch_$s.jsonl"
      if grep -q 'SCRIPT ERROR\|Parse Error' "$OUT/countersearch_$s.raw"; then echo "✗ countersearch 第 $s 片有腳本錯誤" >&2; fail=1; fi
      rm -f "$OUT/countersearch_$s.raw"
    done
    echo "· countersearch 完成（目標 $top）"
  fi
fi
printf '{"modes": [%s], "shards": %d}\n' "$(printf '"%s",' "${MODES[@]}" | sed 's/,$//')" "$SHARDS" > "$OUT/manifest.json"
[ $fail -ne 0 ] && { echo "✗ 有分片失敗" >&2; exit 2; }
python3 tools/balance_report.py "$OUT" "$(( $(date +%s) - t0 ))"
