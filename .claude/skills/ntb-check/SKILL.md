---
name: ntb-check
description: 落子無悔要跑檢查或驗收時用：選最小的檢查、看結果、處理失敗
---
1. 改動中：`cd game && GODOT=<exe> python3 tools/check.py`（快取）；只碰 UI 或文字可加 `--quick`。指定步驟：`--only t_ui,golden`。
2. 里程碑或推送前：`tools/check_all.sh`（`--no-cache`，用背景跑）。
3. 只讀最後一行。失敗才打開 `build/tmp/check/<步驟>.log`，用 grep 找 `FAIL`、`SCRIPT ERROR`。
4. 慢的測試看 `summary.json` 的 `slow_tests`。
5. 卡住：`powershell.exe` 查 `Win32_Process` 的 `--ntb-run=` 記號，確認是自己的才照 PID 收。
