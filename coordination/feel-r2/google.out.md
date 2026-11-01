### 1. 第 1 輪 8 項改善逐項檢視

1. **三層繪製＋角色縮小 8%**：[03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/03_battle.png) 血條與小旗已能穩定浮在最上層，但中央混戰受限於無額外分離仍疊成一團，且 [04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/04_clutch.png) 鏡頭放大時第一層（腳底圈／菱形）與第二層（身體）座標轉換不一致，導致全場腳底標記與角色身體嚴重脫離錯位。
2. **✓✗ 改深色圓底＋亮綠勾／亮紅叉徽章**：[06_puzzle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/06_puzzle.png) 與 [07_duel.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/07_duel.png) 的克制徽章辨識度大幅提升，唯 [07_duel.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/07_duel.png) 同列垂直相鄰擺放時，下方單位頭頂的徽章會壓在上方單位的腳底圈上。
3. **箭矢改木色箭桿＋銀色箭簇＋隊伍色尾羽＋白點拖尾**：[03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/03_battle.png) 的箭矢徹底擺脫棉花棒感，飛行方向、陣營歸屬與軌跡動感都非常清晰。
4. **最後時刻加暗角，鏡頭至少放大 1.08 倍**：[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/04_clutch.png) 有鏡頭放大與大字提示，但四周暗角極不明顯，「最後時刻！」字樣直接蓋在上方交戰騎兵團上，且放大觸發了腳底標記與身體分離的座標 Bug。
5. **跳字起點更高、錯開 20px、同目標同效果合併**：[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/04_clutch.png) 的「拒馬 ×11 132」合併大幅減少刷屏，但跳字仍常直接蓋在角色臉上與受擊白點特效上（如 [03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/03_battle.png) 右下「衝鋒！35」與 [04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/04_clutch.png) 左側「衝鋒！×2 70」）。
6. **背水改成腳下雙層擴散橘色波紋**：[03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/03_battle.png) 左側藍方弓箭手腳下可見雙層橘圈，比上一輪清楚，但透明度偏低、緊貼藍圈，在深色地面上仍不夠搶眼。
7. **地面蓋一層深藍綠調色、部署分界改成隊伍色虛線**：地面壓暗後整體角色、箭矢與射程圈的對比度顯著提升，藍紅虛線分界也很直覺。
8. **開選單時全畫面暗化並隱藏標題字**：[08_settings.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/08_settings.png) 與 [09_puzzles.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/09_puzzles.png) 背景壓暗並隱藏大標題後乾淨許多，但 [01_title.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/01_title.png) 主選單的半透明黑底只罩住標題上半部，下半部選單按鈕仍直接壓在背景混戰成團的角色身上。

---

### 2. 新的分數：**7.6 ／ 10**
（地面調色、箭矢重繪、徽章底座、預算與設定 UI、結算 MVP 立繪都有感升級；扣分主要在於 `04_clutch.png` 鏡頭縮放導致腳底圈與角色身體分離的渲染 Bug，以及主選單／混戰視覺重疊。）

---

### 3. 還剩的前 3 個問題（純程式可解）

1. **修復鏡頭縮放時「腳底標記層」與「角色身體層」的座標不一致（必休 Bug）**：[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/04_clutch.png) 放大 1.08 倍時，所有藍圈與紅菱形都留在未縮放（或不同原點）的座標上，跟角色身體完全脫節；請確認三層繪製共用同一個 Camera transform 矩陣。
2. **「純渲染層」微幅視覺錯開（不改 `MIN_SEP` 物理規則）＋特效／橫幅避讓**：既然不動碰撞規則，可在繪製身體與跳字時，依單位 ID 或重疊鄰居數加 `±3~5px` 的純視覺繪製偏移（render-only jitter），並將 [04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/04_clutch.png)「最後時刻！」移至頂部 UI 條下方、調降受擊白點粒子數量與不透明度，避免把交戰角色完全蓋白。
3. **主選單背景遮罩延伸＆結算判詞與 MVP 口徑一致**：[01_title.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/01_title.png) 的半透明黑底應從標題一路延伸包住整個按鈕區（或開局背景改用排陣／遠射畫面而非中央疊團）；[05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/05_result.png) 判詞寫「紅方的騎兵打出關鍵輸出」但右側大立繪卻是「MVP：紅方的弓箭手」，建議判詞標明「騎兵軍團總輸出最高」與「單兵 MVP：弓箭手」以免玩家困惑。

---

能不能拿去做商店頁截圖與試玩版：**有條件可**（修掉 [04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel2/04_clutch.png) 鏡頭放大時腳底圈與身體脫離的穿幫 Bug 後即可上線試玩與截圖）。
