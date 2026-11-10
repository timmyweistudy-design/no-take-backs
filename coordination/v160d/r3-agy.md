### 1. 事實錯誤或不可行
1. **[coordination/v160d/r3-plan.md:20](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v160d/r3-plan.md#L20)（#15 平衡新版）**：標註「舊重播照舊」違反 [docs/STATE.md:63](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L63)（S5 版本契約）。S5 明訂改既有數值時「不留舊模擬，舊代碼顯示警告並用新規則重算」，數值一改舊重播必然分歧，無法照舊。
2. **[coordination/v160d/r3-plan.md:21](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v160d/r3-plan.md#L21)（#16 出題台）**：寫「擴 NTP 目標（護送、求和等）」，但「護送」在 V1.0.5 已存在（[docs/STATE.md:44](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L44)）；且全自動戰鬥勝負制無和局判定，「求和」與既有規則與戰後判定邏輯衝突。
3. **[coordination/v160d/r3-plan.md:12](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v160d/r3-plan.md#L12)（#7 無障礙）**：「175% 字級」不可行。現有固定面板與嚴格排版（[docs/STATE.md:149, 155](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L149-L155)）在 150% 時英文結果頁等已逼近邊界（[docs/STATE.md:169](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L169)），175% 會引發大量 R8 破框違規。
4. **[coordination/v160d/r3-plan.md:8](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v160d/r3-plan.md#L8)（#3 Steam 接通）**：「後台建 31 成就」不精確。前 24 個成就已建，是 V1.5 新增的 7 個未建（[docs/STATE.md:182, 193](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L182-L193)）；每週榜程式也已就緒（[docs/STATE.md:127](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L127)）。

### 2. 全選時的分批與相依錯誤
1. **#15（批 4）與 #8、#9（批 3）倒置**：#15 若升 RULES_VERSION 調數值，依契約需重驗殘局庫（[docs/STATE.md:63](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L63)）。置於批 4 會導致批 3 的極速賽題庫與教練候選解面臨失效重調。
2. **#12（批 3 一次存檔遷移）時機錯誤**：批 4（#16 出題台自訂存檔）仍有持久化結構，在批 3 做「一次遷移」無法涵蓋後續，會導致二次升級 SAVE_VERSION。
3. **#18（外部校對）過早**：批 1～3 引入大量新文本（#1、#9、#10、#11、#12），依 [docs/STATE.md:125](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L125) 原文更動會擋舊譯稿，現有校對包無法涵蓋新文案，應待文本凍結後執行。
4. **#1 與 #2 內部相依**：#2 真人試玩招募與執行，實務上依賴 #1 先產出試玩版完整路線與建置。

### 3. 人時與組合加總檢查
- **全選總計算錯**：#1～#22 逐項下限加總為 **1,300**（非 1,400），上限加總為 **2,316**（非 2,500），總計應為 **1,300～2,316** 人時。
- **兼顧包算錯**：1+2+3+5+6+8+11 實加為 **330～580**（90+30+20+45+70+35+40 與 170+50+40+80+110+60+70），草案寫「約 390～690」，誤多算了約 60～110 人時。上架包（315～570）與好玩包（300～510）計算正確。

不同意：人時與組合算錯、#15 違反 S5 重播契約，且分批相依需調整。
