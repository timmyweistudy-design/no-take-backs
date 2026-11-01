### 1. S2 三個條件檢視與新分數

* **三個條件是否到位**：三個條件皆已確實到位——[s2_04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s2_04_clutch.png) 的傷害跳字已移至所有特效圖層之上且同處特效不再無限疊加、交戰焦點外淡化與暗角明顯，[s2_14_colorblind.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s2_14_colorblind.png) 橘色戰力條上的深色字已去除黑描邊雙影，[s2_13_poses.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s2_13_poses.png) 揮擊前撲雙腳穩留底圈內並補齊了揮擊白弧殘影與狂熱暗紅氣場。
* **S2 新分數**：**8.5 / 10**

---

### 2. S3 每一項檢視與分數

* **U1 圖鑑可捲動**：150% 大字與長文已加上逐行裁切與獨立捲軸（[s3_10_codex.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_10_codex.png)、[s3_10_codex_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_10_codex_en150.png)），但 [s3_10b_codex_scrolled.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_10b_codex_scrolled.png) 捲動時左欄大頭像只要超出頂部就會整張消失留下一塊黑洞，且 [s3_10b_codex_scrolled_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_10b_codex_scrolled_en150.png) 同一畫面拆成三個小捲動區（左欄、右上技能、底部筆記各只露 1～2 行）閱讀較零碎。
* **U2 屬性條**：血量、每秒傷害、射程、速度、價格五項數值與比例長條圖對齊清晰、一目了然。
* **U3 擺放**：[s3_02_place.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_02_place.png) 的弓手射程弧線已裁切於棋盤內、卡片上方有「剋／怕」小頭像、右側 AI 迷霧有顯示難度性格，惟多隻弓手的射程弧線交錯略雜，且小頭像縮太小較難一眼分辨盾兵與劍士。
* **U4 殘局**：[s3_06_puzzle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_06_puzzle.png) 的三階星級條件、鎖頭與左上圖例、騎兵衝鋒預覽與敵方綠勾／紅叉克制提示皆到位；[s3_09_puzzles.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_09_puzzles.png) 有總星數與迷你縮圖，但縮圖圓點以兵種色繪製而未區分藍紅陣營。
* **U5 結果時間軸**：[s3_05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_05_result.png) 具備藍紅拉鋸色帶與關鍵事件標記，但約 6 秒處的第 2 個藍色菱形節點因防重疊被省略文字後變成無標籤孤點，且結算窗右側邊緣露出底層殘留的戰鬥跳字（`0)`、`60)`）。
* **S3 分數**：**7.8 / 10**

---

### 3. 前 3 個程式做得到的問題

1. **修正圖鑑左欄捲動破圖與屬性區固定（[s3_10b_codex_scrolled.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_10b_codex_scrolled.png)）**：目前左欄捲動時若頭像上緣超出裁切區就整張不畫，導致左上角出現大片空白黑洞、只剩右邊孤零零一句台詞。應改用真正的矩形裁剪（scissor/clip rect）平滑裁切，或將「頭像＋名稱＋五條屬性」固定在左欄上半部，只捲動下半部的介紹與綠／紅戰術提示。
2. **修復結果時間軸「無名孤點」與背景跳字殘留（[s3_05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_05_result.png)）**：時間軸當兩個事件太近時（如 3s、6s、8s），文字標籤改為上下交錯排布（一上一下）而非直接隱藏標籤留下無字菱形；同時打開結算彈窗時應隱藏或清除場上殘留的戰鬥傷害跳字，避免從彈窗邊緣穿幫。
3. **殘局選單縮圖區分敵我陣營＆擺放射程線降噪（[s3_09_puzzles.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_09_puzzles.png)、[s3_02_place.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s23/s3_02_place.png)）**：殘局縮圖中間加一條淡中線，並用外圈顏色（藍圈／紅鑽）或藍紅主色區分我方固定棋與敵陣；擺放畫面選中弓手時，只有滑鼠懸停／拖曳的那隻畫亮黃色射程弧，場上其餘已擺弓手射程弧降為低透明度（如 alpha 0.2），避免多條弧線交織成麻花。

S2 可過，S3 有條件可過。
