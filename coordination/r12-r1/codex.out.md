唯讀審查，未改檔、未重跑測試；以下行號以 **9346354** 為準。未見嚴重問題，但有以下中度缺口。

1. **中｜偵測器會漏報。** [orbit_detect.gd:38](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/orbit_detect.gd:38) 每隻騎兵首次命中後永久 `flagged`；若先被分類 N／T，之後真正的 A／C 不再檢查。分類又只看視窗最後一刻：換過目標便列 T，接近目標便列 N，沒有確認傷害、攻擊或進展；B 也只看目標的移動意圖。故 A=0、C=0 不足以證明沒有卡住。應持續追蹤後續事件，並用整個視窗的狀態與交戰進展分類。

2. **中｜候選點檢查不是到直線的距離。** [battle_sim.gd:623](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:623) 比較的是垂直差。騎兵與弓手連線接近垂直時，即使通過 1500 門檻，候選點仍可能幾乎落在原路線上，甚至先往反方向走。應改用叉積平方比較垂直距離，補近垂直案例。狀態機本身使用整數、差值中點，`nav／chasing` 也納入指紋與鏡像檢查，未見新增的不確定性或左右不對稱來源。

3. **中｜圖集動畫不等價。** [sprite_cache.gd:49](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:49)、[sprite_cache.gd:109](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:109)：攻擊優先會丟掉同時走路的相位；移動／攻擊影格固定睜眼；眨眼格未歸零呼吸，貼圖時又加一次呼吸，造成位置跳動。攻擊與走路六格量化也只是近似，不能稱「完全相同」。

4. **中｜透明與閃白也不同。** [sprite_cache.gd:77](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:77) 對已合成圖像整體乘 alpha；原 `Art.unit` 對每個圖元各自乘 alpha，重疊區域的潛行效果不同。閃白圓沒有跟隨烘焙的攻擊前衝／走路起伏。色盲配色有傳入烘焙且檢查快取配色；headless 提早返回後由 `_unit／_ring` 退回 Art，這部分未見問題。

5. **中｜測試存在假綠燈。** [run_tests.gd:393](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/run_tests.gd:393) 只要求切換次數少，完全不移動也通過；應直接驗證遲滯內外邊界及確實追近。[run_tests.gd:407](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/run_tests.gd:407) 直接 append 標準解，未驗預算、允許兵種、格位重疊等合法性；總數 ≥13 也不能保證每關兩解。現有測試亦未覆蓋圖集等價性。

6. **低｜拆檔本身未見行為遺失。** 佔位函式都有上層實作；[game_screens.gd:633](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:633) 的 process／draw 包裝仍呼叫原流程，僅增加計時。效能模式則應等待快取完成後再採樣：[main.gd:218](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/main.gd:218) 只等一幀，烘焙等兩次繪製完成，起始數據可能混入回退繪圖。

這批可否繼續：**有條件可**。