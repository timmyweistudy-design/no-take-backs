#!/usr/bin/env bash
# 快速檢查：改動時用，不取代 check_all.sh。用法：GODOT=<godot> tools/check_quick.sh
cd "$(dirname "$0")/.."
PY="$(command -v python3 || command -v python)"
exec "$PY" tools/check.py --quick --out "${1:-../build/tmp/quick}"
