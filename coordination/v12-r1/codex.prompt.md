唯讀審查，不要改檔、不要開遊戲。《落子無悔》新增手動技能（未提交的工作區改動，看 git diff HEAD 與新檔 game/scripts/core/cmd_defs.gd）。確定性整數模擬、左右鏡像、舊場次位元組不能變。重點查（附 檔案:行號，沒證據別列）：
1. battle_sim.gd：_cmd_tick、_cmd_apply、護盾、cmd_can、cast、cmd_play、_hash_cmd。舊路徑（沒開技能）有沒有任何位元組或流程改變？鏡像有沒有不對稱（同 tick 兩隊施放順序、_cmd_cluster 平手、AI 判斷讀到另一隊剛套用的結果）？死亡、召喚物、dormant、幽靈、潛行、hidden 的邊界？傷害與統計（dmg_taken）是否一致？
2. 重播一致性：last_cmds 何時寫入、_cmd_setup、cmd_play 用 cmd_can 檢查會不會讓合法紀錄被拒、seek、覆盤（review_run）、對戰代碼 NTB7、挑戰碼、下一局、series、watch_code。有沒有場景用到舊的 last_cmds？
3. ruleset：NTBR5 往返、validate、sim_digest、equals、key_fields 沒帶技能的影響（例如 _lobby_touch 把開技能的規則當成預設、存成我的預設、last_rules、_lobby_pick）。
4. UI：_cmd_key 攔走 Q／E／數字鍵會不會影響其他功能（暫停、速度、圖鑑、重播）、手把 LB／RB、_btn 焦點、skip、暫停中施放、AI 困難背景計算。
最多 10 條必改，由重到輕：問題｜證據｜玩家碰到什麼｜修法。繁中 1000 字內。最後一行「結論：可／有條件／不可」。
