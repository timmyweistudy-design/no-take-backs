你是資深 Godot 4.6 工程師。唯讀：不要改檔、不要跑 Godot。
《落子無悔》（game/）V1.3.1 補做方案 P2 六項（未提交 diff：coordination/v131-impl3/diff.patch）：每種兵音高（sfx.gd UNIT_PITCH、play_unit、play 多 pitch 參數；battle_view 出手／倒下改 play_unit；測試替身 FakeSfx 補方法）、最後一擊定格（last_kill，勝方擊倒者停在 ATK_STRIKE 0.4 秒）、歡呼波浪（依 x 錯開）、奇幻兵遺物落地（_draw_relic：娃娃針、骷髏頭滾、寶箱金幣）、高光改正上方（孢子菇、投彈兵火罐、沙漏玻璃）、_hand_ring 重用緩衝區。
請找真的 bug（繁中、700 字內，引用 檔案:行）：pitch 參數與 sfx 其他呼叫端相容性（play_ambience、UI 音、測試）；last_kill 在重播、跳播（with_fx false）、暫停、殘局頓格時的行為；_draw_relic 在 reduce_fx、dying 生命週期內是否越界；_hr_buf 是實例變數，多個 CanvasItem 共用 ui_base 是否安全；任何改到模擬或 FINGERPRINT 的地方。最後一行「結論：同意／有條件同意（條件）」。
