唯讀，不改檔、不跑 Godot。《落子無悔》V1.1.0 第二批實作，請做程式審查。
讀 coordination/v110-impl2/diff.patch（相對 8435794 的程式改動，含尚未提交的部分），必要時 grep 原始碼；新檔 game/scripts/game/workshop.gd、tools/gen/chapter11_drafts.py、tools/gen/chapter11_merge.py 直接讀。裁決在 coordination/v110-ledger.md「第二批」段。
鐵則：舊場次 FINGERPRINT 不變（模擬改寫必須位元等價）、模擬只用整數、畫面狀態不進模擬、存檔／匯入資料要防壞資料。
請找會出錯的地方（繁中、1000 字內，每條附 檔案:行號、Critical／Important／Minor、具體觸發情境），特別看：
1. game/scripts/core/battle_sim.gd 的 E4 改寫（_foes 每隊可選敵人表、_choose_target 的優先級剪枝 min_r／cmin、碰撞 act 參與者表）：在任何兵種組合、技能關閉（skill_off）、潛行、幽靈、偽裝寶箱怪、召喚物、地形下，是否與原本逐一掃描的結果完全相同？_foes 在 step 以外被呼叫的路徑（_v8_* 有沒有間接用到 _choose_target／_nearest_visible_enemy_d2）？
2. workshop.gd（NTP1）：解碼驗證有無漏洞（超大數字、浮點、負數、重複格、兵種越界、召喚物 20/21、試玩版遮罩）、重跑作者解的成本上限、和 PZ.play 的互動；game_modes.gd _accept_workshop／_make_workshop、game_result.gd _ws_ok。
3. puzzles.gd 新目標 flawless／margin、lost_of_type（召喚物、寶箱怪、復活的骷髏）、CHAPTERS=11 對清單、星數總計、成就、存檔的影響。
4. battle_units.gd _draw_xray、battle_view.gd _goal_target_id／_death_extra、勝利小動作：效能、跳轉、簡化特效。
5. dev_main.gd 記憶體檢查的判準改動是否合理（從「換色 2 次 vs 20 次」改成「暖機 vs 換色 20 次」）。
最後一行「結論：可出貨／修完 Critical/Important 後可出貨」。
