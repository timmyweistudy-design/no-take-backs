#!/usr/bin/env bash
# 新兵種驗收（第四輪 §3.4）。用法：NTYPES=7 SHARDS=12 tools/balance/unit_eval.sh <輸出資料夾> core repl:5 repl:6 cover:7 ...
# 第六輪：FREE=間距,縱深 → 全部改用自由陣型（例 FREE=800,6000）。
# 每個模式開 SHARDS 個 headless 行程；最後 unit_eval_report.py 核對筆數與鍵、算群集區間、判定門檻。
set -uo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:?輸出資料夾}"; shift
SHARDS="${SHARDS:-12}"; GODOT="${GODOT:-godot}"; NT="${NTYPES:-10}"
FA=""; [ -n "${FREE:-}" ] && FA="--free=$FREE"
mkdir -p "$OUT"; rm -f "$OUT"/*.jsonl
t0=$(date +%s); fail=0
for m in "$@"; do
  mode="${m%%:*}"; unit=""; [[ "$m" == *:* ]] && unit="--unit=${m#*:}"
  pids=()
  for ((s=0; s<SHARDS; s++)); do
    "$GODOT" --headless --path . --script res://tools/balance/unit_eval.gd -- "--mode=$mode" $unit "--ntypes=$NT" "--shard=$s" "--shards=$SHARDS" $FA > "$OUT/${m/:/_}_$s.raw" 2>&1 &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || fail=1; done
  for ((s=0; s<SHARDS; s++)); do
    grep '^R ' "$OUT/${m/:/_}_$s.raw" | sed 's/^R //' > "$OUT/${m/:/_}_$s.jsonl"
    if grep -q 'SCRIPT ERROR\|Parse Error' "$OUT/${m/:/_}_$s.raw"; then echo "✗ $m 第 $s 片有腳本錯誤" >&2; grep -m3 'SCRIPT ERROR' "$OUT/${m/:/_}_$s.raw" >&2; fail=1; fi
    rm -f "$OUT/${m/:/_}_$s.raw"
  done
  echo "· $m 完成（累計 $(( $(date +%s) - t0 )) 秒）"
done
CONTRACT=$("$GODOT" --headless --path . --script res://tools/balance/unit_eval.gd -- --mode=contract "--ntypes=$NT" $FA 2>&1 | grep '^CONTRACT ' | sed 's/^CONTRACT //')
[ -z "$CONTRACT" ] && { echo "✗ 取不到實驗契約" >&2; exit 2; }
printf '{"modes": [%s], "shards": %d, "ntypes": %d, "commit": "%s", "contract": %s}\n' "$(printf '"%s",' "$@" | sed 's/,$//')" "$SHARDS" "$NT" "$(git rev-parse --short HEAD)$(git diff --quiet || echo '+dirty')" "$CONTRACT" > "$OUT/manifest.json"
[ $fail -ne 0 ] && { echo "✗ 有分片失敗" >&2; exit 2; }
python3 tools/balance/unit_eval_report.py "$OUT"
