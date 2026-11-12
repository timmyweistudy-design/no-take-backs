你是《落子無悔》(Godot 4.6.2，GDScript) 的程式審查。只讀檔。專案根目錄是目前資料夾；遊戲在 game/。
1.2.0 第 9 大類：規劃 coordination/v120-impl/cat09-plan.md；差異 coordination/v120-impl/cat09-r1/diff.patch（新檔 scripts/ui/battle/frags.gd 材料碎片；battle_view.gd 事件接上碎片、急救／火矢／接拍觸發資訊；battle_state.gd _hit_material；game_screens.gd 步進與繪製；events.gd 新標籤 rescue；battle_sim.gd 急救事件加標籤）。差異裡也夾著第 8 大類的變更，只看第 9 大類部分。
請檢查：①碎片上限（單格 2、總數 30、丟最舊）實作是否正確、是否真的和 FX_CAP 分開、會不會影響任何必要提示；②截圖可重現（雜湊種子）、減少特效／簡化／4 倍速關閉、跳轉（seek）、重播、結果頁時有沒有殘留；③火矢事件的 src 可能是已倒下的射手：所有用到 src 的地方（last_hitter、戰報、MVP、跟拍）會不會出錯；④急救事件加標籤會不會改到模擬雜湊或金標準；⑤效能（每次命中 3 片、每幀遍歷）；⑥ui.gd 事件測試（KINDS／TAGS）是否涵蓋新標籤。
附檔案與行號。最多 8 條必改（位置、問題、會怎樣、改法）。900 字內。最後一行「結論：可／有條件／不可」。
