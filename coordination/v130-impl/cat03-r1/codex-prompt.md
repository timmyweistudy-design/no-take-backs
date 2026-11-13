你是《落子無悔》(Godot 4.6.2) 1.3.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 3 大類：規劃 coordination/v130-impl/cat03-plan.md；方案 docs/2026-11-13-v1.3.0-plan.md §3、§4、§0.4（底座形狀）、§19.3；差異 coordination/v130-impl/cat03-r1/diff.patch。
內容：art.gd ring_base 加 team（紅方八角）、sprite_cache 環圖多一格與 draw_base／draw_ring 的 team、battle_units 平原棉布拼貼（_cotton_tex）與粉筆線、地圖個性小物 _map_prop、map_art 熔岩亮度與金泥反光、冰下淡裂紋、battle_state._tone 每日清晨／戰役依章、dev_main 純黑 >1% 改違規、layout_check 低對比報表、測試 test_base_shapes_v130。
請檢查：①八角底座：鏡像、換邊、色盲、遠征接力（隊伍與玩家不同時）、圖鑑大圖與擺陣預覽、合成格 fan 偏移是否都拿到正確隊伍；ring_tex 從 14 格變 15 格，有沒有用寫死寬度的地方；②棉布拼貼對齊格線（ORIGIN、小地圖 12×7、放大鏡頭）、texture_repeat 副作用；③_tone 用 get("daily_spec")／camp_id 的判斷會不會誤判（練習、試玩、重播、結果頁）；④純黑門檻會不會誤擋（轉場、暫停、截圖時機）；⑤效能（每幀新增繪製）；⑥其他。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
