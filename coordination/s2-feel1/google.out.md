### 1. 各項目到位檢視（一句話評估）

* **V1 跳字**：**基本到位，但圖層順序有瑕疵**——對比 [`before_04_clutch.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/before_04_clutch.png) 的嚴重字海重疊，[`03_battle.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/03_battle.png) 與 [`04_clutch.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/04_clutch.png) 的黑底膠囊與外框避讓確實達成跳字 0% 互相重疊，但特效圖層（紫色背刺大叉、橘色「!」）畫在跳字上方，直接刺穿並蓋住了膠囊內的文字。
* **V2 最後時刻**：**部分到位**——[`04_clutch.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/04_clutch.png) 的全寬暗帶橫幅、鏡頭拉近 5% 及橫幅區跳字淡化至 0.2（如右上角與橫幅後方的淡化跳字）有落實，但金色暗角過淡幾乎不可見，且左側遠離中央交戰焦點的 5 隻藍方弓兵並未淡化至 0.6（仍維持 100% 不透明度）。
* **V3／V4 特效上限與描邊**：**描邊到位，但同位置疊加仍顯雜亂**——[`12_fx.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/12_fx.png) 中破盾、背刺紫叉、嘲諷同心圓與驚嘆號「!」的深色底描邊非常清晰，但 [`03_battle.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/03_battle.png) 與 [`04_clutch.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/04_clutch.png) 雖清除了漫天黃色虛線，卻在同一交戰點疊了數十個嘲諷圈與碎盾特效，把中央單位完全淹沒。
* **V5／V6 混戰辨識與色盲輔助**：**多數到位，惟戰力條數值繪製重疊**——[`14_colorblind.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/14_colorblind.png) 血條旁的 8px 藍圓 `●`／橘菱 `◆` 加黑邊與出手光圈很清楚，但頂部戰力條右側 `71%` 疑似同時畫了白色描邊字與黑色深色字且未對齊，造成嚴重的黑白雙影疊字。
* **R1 姿態形變與殘影**：**形變到位，但基準點偏移且展示圖缺殘影**——對比 [`before_13_poses.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/before_13_poses.png)，[`13_poses.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/13_poses.png) 的前搖壓扁後仰、揮擊拉長前傾明顯更有張力，但揮擊前傾時身體底部偏離了藍色腳底圓圈中心（像浮空滑出圈外），且 `13_poses` 揮擊格與 `12_fx` 皆未呈現 140° 雙層月牙殘影。
* **R2 受擊後退**：**靜態到位**——[`13_poses.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/13_poses.png) 受擊格可見角色相對待機位置略微後移並搭配閉眼受擊表情。
* **R3 狂熱與衝鋒特效**：**紅眼與閃芒到位，氣場脈衝不明顯**——[`13_poses.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/13_poses.png) 的狂熱紅眼與騎兵專屬 14px 槍尖閃芒清晰可辨，但狂熱角色周圍看不出氣場脈衝光環。

---

### 2. 分數：**7.5 / 10**
> 跳字黑膠囊避讓、姿態壓縮拉伸、特效深色描邊與色盲符號較改版前有大幅躍進，但圖層繪製順序（特效蓋跳字）、UI 文字疊影與同格特效堆疊仍需收尾。

---

### 3. 前 3 個程式做得到的問題

1. **修正渲染圖層順序（Z-Order）與戰力條疊字 Bug**：
   * 在 [`03_battle.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/03_battle.png) 與 [`04_clutch.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/04_clutch.png) 中，紫色背刺「X」與「!」畫在跳字膠囊之上（例如遮住 `衝鋒！35` 與 `背刺！×6 (240)`），請將渲染順序改為：`單位 -> 地面/擊中特效 -> 跳字膠囊 -> 頂部橫幅 UI`。
   * 修復 [`14_colorblind.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/14_colorblind.png) 頂部戰力條 `71%` 的繪製邏輯：色盲模式下應**替換**原有白字與黑框描邊，改為單次繪製純深色字，避免重複繪製產生重影。
2. **補齊「同座標同類特效去重冷卻」與「非焦點單位淡化」**：
   * 僅限制全場特效總數 40 個仍會讓 20 個破盾／嘲諷同心圓疊在同一格（如 `03_battle` 中央混戰團完全看不見角色），請在生成特效時加入空間去重（例如半徑 `24px` 內同類特效 `0.15s` 內最多顯示 1～2 個）。
   * 修正 `04_clutch` 非焦點淡化判斷：計算單位與鏡頭焦點中心的距離，超過閾值者（如左側 5 隻弓兵）確實乘上 `alpha = 0.6`。
3. **修正揮擊前傾的旋轉樞紐點（Pivot）**：
   * 在 [`13_poses.png`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s2/13_poses.png) 的「揮擊」與「前搖」格，角色旋轉與縮放時應以**腳底中心（接地圓圈中心）**為 Pivot，避免前傾 22° 時雙腳滑出藍色底圈外。

S2 可不可以過：**有條件可**（修完上述 3 點純程式圖層／疊字／去重與 Pivot 問題即可過關）。
