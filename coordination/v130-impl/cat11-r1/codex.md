只讀靜態審查，以下 7 條必改；未執行遊戲或截圖驗證。

1. **P1 題單未持久化**：[game_v16.gd:2403](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:2403)。當天拿三星後重開，候選池改變，題單重抽；舊 `done` 仍保留，且限三筆，可能導致新題無法集滿。應存當日題單，題庫移除題目時同步修復題單與完成紀錄。

2. **P1 跳過點擊會穿透**：[game_screens.gd:213](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:213)。只吃按下，放開仍進入第 342 行 `_do_click()`；點擊跳過時可能順便選語言或啟動底下按鈕。須吞掉同次放開。

3. **P2 首次設定順序錯置**：[game_screens.gd:149](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:149)。先設 `first_run`，隨即播放最上層開場；尚未選語言、減少動態便開始動畫，揭幕也露出設定面板。應先完成首次設定，再依設定決定播放。

4. **P2 老闆手被整片遮掉**：[game_screens.gd:804](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:804)。手先畫，後畫的不透明 HUD 覆蓋 y=0～96；手與袖都在此範圍。應調整分層，並依實際棋鐘尺寸定位發條。

5. **P2 表情單位差千倍**：[game_v16.gd:2383](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:2383)。`power/budget` 約為 0～1000，卻和 0.15／0.05 比較；微小差距就得意或慌。須除以 1000。

6. **P2 候選不足違反約定**：[owner_daily.gd:13](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/owner_daily.gd:13)。剩一、兩題未三星時改抽全部，可能完全漏掉待解題；應保留全部未三星題，明定全三星時行為。

7. **P2 清除進度遺留每日狀態**：[game_menus.gd:1213](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:1213)。清殘局未清 `od`，清戰績未清 `od_stamps`，題單快取也未失效；會留下已完成／已蓋印狀態。須納入對應清除項並重建快取。

結論：有條件
