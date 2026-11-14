- **P2** [game_result.gd:338](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:338)：詳細數據頁固定 `y = 590`，新版 `_star_row` 再下移 28 才畫條件；150% 長文字換行後會壓到底列按鈕（y=646），遮住星級條件。須依實際高度保留空間或移入可展開內容。
- **P2** [game_result.gd:235](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:235)：敗因卡受 MVP 分支阻擋。護送、無損或剩餘戰力目標可能藍方獲勝但 `goal_ok=false`，此時仍顯示藍方 MVP，跳過敗因卡。須優先依目標失敗判定顯示敗因卡。

結論：有條件
