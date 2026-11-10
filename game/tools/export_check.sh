#!/usr/bin/env bash
# 匯出成品驗收（第七輪 S3）：匯出正式版、試玩版、Linux，對成品跑 --self-check（不開視窗、不碰 Steam、不碰玩家存檔）。
# 用法：GODOT=<Godot 4.6.2 Windows exe> tools/export_check.sh <輸出資料夾（WSL 路徑，空的或不存在）> [--smoke]
# --smoke：只驗 Windows 正式版（開發中的快速版）。
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:?要設 GODOT}"; OUT="${1:?要給輸出資料夾}"; MODE="${2:-}"
[ -d "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ] && { echo "EXPORT FAIL：$OUT 不是空的"; exit 2; }
mkdir -p "$OUT/win" "$OUT/demo" "$OUT/linux"
rm -rf .godot/exported   # 第七輪：舊的匯出快取會帶到搬走的腳本，匯出成品開不起來（實際踩過：main.gd 拆出 dev_main.gd 之後）
wp() { if [[ "$GODOT" == *.exe ]]; then wslpath -w "$1"; else printf '%s' "$1"; fi; }
ex() {  # 預設名稱 路徑
  timeout 300 "$GODOT" --headless --path "$(wp .)" --export-release "$1" "$(wp "$2")" > "$OUT/export-$3.log" 2>&1 || { echo "EXPORT FAIL：$1 匯出 exit 非 0"; exit 1; }
  grep -E "SCRIPT ERROR|Parse Error" "$OUT/export-$3.log" && { echo "EXPORT FAIL：$1 匯出有腳本錯誤"; exit 1; }
  [ -s "$2" ] || { echo "EXPORT FAIL：$1 沒有產生 $2"; exit 1; }
}
sc() {  # 執行檔 期望 demo 標記
  local log="$OUT/selfcheck-$3.log"
  timeout 90 "$1" --headless -- --self-check > "$log" 2>&1
  local rc=$?
  local line; line=$(grep -a '^SELFCHECK' "$log" | tr -d '\r')
  echo "$3: $line"
  [ "$rc" = "0" ] || { echo "EXPORT FAIL：$3 自我檢查 exit $rc（看 $log）"; exit 1; }
  echo "$line" | grep -q "\"demo\":$2" || { echo "EXPORT FAIL：$3 試玩版標記不對"; exit 1; }
  echo "$line" | grep -q '"exported":true' || { echo "EXPORT FAIL：$3 不是匯出版"; exit 1; }
  echo "$line" | grep -q '"engine":"4.6.2' || { echo "EXPORT FAIL：$3 引擎版本不對"; exit 1; }
  echo "$line" | grep -q '"ok":true' || { echo "EXPORT FAIL：$3 自我檢查 ok 不是 true"; exit 1; }   # V1.0.0 T2
  [ -n "${EXPECT_VERSION:-}" ] && { echo "$line" | grep -q "\"version\":\"$EXPECT_VERSION\"" || { echo "EXPORT FAIL：$3 版本不是 $EXPECT_VERSION"; exit 1; }; }
  grep -aE "SCRIPT ERROR" "$log" && { echo "EXPORT FAIL：$3 有腳本錯誤"; exit 1; }
}
ex "Windows Desktop" "$OUT/win/NoTakeBacks.exe" win
sc "$OUT/win/NoTakeBacks.exe" false win
if [ "$MODE" != "--smoke" ]; then
  ex "Windows Demo" "$OUT/demo/NoTakeBacksDemo.exe" demo
  sc "$OUT/demo/NoTakeBacksDemo.exe" true demo
  # Linux 匯出要 linux_release.x86_64 模板。本機只裝了 Windows 模板時明講略過（不是通過）；CI 的 export job 會實跑。
  if [ -n "${LINUX_TEMPLATE_OK:-}" ] || [[ "$GODOT" != *.exe ]] || ls "$(wslpath -u "$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')")/Godot/export_templates/4.6.2.stable/linux_release.x86_64" >/dev/null 2>&1; then
    ex "Linux" "$OUT/linux/NoTakeBacks.x86_64" linux
    mkdir -p "$OUT/linux-demo"
    ex "Linux Demo" "$OUT/linux-demo/NoTakeBacksDemo.x86_64" linux-demo
    chmod +x "$OUT/linux/NoTakeBacks.x86_64" "$OUT/linux-demo/NoTakeBacksDemo.x86_64"
    sc "$OUT/linux/NoTakeBacks.x86_64" false linux
    sc "$OUT/linux-demo/NoTakeBacksDemo.x86_64" true linux-demo   # V1.0.0 T2：Linux 試玩版也要實際啟動
  else
    echo "LINUX SKIPPED：本機沒有 Linux 匯出模板（未驗證，不是通過）"
  fi
fi
du -sh "$OUT"/*/ | sed 's/^/size /'
# V1.0.0 R0：發版凍結紀錄（commit、各成品雜湊）
{ echo "commit $(git rev-parse HEAD 2>/dev/null)"; echo "dirty $(git status --porcelain 2>/dev/null | wc -l)"; for f in "$OUT"/*/*.exe "$OUT"/*/*.x86_64 "$OUT"/*/*.pck; do [ -f "$f" ] && sha256sum "$f"; done; } > "$OUT/manifest.txt"
echo "MANIFEST $OUT/manifest.txt"
echo "EXPORT OK"
