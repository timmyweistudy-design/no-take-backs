### 觀察核對與補充
你點出的 6 點全數命中：
1. **場外素色落差**：正確。[36_fantasy_late.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/36_fantasy_late.png) 兩側有樹，[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/52_map_ice_battle.png)、[53_map_lava_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/53_map_lava_place.png) 與 [a_main_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/a_main_screens.png) 峽谷、橋樑圖場外卻是 `#1A241E` 死黑綠底，像沒畫完。
2. **冰湖過曝**：正確。大面積 `#E6EEF4` 冷白在深色 UI 中極刺眼，且冰洞的白框像 HTML 表格邊線。
3. **頂列百分比與小字**：正確。藍紅血條只寫 `36%`、`100%`，新手分不清是「戰力佔比」還是「剩餘總血量」；右下 `AI：普通・鐵騎突擊` 字小且灰暗（約 12px），Steam Deck 上極難讀。
4. **結果頁開發者用語與排版**：正確。`指紋 b188ff…` 毫無玩家意義；「藍方勝利！」緊貼頂框；[b_other_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/b_other_screens.png) 右下結果頁的走勢圖「最後時刻 / 勝負已定」文字甚至互相重疊。
5. **標題頁與設定頁**：正確。[01_title.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/01_title.png) 左側 11 顆按鈕形成視覺牆；設定頁與「選一個獎勵 / 征途選軍」彈窗下半部逾 50% 空白。
6. **紅兵貼邊**：正確。[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/52_map_ice_battle.png) 右上兩名紅騎兵頭頂直接切齊外框，Y 軸欠缺安全邊距。

---

### 1. 第一眼：Steam 商店截圖好壞
* **最賣**：[b_other_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/b_other_screens.png) **排兵頁（左一）＋覆盤頁（左下）**。排兵頁有射程圈、兵種剋制提示與隱藏的 AI 陣型，一眼看懂「排陣解謎」玩法；覆盤頁「如果當初改一隻兵」直接打中策略玩家痛點，是最強賣點。
* **最廉價**：[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/52_map_ice_battle.png) 與 [53_map_lava_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/53_map_lava_place.png)。冰湖純白底配銳利白框冰洞、熔岩筆直的橘色長條加黑圓點，幾何感太像工程測試圖（Programmer Art）。

---

### 2. 畫面細節必改項（最多 15 條）
1. **[P0｜S] 頂部戰力條語意與字級**（[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/52_map_ice_battle.png) 頂中）：改標「總血量 36%」；右下 `AI：普通・鐵騎突擊` 放大至 16px 並提亮。
2. **[P0｜S] 混戰交疊辨識度**（[36_fantasy_late.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/36_fantasy_late.png) 中央）：20 隻兵擠成一團時血條與描邊互吃。死亡幽靈改 40% 半透明並取消黑邊；僅受傷單位顯示血條。
3. **[P0｜S] 場地上緣裁切**（[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/52_map_ice_battle.png) 右上）：棋盤頂部內縮 16px 安全留白，或讓高帽/騎兵精靈圖允許壓在頂框之上渲染。
4. **[P0｜S] 結果頁資訊清理與重疊修復**（[a_main_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/a_main_screens.png) 左三列、[b_other_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/b_other_screens.png) 右下）：隱藏「指紋」；「藍方勝利！」下移 16px；修復戰力走勢圖重疊標籤。
5. **[P1｜M] 標題頁按鈕收斂**（[01_title.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/01_title.png) 左側）：11 顆減為 5～6 顆主入口，「觀看對戰代碼 / 接受挑戰」併入對戰子選單，「設定 / 製作名單 / 離開」改為角落圖示鈕。
6. **[P1｜M] 冰湖與熔岩地形邊緣美化**（[52_map_ice_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/52_map_ice_battle.png)、[53_map_lava_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/53_map_lava_place.png)）：冰面明度降 15% 改柔和冰藍，冰洞白框改碎冰不規則邊；熔岩溝移除直線黃框，改暗紅石岸。
7. **[P1｜S] 各地圖場外邊框裝飾**（[a_main_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/a_main_screens.png) 戰鬥圖）：複製青草平原做法，在冰湖外擺雪松/冰晶、熔岩外擺黑曜石、峽谷外擺枯木，消滅純色黑邊。
8. **[P1｜S] 彈窗留白裁切**（[a_main_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/a_main_screens.png) 設定/獎勵、[b_other_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/b_other_screens.png) 選軍）：面板高度依內容自適應縮小 35%，透出底層畫面。
9. **[P1｜S] 排兵頂部剋制列擁擠**（[53_map_lava_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/53_map_lava_place.png) 左上）：「剋 / 怕」小兵圖示貼死文字且切邊，改為膠囊底框並加間距。
10. **[P2｜S] 底部事件紀錄底襯**（[36_fantasy_late.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/36_fantasy_late.png) 底部）：三欄文字散落，加一層半透明黑底條集中視覺。
11. **[P2｜S] 色盲模式高對比強化**（[b_other_screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/b_other_screens.png) 下三）：藍黃配色的黃色底座與草地/沙地對比弱，底座外圈加粗黑邊或陣營幾何標記（圓形 vs 菱形）。

---

### 3. 動畫評估（[walk.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/walk.png)、[atk.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/atk.png)）
走路靠微幅旋轉與 1～2px 上下晃動，Q 版尚可；但**攻擊幅度普遍偏弱**，缺乏前衝拉伸（Stretch）與揮砍殘影，混戰中看不出誰在出手。
* **最弱必補前 4 名（看 [atk.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/plan10-r1/agy/atk.png)）**：
  1. **蘑菇（第 11 列）、史萊姆（第 14/22 列）、吸塵貓（第 20 列）**：8 幀幾乎靜止，只有幾像素縮放或微亮。蘑菇攻擊幀應壓扁 30% 再彈起噴孢子；史萊姆要向前拉長撲擊；吸塵貓槍口要放大抖動。
  2. **劍士（第 1 列）、盾兵（第 2 列）、骷髏（第 23 列）**：武器僅轉 15 度，像在揮指揮棒。出刀幀需加白色弧形刀光（Slash Arc）與身體前傾 4px。

---

### 4. 手感：30～90 秒看戲的高潮與結尾（零模擬干預）
純視覺表現層（Render Layer）讀取模擬狀態，絕不動邏輯 Tick：
* **破陣/人數低於 25%（高潮）**：當一方戰力跌破 25% 或觸發「背水」，BGM 無縫疊加急促戰鼓音軌（Stems Layering），畫面四周浮現微弱暗角（Vignette），鏡頭平滑 Zoom-in 至 `1.12x` 對準交戰重心。
* **最後一擊（Last Hit）**：判定最後一隻敵軍 HP 歸零瞬間，觸發 **0.6 秒 `0.2x` 慢動作**，鏡頭在 0.15 秒內推進至擊殺者 `1.25x`、全畫面微震 4px 並閃白 1 幀，配重低音擊殺音效。
* **結算節奏**：擊殺後**不要立刻彈表單**。留 **1.2 秒勝利喘息期**，存活小兵原地連續跳躍歡呼，再由上而下砸下「藍方勝利」橫幅，0.4 秒後展開數據面板。

---

### 5. 高回報、小工時的留存/分享細節（3 項）
1. **「雖敗猶榮 / 差一點」覆盤誘導按鈕**：戰敗且敵方殘血 `<15%` 時，結果頁「覆盤」鈕發金光並標註「只差 2 隻！點此試改 1 兵逆轉」，直接把挫敗轉為重玩動力。
2. **MVP 與慘案趣味頭銜**：結果頁除了 MVP，多列一個搞笑紀錄（如「最快蒸發：劍士 1.2 秒」、「空大王」），極利於社群截圖分享。
3. **擺兵階段敵方輪廓剪影提示**：針對新手或連敗玩家，在右側迷霧區用極淡虛線標出 AI「前排/後排重心區域」（不露兵種），降低純盲猜挫折。

---

### 6. 不建議做的事（3 條）
1. **不要重畫小兵立繪或加骨骼動畫**：現有圓滾滾 Q 版辨識度討喜，補程序化彈跳（Squash & Stretch）與刀光特效即可。
2. **不要做連線對戰或大廳聊天室**：US$4.99 單機定位明確，現有「對戰代碼 / 挑戰碼」非同步分享已足夠。
3. **不要在戰鬥中加複雜粒子特效**：混戰已夠擠，華麗光效只會徹底蓋住小兵動態。

結論：有條件
