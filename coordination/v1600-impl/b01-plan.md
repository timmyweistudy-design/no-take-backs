# B01：量測工具與存檔範本（方案 §4 B01：P11.1、P11.4、P10.1、§3.1 範本）
1. **耗時切分**：`check.py` 的關鍵路徑 `t_stateful3`（508 秒、六組）拆成 `t_stateful3`（modes、coach_lab，前綴 tc_）＋`t_stateful4`（share_codes、reports_platform、modes_live、battle_visual，前綴 td_）。總工作量不變；測試 ID 聯集照舊核對（`check.py` 既有：每個測試只在一步出現、聯集＝全集）。
2. **差分擴驗**：`tools/affected_shots.py`——改動檔案 → 要重拍的畫面（依 screens.json entry）；字串、字型、色票、介面底層、畫面入口、模擬、存檔、截圖腳本、版面檢查、素材、shader、桌位表 → FULL；不認得的 scripts → FULL；只改 tests／docs → 0 張。發版照舊全量。
3. **烘焙分段量測**：`sprite_cache.gd` 記讀回（GPU→CPU）、上傳（建貼圖）、每段畫格的次數／總時間／最大值（`stage_report()`）；`dev_main --perf` 的圖集掃描輸出附 `stages`。冷熱各 20 次的正式量測放 B09（要開視窗）。
4. **會話邊界範本**：`tests/test_base.gd::session_contract`（承諾後重啟不變、結算只一次、壞資料不當、舊樣本讀回）；先套無盡塔 `test_session_contract_tower_v1600`。
5. 1.6.0 測試尾碼 `_v1600`（`_v160` 是舊內部 V1.6.0）。
