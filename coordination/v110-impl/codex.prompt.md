唯讀，不改檔、不跑 Godot。《落子無悔》V1.1.0 實作完成，請做程式審查（最終一輪）。
讀 coordination/v110-impl/diff.patch（相對 4fd9939 的全部程式改動），必要時 grep 原始碼。方案在 docs/2026-11-06-v1.1.0-plan.md，裁決在 coordination/v110-ledger.md（「實作裁決」段）。
鐵則：舊場次 FINGERPRINT 不變、模擬只用整數、畫面狀態不進模擬、存檔壞資料要能清掉、新測試要登記。
請找會出錯的地方（繁中、1000 字內、每條附 檔案:行號、標 Critical／Important／Minor、附具體觸發情境），特別看：
1. 每日挑戰（game/scripts/game/daily.gd、game_modes.gd _start_daily/_daily_finish、game_result.gd _start_mode 的 daily_spec 保留邏輯）：「再來一次」、從每日挑戰回大廳再開一般對戰、挑戰碼、試煉之間會不會殘留 daily_spec 或 challenge_army；紀錄鍵與存檔清理。
2. 遠征路線（_gauntlet_offers、_recruit_pick、_take_reward、game_core 敵方預算、save.gd sanitize_run）：續局、募兵後卡池合法性（10 種上限、有戰鬥兵、試玩版）、foe 值只影響一戰。
3. 敗因摘要（battle_units.gd _collect_mark 的 dmgby 累計、game_result.gd loss_summary）：快轉／重播跳轉會不會重複累計或漏、ev_count 重置。
4. 動畫與特效（art.gd POSE_PROFILE、battle_units.gd 前搖姿勢與受擊、battle_fx.gd chips／sigil／badge、battle_view.gd 連環爆頓格）：跳轉後狀態、簡化特效、效能。
5. 測試框架（run_tests.gd unregistered、check.py suite_map 與快取鍵）：會不會漏測或誤判。
最後一行「結論：可出貨／修完 Critical/Important 後可出貨」。
