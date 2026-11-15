必改：

1. [table_seats.gd:18](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/table_seats.gd:18) 尚非單一來源：結果紙仍寫死（game_result:119），便條未接槽；放大鏡仍直徑160、四角定位（battle_view:1027），棋鐘仍置頂（860）。應接表並落實互斥、隱藏順序。

2. [game_place.gd:1304](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:1304) 肖像鈕無條件貼胡桃木；`_mat_box` 不檢查簡化介面，會重新畫回紋理。須補平塗分支。

3. [ui_base.gd:1124](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1124) 壓暗只看 state；PLACE／RESULT 開大廳等疊層仍新增壓暗。須依實際頁面限定。

4. [tone_check.py:46](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/tone_check.py:46) 缺頁、缺對照直接跳過；空輸入實測仍報 TONE OK，失敗也未回非零碼。須驗完整組合與檔案。

5. [tone_check.py:66](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/tone_check.py:66) 全盤偏色≤3亦過關，不能稱ΔE＝0；內縮區域、大矩形遮罩另留盲區，主鈕也未驗對比。須校準雜訊、縮準遮罩並補門檻。

6. [ui.gd:2734](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:2734) 整合驗收靠字串，甚至鎖定錯誤壓暗條件。須補點擊／焦點、RT＋View、點穿、停用、長卡邊界及結果頁操作測試。

結果 HUD 返回後略過的按鈕原限 BATTLE，靜態未見誤刪結果操作。

結論：有條件
