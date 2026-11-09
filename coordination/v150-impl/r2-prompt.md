你是《落子無悔》V1.5.0 第二輪實作審查者（Godot 4.6.2）。第一輪意見與處理在 coordination/v150-impl/ledger.md。
請只讀檔，驗證第一輪的修正是否正確且沒有引入新問題，並審查新加的東西：
- 暫停選單、確認框、設定一次寫檔：scripts/ui/screens/game_menus.gd（_draw_pause_menu、_ask_confirm、_apply_all_settings、_progress_backup/_restore、_settings_row_y）
- 投射物：scripts/ui/battle/battle_state.gd proj_phase(only)、battle_units.gd（陣亡者飛行物）、battle_view.gd（BONK 排除、8 筆）
- 圖鑑：scripts/ui/codex_view.gd（cx_clock、CX_ANGLES、出手飛行物）
- 新成就 7 個：scripts/game/steam.gd、game_modes.gd、game_core.gd、game_result.gd；成就頁四欄
- 我的預設 10 格：scripts/ui/lobby_view.gd；結果頁主次按鈕 game_result.gd；競猜說明 game_modes.gd
- 角色：kingdom.gd _berserk_axe、鼓手、弓手；fantasy.gd 骨棒。附圖 units_sheet.png。
另外對 ledger 裡的「裁決」逐條表態：同意／不同意＋理由。
輸出：最多 10 條實際問題（檔案:行號、觸發條件、後果），依嚴重度排序，繁體中文。沒有就說沒有。
