《落子無悔》V1.5.2 **交接方案優化** 第 3 輪（最後一輪）。只讀檔、不改檔。
看 coordination/v152h/r2-plan.md（第 2 輪後修訂；開頭是查核與採納），兩方第 2 輪意見 r2-codex.md、r2-agy.md；程式在 game/scripts/ui/（lobby_view.gd _draw_lobby_presets 約 510～528、_draw_bookmark 約 1134；screens/game_menus.gd 確認框約 835～846、備份約 853～870）、game/tools/dev_main.gd、layout_check.sh。
請：
1. 修訂稿還有沒有會讓接手者做錯或做到一半卡住的地方（最多 4 條，附檔案:行號，對照程式）。特別檢查：書籤放進 `_draw_lobby_presets` 後，簡化介面、手把焦點框、`lb_mine` 按鈕、150% 文字槽是否都正確；備份目錄改跟前綴會不會影響玩家既有備份的讀取（升級相容）。
2. 新交接結構 0～8 章，有沒有多餘或該合併的。
3. 最後一行結論：「同意定稿」或「不同意定稿：原因」。繁體中文，900 字以內。
