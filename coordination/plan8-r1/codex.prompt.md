唯讀審查，不要改任何檔案。《落子無悔》（Godot 4.6 確定性自動對決）。讀方案初稿 docs/2026-11-04-fantasy-units-plan-v8.md，對照 game/scripts/core/battle_sim.gd、army.gd、ruleset.gd、unit_defs.gd、mirror_check.gd、view_buffer（ui）、game/scripts/game/battle_code.gd、tools/compat.gd、unit_eval.gd。

請（繁體中文、1200 字內、都附 檔案:行號，沒證據別列）：
1. §1 哪些事實說錯或漏了（尤其所有寫死 10 種或 4 bit 的地方）。
2. §4.1「只有舊兵時版本與摘要不變」能不能做？指紋、data_digest、RULES_VERSION、規則 sim_digest、NTB2/NTB3 mismatch、compat 基準、D.COUNT 擴大（例如迴圈、_splash、D.zeros、ev_count）會不會改到舊場次的位元組？怎麼做才安全。
3. §4.3 預留休眠單位方案有什麼坑：alive 判定、選目標、戰力、_check_end、擊殺歸屬、view_buffer、mirror_check、覆盤與結算統計、效能、舊場次不受影響。比「動態插入」好嗎？
4. §3 每種兵在 step() 的五步裡怎麼落地、哪種最危險；有沒有會破壞鏡像、造成僵局或無限迴圈、或數值明顯不合理的規則（孢子菇不動導致時間到、羊互炸連鎖、巫毒遞迴、倒帶、抓人穿越、石堆卡死）。提具體修正。
5. §4.5 圖集做法是否可行；§7 驗收缺什麼；§9 成本與順序。V0 是否該拆，什麼能在試玩前做。
最後一行「結論：可定稿／有條件／不可」。
