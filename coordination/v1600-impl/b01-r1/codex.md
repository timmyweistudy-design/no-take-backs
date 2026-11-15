必改：

1. `affected_shots.py:14–18,59–63`：`data/puzzles.json`、`data/l10n_extra.csv`、`tools/screens.json` 均實測回傳 0 張。資料與截圖登記異動應保守 FULL。
2. `affected_shots.py:22–29`：entry 前綴漏掉教練、大廳第一步、軍令時間軸；對應腳本修改仍漏拍。補齊映射，未知入口須擴驗。
3. `save.gd:325–334`（tests/suites）：防重結算由測試自己的 `settled` 閉包提供，未呼叫正式 `_tower_finish`；正式防重失效仍會通過。須改測正式流程。
4. `test_base.gd:322–324`：只驗回傳旗標，第二次偷偷改狀態也會通過；且未在結算後存讀再重送。須比對狀態／獎勵快照，並驗重啟不重領。
5. `test_base.gd:325–329`：壞資料只驗非 null；舊樣本繞過正式遷移。須驗安全預期值、真實舊檔遷移，補各邊界中斷、續玩、回退及寫檔失敗。

分片前綴未見互踩；259 個 ID 聯集完整、無重複，快取含參數與步驟名。sprite 計時未見改動 await、清理或世代判斷；以上為只讀靜態審查與 Python 推演。

結論：有條件
