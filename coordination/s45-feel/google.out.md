### 1. S4 評估與分數：**8.3 / 10**
- **揮擊殘影依兵種（到位）**：[s4_13_poses.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/s4_13_poses.png) 中，劍士下斬／上挑月牙弧光、盾兵前方三道水平衝擊線、騎兵水平突刺槍芒、刺客紫色交叉 X 斬痕都已明確區分，弓手也確實移除近戰殘影。
- **勝利姿勢（大致到位）**：五兵種皆改為站直、不再與前搖一樣後仰；刺客雙刀高舉、騎兵舉槍都很清楚。不過**弓手的勝利姿勢變成水平拉弓搭箭**（看起來像在瞄準而非慶祝），劍士舉劍幅度也與待機略近。
- **交替招式樣品（部分到位）**：劍士改為上挑到頂、刺客改為雙刀展開，與一般揮擊區隔明顯；但**弓手、盾兵、騎兵的「揮擊」與「交替招式」靜態樣品幾乎看不出差異**（尤其弓手兩格完全相同）。
- **細節強化（到位）**：刺客後手刀加長加粗後雙刀感極佳；騎兵前搖時前蹄抬高明顯。

---

### 2. S3 三點驗證與分數：**9.2 / 10**
1. **圖鑑固定區高度（到位）**：[s3_10b_codex_scrolled_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/s3_10b_codex_scrolled_en150.png) 在英文 150% 下，Cavalry 定位與三行黃色口號完整顯示，不再被裁切，下方捲動區分隔清楚。
2. **時間軸退避只寫秒數（到位）**：[s3_05_result_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/s3_05_result_en150.png) 下方時間軸擁擠處已退避顯示為 `8s`，不再留無字孤點（唯上方 `1st charge 5s` 文字位置偏右，視覺上較靠近 8s 的引線）。
3. **殘局縮圖敵陣（到位）**：[s3_09_puzzles.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/s3_09_puzzles.png) 縮圖改為純紅大菱形後，10 關敵陣輪廓一眼可辨。

---

### 3. S5 好不好懂、好不好用與分數：**8.5 / 10**
- **好懂好用之處**：
  - [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/16_review.png)（覆盤）結構極佳：規則一句話講明，左側 6×9 棋盤金框標示修改格並附金幣統計，右側換兵／重算與「原本 vs 如果」雙色帶上下對照，能秒懂改一隻兵對戰局的影響，還可直接播放驗證。
  - [15_replay.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/15_replay.png)（重播）底部控制列（暫停、三段倍速、拉鋸時間軸＋黃色游標）與右下操作提示直觀易懂；結果頁左上角也有 `Battle code` 可複製。
- **體驗扣分處**：重播時頂部仍留著一般戰鬥的「`速度 1×`」鈕造成雙重倍速控制；時間軸與覆盤色帶似乎以 90 秒滿時長為底，導致 30 秒結束的對局色帶只擠在左邊 1/3、右側大片空白。

---

### 4. 前 3 個程式做得到的問題
1. **重播介面倍速鈕重複與時間軸比例（[15_replay.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/15_replay.png)、[16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/16_review.png)）**：重播模式應隱藏頂部右上角的「`速度 1×`」（或與底部同步），並讓重播／覆盤的拉鋸時間軸以「該場實際結束秒數」填滿寬度（並顯示 `目前秒數 / 總秒數`），避免右半部全黑。
2. **覆盤缺少「修改前對照」與鏡頭跟隨狀態提示（[16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/16_review.png)、[15_replay.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/15_replay.png)）**：覆盤可在「改了 1 隻」旁直接寫出變更內容（如 `弓箭手 → 劍士` 或標出原格虛線框）；重播點兵跟隨鏡頭時，應在該兵腳下畫高亮圈並顯示「跟隨中（點空白處取消）」。
3. **弓手勝利與交替招式姿勢區隔（[s4_13_poses.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s45/s4_13_poses.png)）**：將弓手「勝利」改為把弓高舉過頭（避免像水平瞄準），並讓弓手「交替招式」改為仰角拋射或收弓後退以區隔一般揮擊。

S3 可以過，S4 可以過，S5 可以過。
