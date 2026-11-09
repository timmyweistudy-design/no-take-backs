你是《落子無悔》（Godot 4.6.2）V1.5.1 實作審查者，第 1 輪（共 3 輪）。只讀檔、不要改檔。
方案：docs/2026-11-09-v1.5.1-plan.md；實作紀錄與裁決：coordination/v151-impl/ledger.md。程式在 game/。比對 commit 3a44461～9fe7f37（git log）。
重點：
1. M0 返回堆疊（ui_base.gd nav_stack/_nav_push/_nav_back/_open、game_menus.gd _draw_hub、game_place.gd _go_title、game_screens.gd Esc）：找出還會回錯頁、堆疊殘留、手把 B／Esc 行為不一致的情況（列出具體路徑：從哪開→按什麼→到哪）。
2. 戰績勝率（game_modes.gd _record_match、unit_*_rec）。
3. 角色背面（kit.gd back、kingdom.gd、fantasy.gd）、轉身出手格（sprite_cache.gd ensure_turn_atk、ta_tex、draw_unit；battle_units.gd atk_face 插值）、圖鑑近看與 codex_bake.gd：bug、靜態變數殘留、記憶體、子視窗生命週期。
4. 時序：battle_state.gd proj_wind／proj_phase、view_buffer.gd delay 與 cmd_snap、battle_view.gd 軍令欄、replay_view.gd 軍令標記。
5. 設定：恢復預設（SET_KEYS）、預設預覽、全螢幕 10 秒、代碼自動辨識、車輪戰代碼 NTW1、試玩回報、校對包。
6. ledger 裡每條「Ruling」表態同意／不同意＋理由。
輸出：最多 12 條實際問題（檔案:行號、觸發條件、後果），依嚴重度排序；繁體中文。
