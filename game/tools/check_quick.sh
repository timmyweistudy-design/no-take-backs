#!/usr/bin/env bash
# 快速檢查（第七輪 I2）：改動時用。不取代 check_all.sh（驗收、推送前還是跑完整的）。
# 用法：GODOT=<godot> tools/check_quick.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-${TMPDIR:-/tmp}/ntb-quick}"
mkdir -p "$OUT"
fail() { echo "QUICK FAIL：$1（記錄在 $OUT）"; exit 1; }
"$GODOT" --headless --path . --script res://tools/load_all.gd > "$OUT/load.log" 2>&1 || fail "腳本載入失敗"
for s in harness save rules ui; do
  "$GODOT" --headless --path . --script res://tests/run_tests.gd -- --only=$s > "$OUT/$s.log" 2>&1 || fail "測試組 $s 有失敗"
  grep -E "SCRIPT ERROR" "$OUT/$s.log" >/dev/null && fail "測試組 $s 有腳本錯誤"
done
"$GODOT" --headless --path . --script res://tools/golden.gd -- --n=30 > "$OUT/golden.log" 2>&1 || fail "金標準前 30 場有分歧"
python3 tools/check_strings.py > "$OUT/strings.log" 2>&1 || fail "字串表"
python3 tools/check_font_coverage.py > "$OUT/font.log" 2>&1 || fail "字型缺字"
echo "QUICK OK"
