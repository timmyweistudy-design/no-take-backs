只讀審查，必改 8 項；未執行會寫入的 Godot／版面測試。

1. [battle_view:76](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:76)：精華換段啟動非同步 seek 後未返回，當幀可能用新 sim 推進舊 view，污染緩衝；開始跳轉後應立即停止本幀戰鬥處理。

2. [battle_view:1154](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:1154)：seek 未清 cues，且只淘汰過期 tick。跳回前段會提前畫出舊的遠期事件，洩漏展示緩衝以外的未來。

3. [battle_view:1082](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:1082)：放大鏡未排除 hidden／stealth；偽裝兵跳過 mag_pose 更新，卻可能沿用前隻姿態畫出真身；潛行兵也被畫成全不透明。

4. [game_screens:312](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:312)：雙擊只判 y，涵蓋 GIF／時光機按鈕；放開先執行按鈕而未清 dbl_eat，下一次盤面點兵會被吞掉。

5. [battle_view:128](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:128)：鏡頭仲裁不完整：手動縮放仍被跟拍／最後框選覆蓋；暫停時不套用滾輪與平移；正式局也能透過新增輸入移動主鏡。

6. [game_screens:428](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:428)：鍵盤、右搖桿／扳機不取消三連；滑鼠僅清段表、未停播。未綁定鍵與軸輸入也不收放大鏡，未達任何操作一幀接管。

7. [battle_view:980](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:980)：左下鏡框延伸至 y686，會遮住 y650–690 的時光機按鈕；安全角須排除實際操作區。

8. [strings.csv:1710](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:1710)：字串檢查實跑失敗，新增說明含禁用詞「單位」。四語齊全、色票 486／486；新增測試仍須補上述輸入、非同步換段與跳轉產品流程。

結論：不可
