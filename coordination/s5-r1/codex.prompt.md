# 程式輪 S5＋S3／S4 修正（Codex 唯讀，第 1 輪）

請看 `git diff 7d992d6 HEAD -- game/`。

**S5（da2d282）**：
- scripts/ui/replay_view.gd：新層，介於 codex_view 和 game_screens 之間。
  - 重播控制：暫停、倍速、點時間軸跳轉（_seek：同陣型從頭快轉、清空展示／音效狀態、重算 ev_count）、點兵跟拍（_battle_click／_follow_update）。
  - 覆盤：_open_review、review_changes、_rv_try（只准改一隻）、_rv_set_type、_rv_cell、review_run、_rv_play（kind review）、rv_base。
- scripts/game/battle_code.gd：NTB2 對戰代碼。
- game_screens：結果頁「覆盤」「對戰代碼」、標題「觀看對戰代碼」、_replay 對 review 重播覆盤陣型。
- 測試 test_replay_tools：代碼來回、竄改、版本不同；覆盤計數、重算一致；跳轉後狀態與結局一致；覆盤播放不寫存檔。

**修正（cdb440e）**：atk_timing 共用、atk_seq 逐擊交替、試玩評分移位、捲動先夾、陰影疊鏡頭、_draw_smear 依兵種、勝利姿勢、時間軸只寫秒數的退路。

請找：正確性 bug、假綠燈、狀態漏洞。例如：
- 跳轉時 battle_marks 被清掉卻沒重建
- 跳轉在 view.finished 之後
- 跟拍鏡頭與最後時刻鏡頭打架
- 覆盤時 rv_army 預算超過、敵方陣型是否真的不變
- 觀看代碼後的「下一局」會怎樣
- 對戰代碼裡的陣型代碼預算檢查

繁體中文、≤1,200 字，每點附檔名:行號與建議修法，最後一句給「可否繼續」。
