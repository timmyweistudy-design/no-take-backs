#!/usr/bin/env bash
# 1.2.0 §14.8：效能 ABBA 交錯比較（不能用不同時段的單次絕對值下結論）。
# 用法：GODOT=<win exe> tools/perf_ab.sh <A 的 game 資料夾> <B 的 game 資料夾> <輪數> <輸出資料夾>
# 每輪跑 A B B A；兩邊都要先 --import 過（快照資料夾自己先匯入）。輸出每次的 json 與 summary.json／結論。
set -u
A=$(realpath "$1"); B=$(realpath "$2"); N=${3:-2}; OUT=$(realpath -m "$4")
mkdir -p "$OUT"; rm -f "$OUT"/run_*.json "$OUT"/run_*.log "$OUT"/summary.json   # 1.2.0（Codex cat01 #7）：不能混到上一次的殘留輸出
winpath() { if command -v wslpath >/dev/null 2>&1 && [[ "$GODOT" == *.exe ]]; then wslpath -w "$1"; else printf '%s' "$1"; fi; }
i=0
for r in $(seq 1 "$N"); do
  for side in A B B A; do
    i=$((i+1)); d=$A; [ "$side" = B ] && d=$B
    f="$OUT/run_$(printf %02d $i)_$side.json"
    timeout 900 "$GODOT" --path "$(winpath "$d")" --resolution 1280x800 -- --perf="$(winpath "$f")" --perf-commit="$side" </dev/null > "${f%.json}.log" 2>&1
    [ -s "$f" ] || { echo "PERFAB FAIL：第 $i 次（$side）沒有輸出，見 ${f%.json}.log"; exit 1; }
  done
done
python3 "$(dirname "$0")/perf_ab_sum.py" "$OUT"
