必改 1 條：

- **P2 結果頁殘留目標圈**：[game_screens.gd:819](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:819) 只在戰鬥更新／清空 `_focus_ids`；結果頁仍畫 `view`，[battle_units.gd:844](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:844) 卻未限制戰鬥狀態。重播中跟拍後返回結算，舊目標 ID 若仍存活便誤畫朱紅圈。應在非戰鬥清空，並限制目標圈僅戰鬥顯示。

座標系正確：頭頂記號在 game_screens.gd:834，早於 838 的 IDENTITY。與隊色光圈（battle_units.gd:849）、虛線底座（1428）位置及語意不同，無必改重複。

結論：有條件
