以下為針對第五輪實作第 1 輪（共 19 張實機截圖）之完整審查回覆：

---

### 1. 方案第 2 輪三個定稿條件查核〔G〕

1. **擺放畫面「選中兵種資訊卡」不遮擋部署格：已做到**〔G〕
   * 對照 [02_place.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/02_place.png)、[07_duel.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/07_duel.png) 與 [02_place_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/02_place_en150.png)，選中兵種的「名稱＋一句定位＋剋／怕頭像」已移至**棋盤上緣外的頂部橫帶第二行**，藍紅雙方 6×9 部署格與底部卡列完全零遮擋。
2. **150% 字級時 `H2` 與內文 `B` 維持層級落差：已做到**〔G〕
   * 對照 [22_lobby_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/22_lobby_en150.png)、[24_lobby_army_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/24_lobby_army_en150.png)、[10_codex_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex_en150.png)，150% 下小標題（如 `Handicap`、`Cavalry`、`100 gold · 24 units...`）透過字級差、字型／粗細與暖金配色，與一般內文 `B` 保持清晰視覺區隔。
3. **規則變動／花不完錢／禁開戰原因提示：已做到**〔G〕
   * [24_lobby_army.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/24_lobby_army.png) 與 [26_lobby_lab.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/26_lobby_lab.png) 右側說明欄已即時精算並黃字預警「`⚠ 藍方：最多只能擺 14 隻（76 金），4 金用不到`」、「`⚠ 紅方：最多只能擺 14 隻（76 金），64 金用不到`」，並列出「`和標準不同 N 項`」Diff 清單與重置鈕；[23_lobby_pool.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/23_lobby_pool.png) 亦明確標示「`至少要有 1 種戰鬥兵；醫者、鼓手是支援兵，不會攻擊`」。

---

### 2. 逐張截圖評分（0～10 分）與問題清單〔G〕

#### A. 逐張評分表〔G〕
* [01_title.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/01_title.png)：**9.0 / 10** — 左側暗底選單面板與右側動態戰場分區明確，標題毛筆字氣勢佳，3 秒內主次分明。
* [22_lobby.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/22_lobby.png)：**9.0 / 10** — 精簡大廳 6+1 預設卡、卡池頭像預覽、`◎ 平衡認證` 徽章與 AI 難度切換一目了然，新手 2 秒可開戰。
* [23_lobby_pool.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/23_lobby_pool.png)：**8.8 / 10** — 玩家與 AI 卡池上下分列、戰鬥兵／支援兵分框加上上鎖標示與 `★ 娛樂變體` Diff 清單非常直覺。
* [24_lobby_army.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/24_lobby_army.png)：**9.0 / 10** — 讓子開關、藍紅金幣與上限 `◀ ▶` 調整清楚，右側即時算出餘額浪費警告，防呆極佳。
* [26_lobby_lab.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/26_lobby_lab.png)：**8.8 / 10** — 沙盒倍率、技能紅綠開關、兵種右上角紫點修改標記與 `◇ 沙盒` 紫色雙框徽章設計到位。
* [25_lobby_duel.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/25_lobby_duel.png)：**9.0 / 10** — 雙人精簡大廳自動將 AI 難度替換為「落子方式：輪流落子（每人 5 手・公平輪序・推薦）」，完全符合雙人痛點。
* [02_place.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/02_place.png)：**8.8 / 10** — 頂部連續金幣色塊條＋`93/100 金 18/24 隻`＋次行選中兵種剋怕帶，版面乾淨且視野開闊。
* [06_puzzle.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/06_puzzle.png)：**9.2 / 10** — 殘局只顯示 4 種可用兵、金幣條標出 `★★★ ≤14 金` 黃色刻度線、場上固定兵與集火目標標示極為清晰。
* [07_duel.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/07_duel.png)：**8.8 / 10** — 頂部紅字「紅方 第 1/5 手・本手剩 9 金」醒目，輪流落子焦點明確。
* [05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result.png)：**8.2 / 10** — 第一層只留勝負、戰力走勢圖（3 個關鍵時間標記）與 MVP 卡，3 秒內能抓到戰局逆轉重點（惟數據口徑與詳細頁有落差，見下述）。
* [05b_result_details.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05b_result_details.png)：**8.0 / 10** — 雙向中線對比長條圖（輸出／承傷切換）與技能觸發膠囊易讀性高，但與頂部摘要數字存在口徑矛盾。
* [10_codex.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex.png)：**7.5 / 10** — 10 兵種分布圓點排名條與右侧即時小劇場很棒，但中文 100% 左欄即出現捲軸，「怕」與「✓ 擺放建議」被擠到摺頁下看不見。
* [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/16_review.png)：**9.0 / 10** — 補齊「對手站位（參考）」小棋盤、換兵標價、修改摘要（`盾兵→劍士`）與「原本 vs 如果」雙走勢圖對照，邏輯極清楚。
* [08_settings.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/08_settings.png)：**9.2 / 10** — 四分頁＋`◀ ▶` 選擇器＋右側說明欄，結構清爽無負擔。
* [02_place_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/02_place_en150.png)：**8.8 / 10** — 英文 150% 在擺放畫面完全不擠不撞，頂部兩行與底部卡列依然整齊。
* [05_result_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result_en150.png)：**5.8 / 10** — **出現嚴重文字撞框／遮擋**：右上角 `[Details ›]` 按鈕直接蓋住摘要句尾 `a narrow win at 47s`，且 `Red 0%` 擦撞按鈕左緣。
* [10_codex_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex_en150.png)：**6.5 / 10** — 雖無爆框，但單一畫面同時出現 **3 處迷你捲軸**（技能說明 2 行截斷、左欄把 `Beats/Fears` 全擠出畫面、老兵筆記 1 行截斷），閱讀體驗零碎。
* [22_lobby_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/22_lobby_en150.png)：**8.8 / 10** — 英文 150% 預設卡自動換行正常，按鈕與徽章留白充裕。
* [24_lobby_army_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/24_lobby_army_en150.png)：**7.4 / 10** — 左中欄換行良好，但右側欄 `3 changes from standard` 下方的 **3 條具體變更項目被裁切消失**（被 `[Reset to standard]` 擋住或擠出容器）。

---

#### B. 「必須修」與「可以之後再說」清單〔G〕

* **【必須修】（影響結案的明顯瑕疵，共 4 項）**〔G〕：
  1. **[05_result_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result_en150.png) 標題區文字與右上角按鈕重疊（自動檢查漏抓）**：
     * `Wiped out · 47.5s | Remaining power Blue 9% Red 0%` 的 `0%` 撞上 `[Details ›]` 按鈕左緣；下一行 `Blue Assassin dealt the most (840) · a narrow win at ...` 句尾直接被 `[Details ›]` 按鈕蓋住。應限制中央標題區最大寬度（避開左右按鈕欄寬度）並允許自動換行。
  2. **[24_lobby_army_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/24_lobby_army_en150.png) 右側說明欄 Diff 細項在 150% 被吃掉**：
     * 顯示了 `3 changes from standard`，但底下的 3 行具體差異項目（金幣、讓子、單種上限）完全消失。右側說明欄應支援內容捲動或緊縮段落間距。
  3. **[05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result.png) 與 [05b_result_details.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05b_result_details.png) 傷害最高敘事矛盾**：
     * 頂部摘要與 MVP 寫「`藍方 刺客傷害最高 (840)`」，但點開 [05b_result_details.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05b_result_details.png) 戰報輸出長條圖卻顯示藍方「`劍士 1520`、`刺客 1340`」。若 840 是「單兵最高（MVP）」而 1520／1340 是「該兵種全隊總和」，必須在文字上寫清楚（例：`單兵最高：藍方刺客 (840)`、長條圖標 `各兵種總輸出`），否則玩家一眼看過去會覺得數據算錯。
  4. **[10_codex.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex.png)／[10_codex_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex_en150.png) 圖鑑第一層關鍵資訊被捲軸截斷**：
     * 即使在中文 100%（[10_codex.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex.png)），左欄只露出「剋」，把「怕」與「✓ 擺放建議」藏進捲軸下；英文 150% 更連「剋」都看不見，且全頁出現 3 個小捲軸。建議將「剋／怕」改為左右並排（各佔半欄，頭像旁直接寫短名而非上下堆疊），即可在 100% 免捲動完整呈現「剋＋怕」。

* **【可以之後再說】（不擋結案的體驗優化）**〔G〕：
  1. [05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result.png)／[05_result_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result_en150.png) 背景頂部戰鬥 HUD 的 `AI : 普通` 下方有一小塊殘留的半透明切邊（疑似舊 UI 元件未完全隱藏），且英文 150% 左上 `Quick Battle vs AI · Normal` 換行後略貼棋盤上框。
  2. [05b_result_details.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05b_result_details.png) 紅方刺客長條圖的數字 `2140` 因條長滿格而壓在紅條內側右緣，對比度略低。
  3. [10_codex.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex.png) 價格列 `7 金` 仍保留了金色圓點與灰底橫條（雖沒寫排名，但看起來像最低分），可把價格橫條拿掉、只留文字。

---

### 3. 與改版前（第一輪）對比評估〔G〕

整體資訊架構、字級規範與視覺呼吸感**有大幅度的躍進**〔G〕：
* **結果頁（3.5 → 8.2，英文 150% 除外）**：從原本塞滿同屏的混亂圖表，進化成「第一層看走勢與 MVP、第二層看雙向長條戰報」，走勢圖拉高且標記精簡至 3 個，閱讀動線大幅改善。
* **擺放頁（5.0 → 8.8）**：廢除每 10 金一格的碎格子，改為連續色塊金幣條＋大字預算，並把選中兵種資訊與剋怕頭像整合進頂部橫帶第二行，徹底解決遮擋與雜亂問題。
* **圖鑑頁（5.0 → 7.5）**：新增 10 兵種分布排名圓點條與右側即時戰鬥小劇場，直覺度大增（唯左欄高度不足導致「怕」被捲軸藏住，修好即可達 9 分）。
* **同機雙人（4.5 → 8.9）**：新增雙人專屬大廳（直接切換輪流 5 手）與醒目的頂部紅／藍方本手剩餘金幣提示，雙人輪流體驗非常流暢。
* **設定頁（5.5 → 9.2）**：規則全數遷入大廳，設定頁濃縮為四分頁＋說明欄，乾淨俐落。
* **覆盤頁（5.5 → 9.0）**：補齊紅方站位參考圖、換兵價格與上下雙走勢圖對比，「如果當初改一隻兵」的核心玩法一目了然。

---

### 4. 結案判定〔G〕

* **判定：有條件可**〔G〕
* **結案條件（修完以下 4 點即可直接結案）**〔G〕：
  1. 修復 [05_result_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result_en150.png) 中央副標與摘要文字撞到右上角 `[Details ›]` 按鈕的重疊問題（並將該文字框納入自動重疊檢查）。
  2. 修復 [24_lobby_army_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/24_lobby_army_en150.png) 右側欄 `3 changes from standard` 下方變更細項被裁切消失的問題。
  3. 釐清並標明 [05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05_result.png)（刺客傷害最高 840）與 [05b_result_details.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/05b_result_details.png)（劍士輸出 1520、刺客 1340）的統計口徑標籤（區分「單兵 MVP 傷害」與「兵種總輸出」）。
  4. 調整 [10_codex.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v5impl1/10_codex.png) 左欄排版（如「剋／怕」左右並排或緊縮列距），確保中文 100% 下無須捲動即可同時看到「剋」與「怕」。
