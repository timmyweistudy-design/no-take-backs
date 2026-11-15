### 必改

1. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L60)、[L136](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L136)
   - **問題**：第 0 輪備料門檻前後矛盾。L60 先寫「沒有對齊的畫面證據，不進 R1」，下一句又寫「資料不足時，先做不依賴該資料的分析」，開跑後會卡在到底能不能進 R1。
   - **建議改法**：區分 R1 硬門檻與軟缺口——明確規定「第 1～5、7 項（版本錨點、全畫面接觸表、1:1 原圖含尖峰幀、全流程橫向條、灰階與商店縮圖、固定拍攝契約）」齊備才准進 R1；第 6 項動態連環條或個別特殊狀態若缺圖，允許列為「待驗」先開跑 R1，但該部分不得做視覺定案。

2. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L12)、[L88](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L88)、[L96](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L96)
   - **問題**：Codex 加入的「七欄驗收數字」在 L12 與 L96 沒有和畫面判讀死死綁住。L96 寫成「一個驗收數字**或**固定截圖條件」，「或」字會讓系統／玩法提案只交數據、跳過看圖與四層觀片，導致畫面討論被數字取代。
   - **建議改法**：把 L96 改為「工程指標（依 L88 七欄）**＋**畫面判讀條件（對應固定截圖／連環條＋四層觀片及格線）」，並明訂任何涉及可見畫面或動態的細項兩者缺一不可。

3. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L44)、[L54](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L44-L54)
   - **問題**：L44 寫 1.5.0 固定時鐘美感基線（低對比棋子 573／基線 568、0 張超過容差）不可默默放寬或重設，但沒寫 1.6.0 做全站主光、材質、舞台與剪影大改時如何合法更新基線；直接跑五輪會與「0 張超過容差」死鎖。
   - **建議改法**：在 L44 或 §3 補一條「基線升版規則」：若 1.6.0 主動修改光影／材質／版面，必須先以「左 1.5.0｜中 1.6.0｜右灰階」並列通過四層觀片及色盲／低對比／R14 檢查，才可公開登記為 1.6.0 新基線並保留 1.5.0 對照，而非沿用舊像素容差卡死改版。

4. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L73)、[L114](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L114)
   - **問題**：對比規定「左 1.5.0 基線｜中 1.6.0 提案｜右灰階（或連環條）」把動態連環條塞進靜態三欄的第三格。測走路轉向或揮擊時，左中是單幀截圖、右邊是連環條，根本無法做 1.5.0 與 1.6.0 的同 tick 動作對比，也會漏掉灰階明度檢查。
   - **建議改法**：拆成兩套對照模板——靜態畫面維持「左 1.5.0｜中 1.6.0｜右 1.6.0 灰階」；動態切片強制交「上排 1.5.0 連環條｜下排 1.6.0 同 tick 連環條」，另附關鍵接觸幀的靜態灰階對照。

5. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L94-L96)、[L133](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L133)
   - **問題**：① R1 要求每人交 12～16 個玩家時刻＋專業深挖＋§2.3 二十多項逐項表態＋≥10 方向 × ≥3 細項，卻設「R1 建議上限 4500 字」，會逼迫大家壓縮具體畫面證據與改造描述（變相退回抽象詞）；② L94 只叫 Codex 查同類作品系統結構，沒叫 Hydrogen 查桌物化／木偶動態／明暗材質參考，對不到 §1 第 7 點與 §3 L56。
   - **建議改法**：① 明訂「§2.3 逐項表態表」與「細項完整規格表」列為 R1 另附表格、不計入 4500 字正文上限；② L94 補上 Hydrogen 的參考研究責任（拆解同類手作／桌游／木偶作品的明暗比例、材質層次與轉向過渡，附 §10 引用格式）。

6. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L106)
   - **問題**：R2「驗證可全選」只盤點「重複、互斥、依賴、共用資源競爭、新入口、效能／素材／維護負擔」，漏掉「全選後的同一畫面空間與視覺焦點預算」。故事物件、老闆神態、棋鐘、便條、印章、新模式入口同時上桌時，最容易互搶版面、毀掉 R14 與三階明度。
   - **建議改法**：在 L106 補入「全選後同頁桌面空間／R14 留白／明度層級預算」，要求各方向標明佔用哪一塊桌面區域與哪一層視覺權重，並確認不會互相擠壓。

7. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L113)
   - **問題**：R3 必選切片只列角色動態、舞台與戰場辨讀、玩法循環、覆盤、驗收提速，且註明「技術已足夠的方向直接寫批次規格，不必切片」。這會讓「懸浮視窗轉桌物化＋R14＋英文 150%＋簡化模式」被當成技術已足夠的純 UI 樣式改動而跳過切片，等到 R4 或量產才發現長字串撐爆便條或木牌。
   - **建議改法**：將「一個代表頁的桌面敘事化版面重構（含 R14、英文 150%、簡化模式切換）」列為 R3 必選切片。

8. **位置**：[p3-prompt-combined.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L120)
   - **問題**：R4 Hydrogen 審查項目被縮窄成「電腦感／R14／英文 150% 與簡化模式」，漏掉角色剪影與多方向過渡、戰場高負載尖峰幀可讀性（隊色與目標不被遮擋），以及跨頁全流程條的光向／色溫／材質統一。
   - **建議改法**：L120 補齊為逐項查核「六把尺全站覆蓋、全流程條世界一體性、角色剪影與動態過渡、戰場尖峰幀可讀性、R14＋英文 150%＋簡化模式不毀桌物化」。

### 建議

1. **肯定核心保留並補強全案視覺底座**：Hydrogen v2 的備料 9 類、四層觀片、六把診斷尺與禁用詞都保留完整且未受損；建議在 [L118](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L118) 主持人全案欄位多列一節「全站美術統一規格摘要（主光向、主材質色盤、三階明度／字級原則）」，避免分批實作各畫各的。
2. **補齊動態連環條取樣定義**：[L66](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L66)「4～6 格等距 tick」建議改為「4～6 格關鍵姿勢或等距加極值（須拍到預備、出手／轉向中段、受擊頓幀、收招回穩）」，避免等距取樣剛好跳過頓幀與轉身過渡。
3. **統一圖號引用欄位**：[L16](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L16) 寫 `[圖號｜區域｜看到什麼｜改成什麼]`，[L93](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L93) 寫 `[圖號｜位置｜看到什麼]`；建議統一用語為 `區域`，R1 診斷用 3 欄（改法寫入方向細項）、審查與對比用 4 欄。
4. **明訂退路方案的視覺底線**：[L57](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L57) 的程式／幾何／合成退路與音畫同步（[L16](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L16)、[L33](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L33)）缺乏品質下限，建議明訂「即使改走退路，仍須通過六把尺第 1、5、6 尺及基本音畫對拍檢核」，防止沒收到外部資產時用粗糙幾何塊過關。
5. **允許 R1 視覺方向附標註示意**：R1 時還沒有 1.6.0 實機圖，純文字寫版面與舞台改法容易落差；建議允許在 R1 附「1.5.0 原圖圈註或簡易拼貼示意」，但強制標註「提案示意（非實機證據）」以免違反 [L133](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy/p3-prompt-combined.md#L133) 不得編造截圖的原則。

結論：有條件
