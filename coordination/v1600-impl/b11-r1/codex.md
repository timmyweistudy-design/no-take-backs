以下行號均指快照：

- P1 [battle_units:515](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/scripts/ui/battle/battle_units.gd:515)：0.04 是進度比例，實際僅約 3–13ms，倍速更短，達不到 0.04 秒。
- P1 [battle_units:512](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/scripts/ui/battle/battle_units.gd:512)：停在 STRIKE；事件命中／遠程離手卻在 WINDUP。頓幀延後約一段揮擊，飛行物仍照原時序。
- P1 [battle_units:526](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/scripts/ui/battle/battle_units.gd:526)：縱向節奏用持續增加的 time；暫停、全場頓幀仍壓彈，倍速也不縮時。
- P1 [dev_main:1882](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/tools/dev_main.gd:1882)：南北方向直接切換；另寫選路、固定 crouch=1。缺格零不能證明實戰轉身，腳滑僅驗側面。
- P2 [dev_main:1975](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/tools/dev_main.gd:1975)：無腳像素被忽略；全失敗記 -1，仍可 TURNSTRIP OK。應要求八格皆有效。
- P2 [battle_units:1120](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/scripts/ui/battle/battle_units.gd:1120)：繞過 reduce_motion，且乘上受擊壓縮，最低約 0.854；測試未覆蓋疊加。

結論：不可
