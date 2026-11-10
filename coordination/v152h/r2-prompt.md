《落子無悔》V1.5.2 **交接方案優化** 第 2 輪（共三輪）。只讀檔、不改檔。
看 coordination/v152h/r1-plan.md（第 1 輪後修訂稿；開頭寫了採納與不採納的查核），對照 docs/history/HANDOFF-v152.md 與程式（game/scripts/ui/ui_base.gd、lobby_view.gd、screens/game_menus.gd、game/tools/dev_main.gd、layout_check.sh）。兩方第 1 輪意見：r1-codex.md、r1-agy.md。
請：
1. 修訂稿裡的錯誤或會讓接手者做錯的地方（最多 5 條，附檔案:行號，要對照程式）。特別檢查：①`_draw_bookmark` 移到 `_draw_lobby` 結尾，畫序對不對（會不會被之後畫的東西蓋、或蓋到別的層／彈窗）；②`_h1` 回傳 float 改動，31 個呼叫點是否相容；③`--shot-data` 注入假存檔會不會污染真存檔或指紋。
2. 「未選分頁預設不畫書籤」、「確認框不捲動只截斷」這兩個定案，你同意嗎？一句理由。
3. 交接文件結構還缺什麼才能讓新工作階段 30 分鐘內開工（最多 3 條）。
4. 最後一行結論：「可定稿」「有條件」或「不可」。繁體中文，1000 字以內。
