必改 6 項（只讀審查）：

1. **P1** [art_baseline.py:17](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/art_baseline.py:17)：缺 art／units=0 直接略過，只遍歷現值；既有探針消失甚至空輸出仍成功。須核對本次應拍的基線鍵與 units。
2. **P1** [game_v16.gd:81](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:81)：失焦只清 `_held`，未清既有輸入鎖；[game_screens.gd:1197](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1197) 拔手把反而未清 `_held`，下次轉場會復活舊鎖。須同步清理。
3. **P1** [game_screens.gd:1158](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1158)：只鎖左搖桿；右搖桿持續推過轉場，後續事件便直接捲動圖鑑，未等回中。
4. **P1** [ui.gd:2248](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:2248)：斷線後仍補 release、after 不驗數量、恢復只測滑鼠；佇列也看不到右桿直接捲動。100 組可假通過，須驗實際副作用及各來源恢復。
5. **P1** [run_chain.sh:14](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/run_chain.sh:14)：`--stop` 強殺所有 Windows Godot，且忽略失敗；須限定本鏈程序並確認退出。
6. **P1** [run_chain.sh:22](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/run_chain.sh:22)：檢查、覆寫、登記 PGID 無鎖；同名並發或 PGID 尚未寫入時可雙開、混寫。須原子鎖及每輪獨立紀錄。

RC 改法保留原失敗；GROUND_FX 戰鬥路徑未見新增重畫。

結論：不可
