### 《落子無悔》V1.3.0 實作審查（第 1 輪）

#### 1. 轉身中間姿勢（[`turn_strip.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/turn_strip.png)）
頭與身體分開縮放確實改善了頭部壓扁問題，但**「局部紙片感」與「圖層穿插破綻」仍明顯**：
* **嚴重 Bug（雙武器重影）**：第 3 列（騎兵）與第 4 列（長槍兵）的**最右格（第 7 格反面）**出現**兩把長矛／兩支槍頭重疊**，轉身結束後前景武器未清除或舊圖層未隱藏。
* **五官被武器橫切**：第 1 列（劍兵）、第 3 列（騎兵）、第 4 列（長槍兵）在 **第 3～5 格（`cos 0.55`、`0.3`）**，近側武器移到身前時直接貫穿眼睛與臉部正中央，視覺像「吞劍／插臉」。轉身時武器應隨手部微降或偏移避開五官。
* **盾牌與馬身變成薄紙片**：
  * 第 2 列（盾兵）**第 4、5 格（`cos 0.3`）**：人物轉向鏡頭時，持在側前方的盾牌在透視上應「越轉越寬（露正面）」，目前卻跟著身體水平壓窄成 `0.3` 寬的細長藍條擋在臉中間，完全違反透視。
  * 第 3 列（騎兵）**第 4、5 格（`cos 0.3`）**：人頭不扁但底下的木馬被水平壓成極細直條，頭重腳輕像插在木棍上，馬身窄位下限應設為 `0.55`。
* **第 5 列（史萊姆）**：第 1～7 格輪廓完全沒變、僅眼珠微移 `1~2px`，看不出轉身動感，建議轉身中段加入微幅縱向擠壓（寬 `0.92`、高 `1.06`）與頂端尖角擺動。

---

#### 2. 木座、手繪圈、粉筆線、牆邊與 UI（[`02_place.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/02_place.png)、[`03_battle.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/03_battle.png)、[`52_map_ice_battle.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/52_map_ice_battle.png)、[`ui_tex_before_after.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/ui_tex_before_after.png)）
* **腳下三層（隊伍圈吃掉木座）**：步兵腳下的高彩度藍／紅隊伍圈＋粗黑邊太搶眼，像踩著塑膠飛盤，完全遮住內層木座（僅騎兵高木桶可見）。建議：**木座高度加厚 `+2px` 並作為最外層實體底盤**，隊伍色改為木座側邊塗漆或內圈細線（彩度 `-20%`、線寬 `1.5px`）。
* **手繪射程圈（多兵重疊變吵）**：[`02_place.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/02_place.png) 多隻弓箭手的雙線手繪圈交錯成網，干擾格線。建議：非選中／非 hover 單位的常駐射程圈透明度由目前約 `0.35` 降至 **`alpha 0.12~0.15`**，且改單線。
* **粉筆虛線（彩度過高像塑膠標線）**：在草地與冰面（[`52_map_ice_battle.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/52_map_ice_battle.png)）上藍紅虛線過於鮮豔均勻。建議：彩度降 `30~40%`（偏粉白：`#88B4CC`／`#D48A84`），`alpha` 設為 **`0.55`**，單段長短做 `±25%` 隨機變化。
* **不規則磨損邊（高頻抖動像破圖鋸齒）**：[`ui_tex_before_after.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/ui_tex_before_after.png) 下排與戰場木框內緣的噪波頻率太高，像抗鋸齒失敗的毛邊。建議：**波長拉長 `4~6 倍`**，改為每邊僅 2～3 處手工削角／微凹（振幅 `1~1.5px`）。
* **走勢圖漏標倍數**：[`05_result.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/05_result.png) 走勢圖前段仍貼平中線，且**未見縱軸放大倍數標示**。

---

#### 3. 剪影表辨識度（[`silhouettes.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/silhouettes.png)）
* **左起第 2（盾兵）、第 7（投擲手）、第 18（骷髏法師）太像**：三者武器／盾牌皆緊貼身體內側，黑剪影全成「圓頭膠囊狀」。
  * **招牌改造**：盾兵（#2）盾牌往外推 `3~4px` 並加寬方盾角；投擲手（#7）背後加凸出大藥劑包、手舉燒瓶超出頭頂；骷髏法師（#18）兜帽後尖角拉長外翹、手持骨杖外探。
* **第 14（大史萊姆）與第 21（小史萊姆）完全同形**：僅大小差異，建議大史萊姆頭頂加晃動水滴觸角或皇冠。

---

#### 4. 必修與建議
* **必修（5 條）**：
  1. 修正 [`turn_strip.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/turn_strip.png) 騎兵與長槍兵第 7 格的**雙武器重影 Bug**。
  2. 修正轉身 `cos 0.55/0.3` 時武器橫切五官，以及**盾兵轉正面時盾牌反向變寬、騎兵馬身保底寬度 `0.55`**。
  3. 調換腳下視覺層級：**厚木座外露**，隊伍圈收縮或改塗木座側邊，消除塑膠圈感。
  4. 降低非焦點手繪射程圈透明度至 `0.15`，粉筆虛線降彩度 `-35%`、透明度 `0.55`。
  5. 補上 [`05_result.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl1/agy/05_result.png) 走勢圖漏掉的縱軸倍數標示與曲線放大。
* **建議**：將 UI 木框與紙張的高頻鋸齒噪波改為低頻長折線削角；拉開盾兵、投擲手、骷髏法師的外輪廓剪影。

結論：P0 方向正確但轉身第 7 格有雙武器 Bug、中間格武器切臉且盾馬透視相反，需先修完 5 項必修並調降場地線圈彩度與高頻毛邊後再進入下一輪。
