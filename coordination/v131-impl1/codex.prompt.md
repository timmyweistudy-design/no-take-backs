你是資深 Godot 4.6 工程師兼 2D 技術美術。唯讀：不要改檔、不要跑 Godot。
《落子無悔》（game/）V1.3.1 實作審查第 1 輪。方案 docs/2026-11-08-v1.3.1-plan.md、裁決 coordination/v131-ledger.md。未提交 diff：coordination/v131-impl1/diff.patch（也可讀 game/ 現檔）。
注意：方案的「兩趟畫序」沒照做——理由：轉身影格只烘 0～90°，另一半是鏡像，配件近遠歸屬不用對調；請判斷這個理由是否成立。
請找真的 bug（引用 檔案:行，繁中、1500 字內）：
1. kit.gd 的 _part／_part_at／_part_end／_hat_on／_hat_off／look／calm／hat_pop／baking／anchor_* 狀態有沒有漏重設、在一般影格或直接繪製（圖鑑 _cx_portrait、MVP）污染；各兵種 _part 與 _part_end 配對（kingdom.gd 頭部轉換結束、fantasy.gd 每種）。
2. sprite_cache.gd：_ExtraPainter（小動作／受擊帽子／走路轉身）索引與 _post(per) 隊伍墨色、wt 分頁、fid/hurt/walk 轉身路由優先序、_draw_cell 的呼吸、slime_shine 位置與重複、世代檢查。
3. battle_units／battle_state：atk_face 鎖朝向、待機小動作觸發條件、grim 計算、最後一隻張望（idle_since）、投彈兵起飛點、M_HAPPY／M_SURPRISE／M_GRIM 疊加。
4. 記憶體與烘焙時間（轉身頁 22 種、小動作頁、走路轉身 2 頁）是否符合方案 §0；冷啟動影響。
5. 任何改到模擬或 FINGERPRINT 的地方（不該有）。
分「必修／建議／不用改」，每條含修法。最後一行「結論：…」。
