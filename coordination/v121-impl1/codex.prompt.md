你是資深 Godot 4.6 工程審查者。唯讀：不要改檔、不要跑 Godot。
審查 coordination/v121-impl1/diff.patch（《落子無悔》V1.2.1 實作，方案 docs/history/2026-11-07-v1.2.1-plan.md、裁決 coordination/v121-ledger.md）。遊戲在 game/。
重點：
- save.gd 音量遷移與 sfx.gd 四軌（gain_for、trim_db 依 resource_path、play_ambience 試聽計時器在離開設定後的行為）。
- ui_base.gd：qcol／_sb_room 快取、_legible 自動提亮（會不會改到不該改的字：浮雕、緞帶、色盲字）、_ink 透明度規則、_btn 的 btn_paper／懸停金邊／按下內陰影（狀態洩漏、plain_ui）、_probe_glyph。
- tools/dev_main.gd 的對比檢查（text_bg 取樣、外圍一圈退路、門檻、描邊判定）與九宮格邊規則、shot_state、缺圖；tools/layout_check.sh 組合解析。
- map_art busy 鍵、steam 鍵盤回呼、game_result 斷行與緞帶、charts 長條、battle_fx 手把戰報、game_modes 成就與禁兵卡、strings.gd field/pick 與存檔語言清單。
- 確定性：不能碰模擬（FINGERPRINT b8fe741bcbfcf800）。
回答（繁中、800 字內）：每條「檔案:行｜Critical/Important/Minor｜問題與修法」，只列真的問題。最後一行「結論：可出貨／修完再出」。
