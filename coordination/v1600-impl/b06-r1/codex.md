必改 5 項：

1. [map_art.gd:314](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/map_art.gd:314)：南影深達 7／12px，超過契約 5px；右移後未檢查東南格，可染到 BLOCK 輪廓。須裁切並補烘焙遮罩測試。
2. [map_art.gd:343](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/map_art.gd:343)：凹槽北緣內陰影仍只在 tilt 開啟時畫，漏做計畫要求的正上方視角。
3. [screen_owner.py:20](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/screen_owner.py:20)：萬用規則將未知入口全歸 B06；已實測，未登記新頁仍通過。須改明確清單。
4. [ui.gd:2857](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:2857)：便條測試手工塞按鈕，未驗真實繪製註冊，也未測手把聚焦／確認。
5. [ui.gd:2819](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:2819)：對比只驗假定純色；tone_check 僅三頁，不能證明全站紋理暗處合格。須補 B06 紙頁實圖量測。

結論：有條件
