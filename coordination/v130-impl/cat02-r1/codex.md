只讀靜態審查；有 6 條必改：

1. **A 的 No-Go 證據不足**：[cat02-plan.md:19](/mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl/cat02-plan.md:19) 把整合成本當硬門檻失敗；引用的切片檔未找到，桌機數字也未涵蓋 §19.2。應試較低成本候選：沿用圖集給 Sprite3D、既有 2D 演出經透明 SubViewport 貼立牌、HUD 保留投影錨點；不能直接斷言效果全部失去。

2. **沒有實作傾斜投影**：[battle_units.gd:457](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:457) 宣稱偏離俯視 20°，但 [game_screens.gd:700](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:700) 仍只有原本縮放平移。須補投影與反算，或明訂縮減方案。

3. **崩塌高度永遠不更新**：[battle_units.gd:471](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:471) 讀共用初始 terrain；模擬在 battle_sim.gd:191 複製、2429 改格。須依呈現 tick 同步牆格及快取，涵蓋重播跳轉；後畫碎石不能替代。

4. **可見牆面與點擊不一致**：[battle_units.gd:506](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:506) 頂面向北越界 12px，free_place.gd:51 仍按地面反算，點可見牆可能落到北側空地。須補高度命中測試，符合 §1.1。

5. **缺牆後遮擋**：[game_screens.gd:720](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:720) 先畫全部高度、再畫角色，所以高度不會蓋單位、選取／射程圈及跳字，卻讓北側兵完整壓在牆上。須補深度交錯與淡化；高度小於半格的測試無法驗證此事。

6. **靜態高度應烘焙**：[battle_units.gd:483](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:483) 每幀掃格、貼頂面及畫線，重新引入已知成本。應按地圖／大小／視角／地形版本快取，補 B 的 ABBA p95／p99，不能引用 A 的數字。

核對無誤：Q=500 對應 32px；大小圖共用換算，格內索引與模擬一致，隊伍差異在邊界取整。簡化／正上方會關高度。save.gd:123、663 使缺鍵／錯型回 true；game_menus.gd:1004–1016 全字典匯出並 sanitize，NTS1 未漏。測試 :785 尚缺上述整合案例。

結論：有條件
