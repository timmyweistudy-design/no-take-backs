只讀靜態審查，未跑 Godot。原 17 場金標準逐字保留；常數抽取未見數值或整數捨去順序改變。必改 5 條：

1. [battle_sim.gd:964](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:964)：時停只清 charge，未清 ride／ride_t；冰封與吸引也漏清。短於再衝期限的暈眩結束後仍能再衝，違反「被暈取消」。統一在施加暈眩時清兩欄，補三種來源測試。

2. [battle_sim.gd:969](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:969)：擋中先設冷卻 120，再於本 tick 減成 119；逾時卻在遞減後設 120。相同結束 tick 的兩種路徑差一 tick。統一冷卻起算位置，測完整 step 的再次可架盾時刻。

3. [game_screens.gd:230](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:230)：RT 工具直接修改陣型，既有落子、放開、開戰卻排隊。同幀先放開 A 再按 RT＋Y，會先對齊才提交拖曳，顛倒輸入順序。工具也應入列，執行時重驗畫面世代與部署權限。

4. [game_place.gd:881](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:881)：自由部署對齊未終止拖曳。按住 A 搬群組時對齊，fp_drag_from 仍是原位置；放開後以舊起點再加位移，造成額外偏移。工具執行前取消拖曳／筆畫，或明確禁止操作中使用。

5. [game_place.gd:849](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:849)：提示寫死 Y／LB，但工具判斷已經 pad_to_default。交換 Y、X 綁定後，照提示按 RT＋Y 會走移除及長按清空。提示應使用目前 pause／prev 的綁定圖示，並補改鍵後經 _input 的整合測試。

_post_vp 的兩條分支均先讀回 Image 再釋放來源；世代檢查前釋放未見懸空貼圖問題。is_sandbox 呼叫路徑及實物開合停演條件未見其他必改。

結論：有條件
