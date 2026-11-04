路徑相對於 `game/scripts/`。

- P1 `core/battle_sim.gd:763`：最後一隻羊被殺後，待爆尚未處理就判全滅；下 tick 爆炸被吞，可能錯判勝負。
- P1 `core/battle_sim.gd:901`：寶箱怪逐隻改 hidden/sv；一隻先被主力觸發，可讓鄰近敵寶箱同 tick 現身，交換隊伍後時序不同。
- P1 `core/battle_sim.gd:1096`：同列多貓同 tick 吸同一敵兵，按部署欄先到者取得；鏡像後順序反轉，拉向不同位置。
- P1 `ui/game_screens.gd:173`：遠征沿用奇幻卡列，Army.pool 仍是舊十種，敵軍也用舊 `_pool()`；顯示的新兵無法部署。
- P1 `core/ruleset.gd:109`：以非支援判戰鬥兵，純菇／羊／寶箱卡池通過驗證，但 Army.has_combat 永遠為假，無法開戰。
- P1 `core/turn_placement.gd:95`：末手只禁支援；尚無主力仍可放奇襲兵後結束末手，部署完成卻無法開戰。
- P2 `core/battle_sim.gd:1202`：待爆只存羊索引，未存引爆方；連鎖炸死友軍時，擊殺歸羊自身隊伍，違反跨 tick 歸屬規則。
- P2 `core/battle_sim.gd:1023`：時停開始前搖即設 used；被敵方時停打斷會清 windup，卻永遠不能重施。
- P2 `core/ruleset.gd:419`：合法關閉 13 招仍能輸出 NTBR3，解碼卻限 SKILLS.size＝12，自產代碼無法匯入。
- P2 `ui/sprite_cache.gd:99`：同兵種在烘焙中再次 ensure 可產生重複頁；淘汰舊副本無條件 erase loc，使仍在新頁的兵種失聯、退回逐隻繪製。

結論：不可
