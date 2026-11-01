唯讀核對完整 diff 與英文 150% 截圖；未重跑測試。

1. **已修好**：`load_all()` 先讀原始資料再遷移；目前支援版本的非 Dictionary `unit_wins` 會修復，也有走正式載入的 v1 整合測試。
2. **已修好**：徽章文字限寬 84 並自動縮字，截圖未見越界。
3. **原溢出已修好**：標題、膠囊與提示列均有字級上限；英文 150% 擺放／對戰截圖未見侵入戰場。
4. **已修好**：攻擊時先將 `walk` 歸零，貼圖與 overlay 的呼吸條件一致。
5. **部分完成**：逐事件扣除攻擊者 FX、0.5px 容差與腳本載入守門均已加入。但 [run_tests.gd:603](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/run_tests.gd:603) 未斷言存活者最後一格確有位移；若末格靜止，插值停住仍可能通過。後搖也只驗證時鐘前進，未直接核對動作完成。

另有一項 **P3 排版偏移**：[game_screens.gd:1093](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1093) 膠囊置中估寬使用 `ts(14)`，實畫卻用 `min(ts(13),15)`；150% 時整組偏左，截圖可見。應用相同字級量寬，並只計兩個間距。

`fit()`、`maxw` 與圖鑑 `_fit_block()` 未見新增阻擋問題。

可否收尾：暫不建議，先補第 5 點的末格移動前提與後搖完成斷言。