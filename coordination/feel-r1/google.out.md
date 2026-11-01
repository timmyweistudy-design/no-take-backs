以下為完整檢視 [review-input.md](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/review-input.md) 與 9 張實機截圖後的評測回覆：

### 1. 可愛度與統一感：6.5 / 10 分
* **評價理由**：程式向量繪製的 Q 版角色本身相當討喜（大眼、紅腮紅、圓頭比例與五兵種特徵都很清楚），但與 Cainos 像素地圖放一起時，「向量平滑高飽和 vs. 像素顆粒低飽和」的材質割裂感明顯。
* **最違和的三個地方**：
  1. **邊緣銳利度與解析度衝突**：角色是平滑抗鋸齒的 `#1A1A1A` 粗黑描邊向量圖，但地面小碎花與兩側樹木（見 [01_title.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/01_title.png)、[02_place.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/02_place.png)）是無黑邊、放大後呈方塊鋸齒的像素圖，兩者像不同遊戲疊在一起。
  2. **棋盤外框與深色背景斷層**：棋盤四周是一圈死板的純色直線棕框，外圍則是近乎純黑（`#111A16`）的空曠底色，兩側像素樹直接「浮」在黑底上，缺乏草地邊界過渡。
  3. **特效幾何感過重**：[03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/03_battle.png)、[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/04_clutch.png) 中的飛行箭矢像「白色圓頭棉花棒」，死亡與受擊煙塵則是單純的半透明白圓球，與 Q 版角色及像素地面的風格都脫節。

---

### 2. 可讀性（48 隻混戰表現）
* **2 秒內能否分辨**：外圍散開的弓兵、上下路衝鋒的騎兵，靠著「藍圓／紅菱形底座」與綠兜帽、小馬剪影，**1 秒內即可秒辨**；但中央主戰團擠在一起時，**無法在 2 秒內看清兵種與數量**。
* **哪裡會糊**：
  1. **中央肉搏團（Z-order 疊壓）**：[03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/03_battle.png) 中央約 15 隻步兵座標高度重疊，後排的藍圓／紅菱底座被前排身體完全遮擋，劍士銀盔與盾兵灰盔混成一團灰白色塊，刺客也埋在裡面看不見。
  2. **死亡白煙＋跳字＋血條三層交疊**：[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/04_clutch.png) 中央「拒馬 ×11 132」、「拒馬 ×9 108」與大量白色煙霧圓點、破盾方塊及血條疊在同一塊，直接蓋住存活單位的臉與武器。
  3. **背水光圈被吃掉**：[03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/03_battle.png) 左上雖有紅字「背水！攻速提升」，但在混戰團腳下幾乎找不到橘色光圈。

---

### 3. 激烈感（04 最後時刻、05 結果戰報）
* **[04_clutch.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/04_clutch.png)（最後時刻）**：目前只有畫面中上方浮出一行「最後時刻！」黃字，鏡頭與背景毫無變化，張力不足。**建議加**：四周黑色暗角（Vignette）、雙邊血條外框脈衝發光、鏡頭微幅 Zoom-in（1.08 倍）聚焦殘存戰團。
* **[05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/05_result.png)（結果戰報）**：數據邏輯很棒（輸出／承傷對照、破盾／拒馬統計、MVP），但視覺太像後台報表：
  1. 「領先交換 0 次・勝負在第 56 秒鎖定・最大落後 0%」遇到碾壓局全是 0，讀起來很乾，應改用動態戰況判詞（如「紅方騎兵雙路穿插，56 秒完封藍方後排！」）。
  2. MVP 只有一行小字，旁邊應直接畫出該 MVP 兵種的放大 Q 版立繪＋金色光暈。

---

### 4. 只用程式就能做到的改善（前 8 名，依效益排序）
1. **同格／近距軟性碰撞推擠（Boids Separation）**：設定最小間距 `14px` 的排斥力，避免 [03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/03_battle.png) 中央 10 幾隻角色完全疊在同一個座標點，這是救混戰可讀性最關鍵的一步。
2. **預覽標記「✓ / ✗」改高對比徽章**：[06_puzzle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/06_puzzle.png)、[07_duel.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/07_duel.png) 敵我頭頂的深綠 `✓` 與暗紅 `✗` 幾乎融進草地與黑描邊。請改畫在半徑 `9px` 的深色圓底（`#111827`）上，字體改用亮綠 `#4ADE80` 與亮紅 `#F87171` 並往上偏移 `8px`。
3. **箭矢重繪為帶尾羽錐形＋拋物線殘影**：把 [03_battle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/03_battle.png) 的「白棉花棒」改為長 `16px` 木色箭桿（`#D97706`）、前端 `5px` 銀色三角箭簇、尾端雙開叉陣營色尾羽，並加上長 `24px`、透明度 `0.35→0` 的漸層飛行拖尾。
4. **最後時刻「暗角＋聚焦」演出**：觸發時用程式疊加四周徑向漸層黑框（外圍 Alpha `0.45`、持續 `0.3s` 淡入），並將棋盤 Canvas 向存活單位重心放大 `1.08x`。
5. **跳字防重疊佇列與拉高飄移**：將跳字起始高度上移 `18px`，同區域 `0.25s` 內的跳字強制垂直錯開 `16px` 並帶微幅拋物線彈出，不再直接糊在交戰單位臉上。
6. **背水狀態改為身體外發光＋腳底雙環脈衝**：單靠腳底橘圈在人群中必被遮擋，改為每 `0.6s` 擴散一次的 `#FF6B00` 雙層波紋（半徑 `14px→22px`），並在單位身體外圍加 `2px` 橘紅呼吸描邊。
7. **壓暗並柔化地面像素貼圖**：在 Cainos 地面圖層上蓋一層 `rgba(15, 23, 42, 0.18)` 的深藍綠調色遮罩，降低碎花對比度，並將雙陣營部署分界線改為 `2px` 寬、`6px` 間距的半透明虛線（Alpha `0.4`），讓 Q 版角色跳出來。
8. **彈窗背景加暗化遮罩與毛玻璃**：[01_title.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/01_title.png) 標題文字直接壓在 AI 混戰兵團上、[09_puzzles.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/09_puzzles.png) 彈窗頂部切到半截「落子無悔」大字；開啟選單時應先蓋一層 `rgba(0,0,0,0.65)` 全畫面遮罩並隱藏底層大標題。

---

### 5. 介面（字級、按鈕、資訊密度）問題
* **頂部進度條與文字重疊**：[02_place.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/02_place.png) 上方「藍方 已用 57/100 金 11/24 隻」直接疊在藍色進度條正中央，亮藍底配白字對比度差；應將文字移至進度條上方或加深色字體描邊。
* **殘局金幣不足的紅字太暗**：[06_puzzle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/06_puzzle.png) 下方「盾兵 5 金」因餘額不足變暗紅字，在深灰藍卡片底色上幾乎看不清，建議改為整張卡片半透明（Alpha `0.45`）但維持高亮度紅字 `#F87171`。
* **設定與殘局選單過於扁平單調**：[08_settings.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/08_settings.png) 的「開／關／70%」全是一模一樣的灰框按鈕，無法一眼看出開關狀態（建議「開」改亮綠或琥珀色底，音量改為橫向進度拉桿）；[09_puzzles.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-feel/09_puzzles.png) 十個關卡按鈕沒有過關勾勾、推薦難度或敵方主力小圖示。

這版美術能不能拿去做商店頁截圖與試玩版：**有條件可**（免費試玩版可直接上；但若要放 Steam 商店頁截圖，必須先修好「混戰重疊成一團」、「棉花棒箭矢」與「預覽 ✓✗ 看不清」這三項程式視覺問題）。
