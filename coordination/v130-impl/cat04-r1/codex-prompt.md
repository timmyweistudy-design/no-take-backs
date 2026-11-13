你是《落子無悔》(Godot 4.6.2) 1.3.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 4 大類：規劃 coordination/v130-impl/cat04-plan.md；方案 docs/2026-11-13-v1.3.0-plan.md §5；差異 coordination/v130-impl/cat04-r1/diff.patch。
內容：ui_base UNIT_SCALE 0.92→1.15（戰場角色 1.25 倍）、dev_main 對比量框跟尺寸、battle_units focus_scale（跟拍那隻 1.4 倍）、受傷掉漆貼花 chip_tex／_chip_decal、kingdom.gd 個性小物 _trinket 與騎兵發條鑰匙、palette 新色。
請檢查：①UNIT_SCALE 變大後，所有寫死像素（頭頂符號、血條、跳字錨點、點兵判定、選取圈、xray、圖鑑小劇場比例、標題示範戰場、擺陣預覽與拖曳、碰撞以外的重疊判斷）有沒有沒跟著縮放的；點兵（_battle_click／hover）用的半徑；②focus_scale 只放大身體與木座，頭頂血條／標記是否錯位；③掉漆貼花：u.hp／max_hp 在 view 物件上是否存在、召喚物、巨獸、倒下、透明度、鏡像（face）位置、每幀成本；④小物會不會在背面／轉身中間格／圖鑑放大時穿幫；⑤其他。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
