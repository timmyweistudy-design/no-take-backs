### 1. 各項實作檢核
* **已做到**：戰力條加「戰力 %」標籤（[03_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/03_battle.png)）、結果頁摘要與數據分頁（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R1C4/R2C1）、標題頁「4 主＋4 次＋系統列」（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R1C1）、20 張禁牌（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R2C4）、離開確認／代碼／遠征續玩與選軍（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R3C1–C4）、各地圖場外裝飾、排兵剋制列底框（[b_maps.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/b_maps.png) R1C4）、事件紀錄底條（[03_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/03_battle.png) 下方）、冰湖降亮與碎冰邊（[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/52_map_ice_battle.png)）。
* **沒做好**：
  1. **設定頁未縮高**（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R2C2）：外框仍過高，下半部留了近半塊空白。
  2. **戰場下移與上緣穿框**（[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/52_map_ice_battle.png)、[53_map_lava_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/53_map_lava_battle.png)、[b_maps.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/b_maps.png) R1C4/R2C2）：雖避開頂部 HUD，但右上紅方騎兵的頭與旗仍超出戰場上內框；且排兵時「剋制列底框」壓到戰場上邊框。
  3. **色盲底座黑邊過細**（[b_maps.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/b_maps.png) R3C2）：黃方菱形底座黑邊不明顯，對比仍弱。
  4. **標題頁小人貼邊**（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R1C1）：右下兵種列最右端角色貼邊微裁切。

### 2. 新裝飾、碎邊是否誤導地形？
* **場外裝飾**在框外不影響判讀，但 [52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/52_map_ice_battle.png) 場外冰山與場內冰洞浮冰造型完全相同。
* **場內邊緣易誤導**：[53_map_lava_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/53_map_lava_battle.png) 熔岩岸邊是一圈深褐圓球，像散落圓石而非連貫石岸；中間灰區與 [52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/52_map_ice_battle.png) 冰面交界都是生硬的「圓弧泡泡邊」；[b_maps.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/b_maps.png)（R2C3）沙漠上下灰磚區像不可通行的城牆高台。

### 3. 冰湖、熔岩當商店截圖夠不夠？
* **不夠當主打截圖**。刺眼問題雖解決，但圓球石岸與泡泡邊的「程式幾何感」仍重，且開局列隊缺乏交戰張力；主打圖建議用草地／奇幻混戰（[03_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/03_battle.png)、[b_maps.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/b_maps.png) R3C4）。

### 必改項目（6 條）
1. **P0**：下調最上排單位生成 Y 軸上限，避免紅方騎兵頭旗穿出戰場上內框（[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/52_map_ice_battle.png)、[53_map_lava_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/53_map_lava_battle.png)）。
2. **P1**：排兵「剋制列底框」縮高或戰場再微下移，避免壓到戰場上框（[b_maps.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/b_maps.png) R1C4/R2C2）。
3. **P1**：設定頁外框高度真正縮減，移除下半部空白（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R2C2）。
4. **P1**：將熔岩圓球石岸與減速區「圓弧泡泡邊」改為連續不規則折線或自然邊緣（[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/52_map_ice_battle.png)、[53_map_lava_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/53_map_lava_battle.png)）。
5. **P2**：加粗色盲模式黃方菱形底座黑邊（[b_maps.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/b_maps.png) R3C2）。
6. **P2**：標題頁右下兵種插畫列內縮，避免最右角色貼邊（[a_ui.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v10-r1/agy/a_ui.png) R1C1）。

結論：有條件
