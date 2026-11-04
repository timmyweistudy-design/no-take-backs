#!/usr/bin/env bash
# 統一檢查入口：本機與 CI 用同一套；實作在 tools/check.py（第九輪 P0：平行、可快取）。
# 用法：GODOT=<godot 執行檔> tools/check_all.sh [輸出資料夾]   驗收一律全部重跑；改動時用 tools/check.py（有快取）或 --quick
cd "$(dirname "$0")/.."
PY="$(command -v python3 || command -v python)"
exec "$PY" tools/check.py --no-cache --out "${1:-../build/tmp/check}"
