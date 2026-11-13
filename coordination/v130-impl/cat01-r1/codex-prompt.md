你是《落子無悔》(Godot 4.6.2，GDScript) 1.3.0 實作的程式審查。只讀檔。專案根目錄是目前資料夾；遊戲在 game/。
第 1 大類：規劃 coordination/v130-impl/cat01-plan.md；方案 docs/2026-11-13-v1.3.0-plan.md §9.2（R11）、§4（色票）、§15；差異 coordination/v130-impl/cat01-r1/diff.patch。
內容：ui_base.gd 墨跡框 ink_line（TextServer 字形框）、label_ink、ink_center_p、probe_cell_begin/end、_btn／_btn_quiet 改墨跡置中；layout_rules.gd R11；optical_offsets.gd；dev_main.gd r11_cells、layout_check.sh 沒接上就失敗；lobby_view／game_v16／replay_view／game_modes 的格子宣告；palette.gd 色票與別名；game_menus.gd 音量木軌拖曳；測試 ui.gd（test_layout_r11_v130、test_palette_v130、test_vol_drag_v130）。版面 2 組 370 張 0 違規、R11 量了 3849 段。
請檢查：①ink_line 的正確性（字形 offset 的座標系、font_size 欄位、後備字型、空白字、多語、快取鍵會不會撞、free_rid）；②墨跡置中改變了所有按鈕字的位置——有沒有地方會因此出框、壓九宮格、和既有排版假設衝突（例如 _btn 的 fit／wrap 用的寬度、按下下沉）；③R11 把同一個面的字合併：會不會把不同格子誤合、或漏掉沒宣告的格子；④音量拖曳：在 draw 裡改設定是否安全（重入、存檔次數、手把、觸控、跨畫面殘留狀態）；⑤palette 的 const 別名在 GDScript 是否真的是常數（會不會影響 static 方法或 match）；⑥其他錯誤。
附檔案與行號。最多 8 條必改。900 字內。最後一行「結論：可／有條件／不可」。
