#!/usr/bin/env bash
# 統一檢查入口（第三輪 T1）：本機與 CI 用同一套。任何一步失敗就 exit 1，並印出是哪一步。
# 原本 CI 的問題：匯入失敗被 `|| true` 吃掉；`grep '0 失敗'` 連「10 失敗」也會通過；腳本語法錯誤會讓相依的測試靜靜略過。
# 用法：GODOT=<godot 執行檔> tools/check_all.sh [輸出資料夾]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-${TMPDIR:-/tmp}/ntb-check}"
mkdir -p "$OUT"
EXPECT_GODOT="4.6.2.stable"   # 第七輪 N3：本機、CI、匯出模板要同一版；確定性和指紋比對都靠這個
fail() { echo "CHECK FAIL：$1（記錄在 $OUT）"; exit 1; }
has_err() { grep -E "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script" "$1" >/dev/null; }

GV="$("$GODOT" --version 2>/dev/null | tr -d '\r')"
case "$GV" in
  "$EXPECT_GODOT"*) ;;
  *) [ "${ALLOW_GODOT_MISMATCH:-0}" = "1" ] || fail "Godot 版本是 $GV，應該是 $EXPECT_GODOT（快速開發可設 ALLOW_GODOT_MISMATCH=1，但不能當驗收）"
     echo "警告：Godot 版本 $GV 不是 $EXPECT_GODOT，這次結果不能當驗收" ;;
esac

"$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1 || fail "匯入失敗（exit 非 0）"
has_err "$OUT/import.log" && fail "匯入有腳本錯誤"
grep -E "^ERROR: .*(import|Import|Failed loading resource)" "$OUT/import.log" >/dev/null && fail "有素材匯入失敗"

"$GODOT" --headless --path . --script res://tools/load_all.gd > "$OUT/load.log" 2>&1 || fail "有腳本載入失敗"
grep -q "^LOADALL .*失敗 0：" "$OUT/load.log" || fail "載入檢查沒有完成"

"$GODOT" --headless --path . -- --boot-check > "$OUT/boot.log" 2>&1 || fail "正式入口啟動失敗"
grep -q "^BOOTOK" "$OUT/boot.log" || fail "正式入口沒有跑到標題"
has_err "$OUT/boot.log" && fail "正式入口啟動時有腳本錯誤"

"$GODOT" --headless --path . --script res://tests/run_tests.gd > "$OUT/test.log" 2>&1 || fail "規則測試有失敗（exit 非 0）"
grep -qE "^—— [1-9][0-9]* 通過 / 0 失敗" "$OUT/test.log" || fail "規則測試沒有印出完成標記"
has_err "$OUT/test.log" && fail "測試過程有腳本錯誤（可能有測試被略過）"
grep FINGERPRINT "$OUT/test.log" > "$OUT/fingerprint.txt"

"$GODOT" --headless --path . --script res://tools/mirror_100.gd > "$OUT/mirror.log" 2>&1 || fail "鏡像檢查失敗"
grep -q "^MIRROR100 100/100" "$OUT/mirror.log" || fail "鏡像沒有 100/100"

GN="${GOLDEN_N:-1000}"   # Windows 上一場約 1.5 秒，CI 的 Windows 用 200 場
"$GODOT" --headless --path . --script res://tools/golden.gd -- --n=$GN > "$OUT/golden.log" 2>&1 || fail "確定性金標準有分歧（看 golden.log 的第一個分歧場次與 tick）"
grep -q "^GOLDEN {\"n\":$GN,\"ok\":true}" "$OUT/golden.log" || fail "金標準沒有比完 $GN 場"

CN="${COMPAT_N:-1000}"   # 第四輪：舊 5 種兵逐 tick 相容（加新兵後舊兵行為不能變）；里程碑時用 COMPAT_N=1000 跑完整
"$GODOT" --headless --path . --script res://tools/compat.gd -- --n=$CN > "$OUT/compat.log" 2>&1 || fail "舊兵種相容檢查有分歧（看 compat.log）"
grep -q "^COMPAT {\"n\":$CN,\"ok\":true}" "$OUT/compat.log" || fail "相容檢查沒有比完 $CN 場"

"$GODOT" --headless --path . --script res://tools/seal_codes.gd > "$OUT/sealcodes.log" 2>&1 || fail "封存的舊對戰代碼（NTB2）播出不同結果（看 sealcodes.log）"
grep -q '^SEALCODES {"n":40,"ok":true}' "$OUT/sealcodes.log" || fail "舊對戰代碼檢查沒有完成"

"$GODOT" --headless --path . --script res://tools/golden_free.gd > "$OUT/goldenfree.log" 2>&1 || fail "自由模式金標準有分歧（看 goldenfree.log）"
grep -q '^GOLDENFREE {"n":120' "$OUT/goldenfree.log" || grep -q '^GOLDENFREE {.*"n":120' "$OUT/goldenfree.log" || fail "自由模式金標準沒有比完 120 場"

"$GODOT" --headless --path . --script res://tools/golden_v8.gd > "$OUT/goldenv8.log" 2>&1 || fail "第八輪金標準有分歧（看 goldenv8.log）"
grep -q '^GOLDENV8 {.*"n":60' "$OUT/goldenv8.log" || fail "第八輪金標準沒有比完 60 場"

"$GODOT" --headless --path . --script res://tools/orbit_detect.gd > "$OUT/orbit.log" 2>&1 || fail "騎兵打轉偵測超過門檻"
grep -q "^ORBIT cav_battles=" "$OUT/orbit.log" || fail "打轉偵測沒有完成"
for lg in mirror golden goldenfree goldenv8 compat sealcodes orbit; do has_err "$OUT/$lg.log" && fail "$lg 過程有腳本錯誤"; done

python3 tools/check_strings.py > "$OUT/strings.log" 2>&1 || fail "字串表有問題（欄數、重複鍵、空翻譯、參數數、不存在的鍵；看 strings.log）"
python3 tools/check_assets.py > "$OUT/assets.log" 2>&1 || fail "素材登記檢查失敗"
python3 tools/check_font_coverage.py > "$OUT/font.log" 2>&1 || fail "字型子集缺字（改了中文要重跑 tools/build_font.py）"

echo "CHECK OK：匯入、載入、啟動、測試、鏡像、金標準、自由金標準、打轉、字串表、素材、舊兵相容、舊對戰代碼、字型涵蓋全過（記錄在 $OUT）"
