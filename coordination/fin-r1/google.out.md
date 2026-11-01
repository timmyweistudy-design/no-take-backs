### 1. 錯位修好了嗎？[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/04_clutch.png) 現在的問題還剩什麼？

* **腳底圈與身體錯位：已完全修好**。在 [04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/04_clutch.png) 鏡頭放大狀態下，藍紅雙方的身體都精準落在各自的圓圈与菱形底座內，血條、飛箭與陣亡殘影座標皆已對齊。
* **其餘修正確認**：[01_title.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/01_title.png) 暗底延伸至按鈕區後主選單清晰度大增；[03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/03_battle.png) 密集交戰處加入 ±4px 錯開後不再疊成單一紙片；[05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/05_result.png) 判詞改為「紅方的騎兵部隊總輸出最高」，與「單兵 MVP：紅方的弓箭手」邏輯完全分離不再矛盾（惟結算面板頂部邊緣後方仍露出一小截「最後時刻！」金色字頂端，建議結算彈出時直接隱藏該橫幅）。
* **[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/04_clutch.png) 剩餘問題**：
  1. **「最後時刻！」壓住上路交戰單位**：橫幅移到 HUD 下方後，正好壓在最上排藍方劍士的頭頂、血條與飛箭上。建議字級微縮，或觸發顯示 1.5 秒後淡出／縮至角落，避免常駐遮擋上路戰況。
  2. **浮動戰鬥文字重疊與數字連黏**：左側「衝鋒！×2 70」與右側「衝鋒！35」直接蓋在角色臉部與血條上；中間「拒馬 ×11 132」、「拒馬 ×9 108」的次數與總傷害僅空一格，容易誤讀成萬位數，建議改為 `拒馬×11 (132)` 並將飄字起點往上提。
  3. **陣亡骷髏殘影略顯擁擠**：中路與右路同時死傷時，骷髏頭、白色粒子與存活單位疊在一起，建議加快骷髏殘影的上飄與透明度衰減速度。

---

### 2. 新分數

* **8.3 / 10**（較上輪 7.6 提升 0.7 分）。最致命的鏡頭縮放錯位與結算文案矛盾均已根除，戰鬥與介面完成度已達標。

---

### 3. 膠囊圖評估（[header.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/header.png)、[main.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/main.png)、[library_capsule.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/library_capsule.png)、[small.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/small.png)）

* **[small.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/small.png)（462×174）看不看得清標題？**
  中文「落子無悔」**看得清**，但下方英文「No Take-Backs」在縮圖下偏小且邊緣微糊，兩側小兵也略顯細碎。
* **構圖修改建議（純程式可改）**：
  1. **修正頂部半透明黑帶蓋住上半排小兵的問題**：目前橫幅黑底畫在角色圖層上方，導致左右兩軍上半部 6～8 隻角色臉部變暗發髒。請改為**先畫黑底再畫角色**，或將兩軍 Y 座標整體下移，讓開頂部標題帶。
  2. **填補中央空洞、增加對決動感**：[header.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/header.png) 與 [main.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/main.png) 標題下方的中央草地完全空白。建議把兩軍往中間拉近，並在中央畫上紅藍中線虛線與 5～6 支對射飛箭（含尾跡），立刻就有交戰張力。
  3. **[small.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/small.png) 放大重點**：小圖中將標題字級放大 20% 並加深文字黑框；左右兵力減半（各留 5 隻）但角色縮放乘 1.3 倍，縮圖辨識度會好很多。
  4. **[library_capsule.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-fin/library_capsule.png) 留邊**：左右最外側的騎兵與弓手緊貼畫布邊緣被切到一點，左右各往內縮 20px 即可。

有條件可（把膠囊圖「黑帶蓋到小兵臉部」與「中央空白無飛箭」用程式微調重出後，即可直接拿去做商店頁與試玩版）。
