# 1.6.0 實作裁決（方案 `docs/2026-11-15-v1.6.0-plan.md`）

> 流程同 1.5.0：每批 plan → 實作 → Codex＋Hydrogen 各 ≤3 輪（使用者 11/14 指定）→ 檢查＋24 組（＋固定時鐘）→ ledger → commit／push。改 game/ 前跑 `build/tmp/chain_busy.sh`。測試尾碼 `_v1600`（`_v160` 是舊內部 V1.6.0）。

## B01：量測工具與存檔範本
- `check.py`：`t_stateful3`（508 秒、六組）拆成 `t_stateful3`（modes、coach_lab）＋`t_stateful4`（其餘四組，前綴 td_）。完整檢查壁鐘 582 → 446～453 秒（同樣 31～34 步快取，−22%）；測試 ID 聯集照舊核對（6974→6982 項）。新關鍵路徑 `t_stateful4` 388 秒。
- `tools/affected_shots.py`：改動檔案 → 要重拍的畫面；寧可多拍：`data/`、`tools/screens.json`、字型、色票、介面底層、畫面入口、模擬、存檔、截圖腳本、版面檢查、素材、shader、桌位表、`game_v16.gd`（跨太多畫面）→ FULL；不認得的 scripts → FULL；對照表沒認領的畫面一律加拍；只改 tests／docs → 0 張。
- `sprite_cache.gd`：讀回、上傳、每段畫格分段計時（`stage_report()`），`--perf` 圖集掃描附 `stages`；正式冷熱 20 次放 B09。
- 會話範本 `tests/test_base.gd::session_contract`（承諾後重啟不變、結算只一次且快照不變、壞資料、舊樣本）＋塔套用 `test_session_contract_tower_v1600`：結算走正式 `_tower_finish`、重啟走 JSON 讀回＋`Save.migrate`＋`sanitize_data`、結算後存讀再重送不重領、寫檔失敗（`fail_inject`）記未存→重試寫入承諾的那一層。
- **事故**：單獨跑測試時沒給 `--prefix`，Save 預設前綴是空字串——塔測試的 `save_data()` 寫進了 Godot 使用者資料夾裡**沒前綴的 `save.json`**（現在是 `{}`，`.bak` 是測試資料）。原本有沒有內容查不到（同資料夾其他檔都帶 `shot_`／`test_` 前綴，多半本來沒有）。→ `run_tests.gd` 一律先設前綴 `test_`（給了 `--prefix` 再覆蓋），任何測試都不再碰沒前綴的存檔。
- 三方：Codex 兩輪（有條件 5 → 有條件 3）；第 2 輪三條（game_v16 判全量、範本快照深拷貝、舊樣本走 migrate＋寫檔失敗情境）自己改，不再送審。Hydrogen 不送（沒有畫面改動；固定時鐘 0 張變差佐證）。
- 驗收：完整檢查 6982 項全過、指紋不變；固定時鐘戰鬥 648 張 0 違規、573／基線 568、0 張變差。
