唯讀核對完成，未改檔；未重跑 Godot，51/51、鏡像 100/100 與實機截圖採用 Claude 提供的驗證結果。

- **#4 已解決**：鏡像檢查已納入 `wp_for`、`kills` 與交換隊伍後的 `rally`（`game/scripts/core/mirror_check.gd:27、32`）。
- **#6 未解決**：已補預期場次鍵集合，但仍不檢查分片檔名／缺片，也未限制合法模式。記憶體模擬檔案實測：manifest 使用 `bogus`；或宣告兩片、只提供含全部結果的 `search_0.jsonl`，兩者均 exit 0、顯示全過（`game/tools/balance_report.py:22、45、65`）。
- **#7 已解決**：預設 400 場＝200 組，同組種子一致、交換先手（`game/tools/balance2.gd:103、110`）。
- **#12 已解決**：陣型儲存依回傳值顯示成功或失敗，失敗提示不再被「✓」覆蓋（`game/scripts/ui/main.gd:1385`）。
- **反制搜尋錯誤列已解決**：報表先拒絕任何 `error` 列；記憶體實測 exit 2（`game/tools/balance_report.py:48`）。
- **balance.sh 掃描已解決**：反制搜尋分支已補腳本／解析錯誤掃描；`bash -n` 通過（`game/tools/balance.sh:49`）。

本批新增程式**未發現可確認的新錯誤**：擊殺先累加同 tick 每位攻擊者傷害，再用鏡像不變鍵決勝（`game/scripts/core/battle_sim.gd:363、371`）；三層繪製、勝方 MVP、判詞、`_pt_entry` 與背水提示流程相符（`game/scripts/ui/main.gd:362、381、990、1513、1635`）。存檔有讀回比對並回傳 rename 結果（`game/scripts/game/save.gd:62、66`）；CSV 設為 keep，匯出亦包含 CSV（`game/data/strings.csv.import:3`；`game/export_presets.cfg:10`）。

本里程碑可否結案：**有條件可**，條件是補齊 #6 的合法模式與分片檔完整性檢查。