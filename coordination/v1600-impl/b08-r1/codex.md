- [battle_fx.gd:1036](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:1036)：繪製另上移最多 8px；513 行紙條外擴、引線也未入框。量測零遮蓋／裁切失真，須共用完整幾何。
- [battle_units.gd:526](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:526)：頭胸框漏掉受擊位移、傾斜及幽靈漂浮；須涵蓋實際姿勢。
- [battle_fx.gd:266](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:266)：關鍵字豁免面積上限，無空位仍蓋臉；擁塞時直接違反 S4，須合併／縮排。
- [battle_fx.gd:299](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:299)：只限垂直距離；橫移及夾盤後可超過 1.5／2.5 格，須檢查最終位移。
- [battle_fx.gd:649](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:649)：slash 仍畫純白，spark 亦繞過亮度上限；測試只量 glow／boom，不能證明全特效合格。
- [battle_visual.gd:1211](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/battle_visual.gd:1211)：p99 量第二次排版，首次已丟字，低估成本；須量首次並補倍速、暫停、跳轉、縮放案例。

結論：不可
