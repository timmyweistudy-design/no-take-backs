唯讀審查，不要改檔、不要開遊戲。《落子無悔》第十輪實作（git diff b6b36a6..HEAD，方案 docs/2026-11-05-v1-polish-plan-v10.md）。重點查（附 檔案:行號，沒證據別列）：
1. 背景執行緒：battle_view.gd pre_thread、game_core.gd ai_thread。離開、重入、覆蓋層、手把 Esc、_on_start 重複觸發、ai_busy 期間切語言或關視窗，有沒有卡死、競態、Thread 沒收？
2. 遠征存點：game_core.gd _gauntlet_save/_resume、save.gd sanitize_run。挑戰、獎勵 2（換兵數）、存檔舊版、壞資料、輸掉、通關、試玩版前綴。
3. 離開確認 _request_leave：覆蓋層 leave 與 Esc、手把 B、結果頁、重播中、watch_mode、系列結束。
4. 最後一擊 _check_final、勝利跳躍：重播、跳轉（seek）、暫停、倍速、view 與 sim 不同步、_on_skip，有無卡住或狀態沒清。
5. 試玩版：_demo_ok、_lobby_block、_watch_code_str、預設規則組合會不會讓試玩版大廳第一次就開不了打（例如 last_rules、預設地圖、卡池）。
6. B9 BATTLE_DY：鏡頭下移後，重播點選兵、_upos、跳字排版、clutch 推近、螢幕座標的特效有沒有錯位。
7. 提示 _pk：Input.get_joy_name、Keymap、鍵盤滑鼠切換。
8. 改動有沒有動到舊場次位元組（battle_sim 不該變）。
最多 10 條必改，由重到輕：問題｜證據｜玩家碰到什麼｜修法。繁中 1200 字內。最後一行「結論：可／有條件／不可」。
