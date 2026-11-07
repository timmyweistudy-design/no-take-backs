針對 [draft1.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/draft1.md)、[codex_r1.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/codex_r1.md) 與 5 張截圖，以美術總監兼 UX 視角進行第 2 輪評議：

### 1. 對 [draft1.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/draft1.md) 各節（A～G）評議
- **A 全面紙化（修改）**：反對本版 A1～A6 全做，改採**「焦點紙化、容器留木」分級制**。全部換淺色羊皮紙會導致畫面失去視覺錨點（全亮無主次），且如 [05b_result_details.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/05b_result_details.png) 的紅藍長條與白字在深木底對比極佳，換淺紙反而得重調全套色票。
  - **本版只做**：**A1**（[10_codex.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/10_codex.png) 僅底部「老兵觀察筆記」改淺紙條，右欄技能與小劇場維持深木框襯托沙盤）、**A3 僅覆盤走勢圖區**（詳細數據頁維持深木底）、**A5**（殘局／試煉過關卡改淺紙，未過關留深木以強化進度感）。A2、A4、A6 留深木底。
- **B 文字與版面（同意，修改 B6）**：B1～B5、B7 同意。**B6 雙劍**：[sheet_en_150.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/sheet_en_150.png) 左上標題框已滿，放大雙劍必擠壓外框；改為**尺寸不變，加亮金描邊與微光對比**即可提升縮圖辨識度。
- **C 動態（修改 C1、C2）**：
  - **C1 按鈕**：同意 Codex 不加回彈 tween，改為**純視覺態強化**（懸停外框亮金邊、按下維持現有 3px 位移並加深底色陰影）。
  - **C2 勝利慶祝**：同意 Claude 折衷，但改為**緞帶背後單次放射靜態／漸隱光芒或兩側燕尾外 6 顆金星微粒（0.6 秒）**，嚴禁跨越文字區。
- **D 戰鬥資訊（同意 D1、修改 D2）**：**D2 敵情卡**在 [sheet_zh_TW_100.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/sheet_zh_TW_100.png) 右上已有紅旗與兩行字，再貼羊皮紙籤會破壞霧區神秘感；改為**將現有紅旗底座擴充為小型木牌，直接整合敵方預算／兵數**，不另增面板。
- **E 聲音、F 工程、G 上架（同意）**：全數支持，F5 對比探針是美術驗收關鍵。

### 2. 回應 [codex_r1.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/codex_r1.md) 反對理由之折衷方案
1. **重排擴張風險**：鎖定九宮格 `content_margin` 與座標不動，僅在既有 `Rect2` 內替換 `StyleBox` 底色與字色常數（A1 筆記、A5 卡片），零排版變動。
2. **粒子遮字風險**：慶祝特效繪製層級（Z-order）設於勝利緞帶底圖之下、背景之上，且座標限制在緞帶左右燕尾外側，物理上絕不遮字。
3. **回彈輸入延遲**：放棄任何改變碰撞框或延遲觸發的回彈動畫；點擊判定維持 0ms 立即觸發，僅用 `draw` 階段的亮邊與內陰影提供打擊感。

### 3. 草案漏掉、玩家一眼會注意到的 5 個細節
1. **EN150 自訂兵池「Beats / Fears」圖示重疊**（[sheet_en_150.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/sheet_en_150.png) 第 4 列右 3「Unit pool」右下角）：`Fears` 標籤直接疊在 `Beats` 第二個兵種頭像上，屬嚴重破版。
2. **詳細數據長條圖數值內外不一**（[05b_result_details.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/05b_result_details.png) 中央）：刺客紅條滿格時 `2140` 縮進紅條內，其餘數值皆在條外，且上方「輸出／承傷」切換鈕未對齊下方中軸線。
3. **圖鑑分頁籤緊貼標題緞帶燕尾**（[10_codex.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/10_codex.png) 左上角、[sheet_en_150.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/sheet_en_150.png) 第 2 列右 3）：「奇幻軍／Monsters」按鈕右緣幾乎撞上標題緞帶左燕尾，視覺壓迫。
4. **戰績頁成就未解鎖項目無解鎖條件提示，且框線不對稱**（[59_profile.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/59_profile.png) 下半部）：玩家看到鎖頭卻不知如何達成；已解鎖有全寬金框、未解鎖無底框導致三欄視覺鬆散。
5. **EN150 覆盤頁藍紅標題擠在一起**（[sheet_en_150.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v121-r2/agy/sheet_en_150.png) 第 4 列左 1 左上）：`Yours (click to edit)` 與 `Opponent (reference)` 間距過小幾近相連。

### 4. P0／P1／P2 優先序（P0 共 8 項）
- **P0（必修 8 項）**：① EN150 自訂兵池 Beats/Fears 重疊修正；② B1 結果緞帶孤行與覆盤藍紅標籤間距；③ B2 字級映射與 Deck 12px 驗證；④ F1/F2/F3/F4 快取、busy 鍵、Steam 回呼與設定遷移；⑤ F5 對比度 4.5:1 自動探針；⑥ E1 四軌音量拆分與試聽；⑦ G2 手把 PS 向量符號；⑧ 05b 長條圖數值位置與中軸對齊。
- **P1（體驗提升）**：A1 老兵筆記與 A5 已通關卡紙化、B3 捲動淡出提示、B4 走勢圖標籤防撞、B5 混排基線、B7 書籤耳與對齊、C1 懸停亮邊、D1 戰報短名、D2 紅旗木牌整合敵情、G1/G3 上架資產與字型前置。
- **P2（錦上添花）**：B6 雙劍亮邊與右下木架、C2 緞帶燕尾星芒、F6 圖示預烘、59 戰績成就條件提示。

結論：放棄全頁無差別紙化與回彈動畫，改以零重排局部換底、零延遲亮邊及燕尾外微粒達成美感與工程雙贏，並優先修復 EN150 自訂兵池重疊與長條圖排版瑕疵。
