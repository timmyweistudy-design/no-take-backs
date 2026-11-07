# 《落子無悔》V1.3.0 第 1 輪：獨立提案

### 1. 截圖視覺與 UX 診斷
* **最像紙片**：
  * [10_codex.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/10_codex.png) 左上騎兵放大立繪與 [01_title.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/01_title.png) 底部兵種列：純平色塊加等寬黑邊，木馬與底座完全無厚度或立體陰影，像扁平剪紙貼在底座上。
  * [52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/52_map_ice_battle.png) 右側整排紅方騎兵與劍士：姿勢、角度、朝向 100% 同步複製，加上轉身瞬間 `scale.x` 正負翻轉，紙板感極強。
* **最機器感／電腦感**：
  * [52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/52_map_ice_battle.png) 中央冰面與兩塊破冰區：完全筆直的矩形邊界、規則排列的白色短斜線與鋸齒白邊，以及兩側幾何三角形松樹，極度像程式繪圖 primitives。
  * [35_fantasy_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/35_fantasy_battle.png) 靈氣圈與波紋、[02_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/02_place.png) 射程弧線與藍紅虛線、方格高亮：正圓、純幾何線段與電腦感霓虹色條（頂部五彩編制條）。
* **不夠好懂**：
  * [03_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/03_battle.png) 與 [35_fantasy_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/35_fantasy_battle.png) 中央混戰團（Mosh Pit）：20 隻兵疊在一起時，黑邊、血條、小旗子與滿天驚嘆號／音符糊成一團，看不出誰在打誰。
  * [03_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/03_battle.png) 底部黑底戰況跑馬燈（紫字、橘字）：打仗時視線在中間，根本來不及低頭讀底部三欄文字。
  * [05_result.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/05_result.png) 戰力走勢圖：前 35 秒幾乎貼平中線，視覺起伏太小，且「領先交換 41s／勝負已定 47s」黃字擠在右上角重疊難讀。

---

### 2. 去紙片感做法（2D 動畫原理與參考作品）
* **轉身（預備動作＋弧線＋假厚度）**：參考 **《Paper Mario》** 與 **《Cult of the Lamb》**——翻面絕不一幀鏡像，而是先往下壓扁（Squash, `scale.y=0.85`）、向上微跳同時 `scale.x` 縮過窄位（約 0.14 秒），在窄位幀將角色外框往背光側偏移 2px 深色塊充當「木雕立牌側面厚度」，落地時帶一點 Overshoot 回彈（`scale.x=1.08→1.0`）。
* **重疊動作（Follow-through）**：參考 **《Wildfrost》** 卡牌棋子晃動——不重繪精靈圖，僅把「武器／盾牌／頭飾」拆成獨立小貼圖或單點錨點，移動與停步時用簡單彈簧公式延遲 2～3 幀擺動。
* **擠壓伸展（Squash & Stretch）**：參考 **《Into the Breach》** 與 **《TABS》**——蓄力攻擊時橫向壓扁、刺出時順攻擊方向微幅拉伸（Skew/Stretch），受擊時瞬間橫向擠壓並閃白。
* **接地（Grounding）**：參考 **《Kingdom Two Crowns》**——底座改為橢圓厚木座（下緣加 2px 深色立體邊），跳躍時木座留地變成陰影縮小、角色本體微浮，徹底擺脫「人跟底盤黏死在同一張紙」的感覺。
* **錯開（Offset）**：用 `unit_id` 雜湊出呼吸頻率（±12%）、相位、搖擺傾角（±3°）與眨眼間隔，破除複製人大軍感。

---

### 3. 去機器感與簡潔好懂的做法
* **消滅幾何原語（去機器感）**：
  * 冰面邊界、草地色塊與光環改用「多邊形頂點微擾＋手繪墨水虛線／羊皮紙拓印圈」，取代完美正圓與直線。
  * [02_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/02_place.png) 頂部刺眼的彩色方塊條改為「木盤凹槽＋雙色木珠／籌碼」；[22_lobby.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/22_lobby.png) 規則設定區改像真實桌遊說明書的鉛筆勾選框。
* **混戰減噪（簡潔好懂）**：
  * **血條聰明隱藏**：滿血與未受擊超過 2 秒的兵隱藏血條；混戰重疊時，只最前排或殘血兵顯示血條。
  * **廢除底部文字跑馬燈**：將「刺客背刺 ×7」改為戰場該兵種頭頂直接彈出「桌遊木牌標籤」，並拉一條短虛線指到發動者。
  * **焦點聚光燈**：關鍵破陣或大招觸發時，周圍微暗 15%、鏡頭輕推 0.25 秒，讓玩家秒懂戰局轉折。

---

### 4. 好玩的新想法（5 條大膽提案）
1. **【純畫面】桌遊「倒棋」物理演出**：兵死掉不要只淡出！改成木製立牌被擊飛後「咔啦」一聲側倒在棋盤上（轉 90 度變灰暗木棋），結束時一隻無形的手（或推尺）把全場木棋嘩啦啦推回木盒。桌遊爽感直接拉滿！
2. **【純畫面】「粉筆戰術畫線」擺陣**：在 [02_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/02_place.png) 擺陣時，桌面自動用粉筆／炭筆畫出我方騎兵預計衝鋒路線、刺客跳躍落點的虛線草圖，開戰後粉筆痕隨戰火漸漸擦除，好懂又有軍師感。
3. **【純畫面】棋盤邊緣「戰利品碗」**：打倒敵兵時，一顆代表敵兵費用的小木幣拋物線飛進畫面側邊的木碗裡敲出清脆木頭聲，不用看頂部百分比也能直覺感受「賺翻了」。
4. **【要新玩法／新規則碼】「地形骨牌／紙板屏風」**：擺陣階段給玩家 1～2 個免費的「木製路障／紙板草叢」可擺在己方半場，用來卡住敵方騎兵直線衝鋒或藏匿弓箭手，真正發揮「落子無悔」的擺陣博弈！
5. **【純畫面】戰後「羊皮紙戰報連環畫」**：在 [05_result.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/05_result.png) 把平淡的折線圖改成三格手繪風「戰報快照」（開局衝撞→關鍵轉折→終局），點擊任一格直接重播該秒數。

---

### 5. 對 [seed.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/seed.md) 各節（A～E）之評議與優先序
* **A 角色立體與生命感**：**同意 A1、A2、A3、A5、A6；修改 A4、A7**。
  * *修改*：A4 即時分層彈簧在 40 隻兵混戰時極易讓 `_draw` 超標（V1.2.1 已 9.61ms，上限約 9.79ms），建議改為「烘焙 3 幀關鍵動態＋整體 Skew 變形」；A7 情緒泡泡在 [03_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/03_battle.png) 已經太多驚嘆號，應先砍舊符號再放。**優先序：A1 > A3 > A2 > A6 > A5 > A4 > A7**。
* **B 去機器感**：**同意 B2、B4、B5、B6；修改 B1、B3**。
  * *修改*：B1 若每幀動態抖動線條會耗效能且眼花，應在烘焙期做靜態手繪不規則邊框；B3「遠處兵略小略淡」在俯視棋盤會破壞距離判讀，建議只做桌面暗角與底座立體厚度。**優先序：B4 > B1 > B5 > B2 > B6 > B3**。
* **C 簡潔好懂**：**全部同意，補充 C1**。
  * *補充*：C1 除了減傷害數字，務必「隱藏滿血血條」與「整合底部跑馬燈上戰場」。**優先序：C1 > C2 > C3 > C5 > C4**。
* **D 好玩的新想法**：**同意 D1、D2、D4；反對 D5、D6；延後 D3、D7**。
  * *反對*：D5 觀戰台詞泡泡與 D6 雨雪天氣會嚴重干擾戰鬥清晰度並吃掉 p95 繪圖預算。**優先序：D1 > D4 > D2**。
* **E 驗收**：**完全同意**，建議將「混戰重疊處的血條／圖示遮擋率」與「p95 先減後加」列為首要門檻。

---

### 6. V1.3.0 開發優先級（P0 / P1 / P2）
* **P0（核心必做，共 8 項）**：
  1. **繪圖效能減法（為特效騰空間）**：滿血隱藏血條、合併重複小符號繪製，先把 p95 壓回 8.5ms 以下。
  2. **立牌轉身動畫（A1+A3）**：0.15 秒壓扁小跳翻面＋窄位側面木牌厚度色塊。
  3. **底座立體化與分離接地（A3）**：雙層厚木座繪製，角色跳動時底座留地。
  4. **同兵種去同步化（A2）**：以 ID 錯開呼吸相位、微傾角与待機眨眼。
  5. **受擊擠壓與「倒棋」物理感（A6+新想法1）**：受擊 Skew 擠壓閃白，擊倒時像立牌側倒桌面。
  6. **擺陣桌遊手感（B4+新想法2）**：抓起棋子放大＋陰影下移、落子木頭震動與粉筆預計路線。
  7. **消滅幾何原語（B1）**：重繪 [52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/52_map_ice_battle.png) 冰面邊界与光環為手繪拓印質感。
  8. **混戰視覺降噪與關鍵慢動作（C1+C2）**：移除底部文字欄改頭頂木牌、破陣瞬間 0.3 秒微慢鏡。
* **P1（重要體驗提升）**：
  * 結算頁 [05_result.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-r1/agy/05_result.png) 走勢圖排版修正與 5 秒高光回放（D1）、音效手作木頭多變體（B5）、兵種剪影強化（C3）、戰前勝方預測押注（D4）。
* **P2（錦上添花／下階段新規則）**：
  * 拍照／GIF 匯出（D2）、戰利品木碗動畫（新想法3）、地形路障新規則模式（新想法4／D7）。

結論：V1.3.0 應以「木座立牌的厚實翻轉與倒棋感」根治紙片味，用「消滅幾何直線＋滿血藏血條」換取清爽度與效能空間，讓沙盤真正像親手擺弄的實體桌遊。
