### 1. 交接文件的事實錯誤、過期與模糊處（對照程式確認）

1. **過期程序清單**（[HANDOFF-v152.md:100](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/HANDOFF-v152.md#L100)）：寫死 14 個暫態 PID。環境重開後這些 PID 已失效，接手者若去查詢或等待清理會卡住，應改為通用的檢查與清理指引。
2. **規則判定等級前後矛盾**（[HANDOFF-v152.md:49](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/HANDOFF-v152.md#L49)、[HANDOFF-v152.md:63](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/HANDOFF-v152.md#L63) 與 [2026-11-09-v1.5.2-plan.md:51](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/2026-11-09-v1.5.2-plan.md#L51)）：§4.1 寫「R2 在 12～16px 警告、<12px 失敗」，但方案 §2.2 卻將 R2 全列為硬規則 FAIL。兩邊衝突會讓實作測試時對 12～16px 的裁決無所適從。
3. **L2 呼叫點與褐色書籤規格模糊**（[HANDOFF-v152.md:29](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/HANDOFF-v152.md#L29) 對照 [lobby_view.gd:487-491](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L487-L491)、[642](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L642)）：分頁在 `_draw_lobby` 繪製，若依文件寫移入「自訂細項（`_draw_lobby_detail:919`）」，會造成入口分散；且「未選分頁褐色書籤一併檢討」未給定案幾何，接手者無法直接實作。
4. **L3 下緣計算與回傳型別未定義**（[HANDOFF-v152.md:31](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/HANDOFF-v152.md#L31) 對照 [ui_base.gd:884-894](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L884-L894)）：目前 `_h1` 為 `void`，緞帶尾端多延伸 2px（`r.end.y + 2 = center.y + sz * 1.45`）。文件要求回傳下緣，但未定案回傳值是否包含尾端，直接影響下游 `+16px` 間距的基準點。
5. **L3 受影響清單手寫漏列**（[HANDOFF-v152.md:31](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/HANDOFF-v152.md#L31) 對照 [replay_view.gd:576](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/replay_view.gd#L576)、[game_menus.gd:943, 960, 1246](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L943)）：手寫清單漏掉覆盤（`*1.3`，間距僅 9.6px）、備份還原（`*1.5`）與首次啟動（`*1.8`），照單修改仍會被自動檢查抓包。
6. **版面檢查參數與缺組問題**（[HANDOFF-v152.md:87](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/HANDOFF-v152.md#L87) 對照 [layout_check.sh:24, 62](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/layout_check.sh#L24)）：腳本常態缺少簡中與日文 125% 組合，且指定 `LAYOUT_COMBOS` 時若未重設預期張數檢查，會觸發結尾驗收腳本退出非 0。

---

### 2. 對 Claude 初稿（A～D）審查

- **A1**：同意。過期 PID 應替換為通用的程序清理說明。
- **A2**：同意。改以 `tz("H1")` 全域檢索為準才能杜絕遺漏。
- **A3**：同意。統一以交接文件為準並回寫修正方案。
- **A4**：修改。建議定案為「未選分頁不繪製書籤（視覺最整潔）」，避免與 A 案頂部書籤產生視覺衝突。
- **B1（先修 L1/L2 再做偵測器）**：**同意（有條件）**。
  - *可行性與風險*：極高且工期 ≤1 小時，能即時給使用者確認 A 案實裝效果；風險是缺乏修前基準可能破壞未捕捉的細節。
  - *一句理由*：可行且能快速給予正向反饋，但條件是動工前必須先完成修前基準存檔，且 M0a 嚴格限定僅修 L1/L2，修畢立即回歸 M0b 偵測器。
- **B2（_panel/_tex_box/_h1 自動登記，不先全面 with_container）**：**修改（有架構風險）**。
  - *可行性與風險*：`_panel` 與 `_h1` 具備唯一語意，自動登記完全可行；但 `_tex_box` 廣泛用於背景、按鈕與裝飾框，若自動當容器會產生嚴重偽陽性噪音，且多欄畫面（如設定、大廳）無容器邊界將無法判定中線（R4/R10）。
  - *一句理由*：`_panel`/`_h1` 自動登記可行，但 `_tex_box` 絕不能自動當容器；多欄畫面仍應顯式宣告輕量欄位邊界。
- **B3**：同意。修前修後接觸表對照是證明「未改壞其他畫面」的科學依據。
- **C1～C6**：同意。第一小時清單、完成定義、避坑手冊、範圍防火牆、規則同步與中斷點拆分，皆能顯著降低交接摩擦。
- **D1～D2**：同意。引入業界斷言標準與無障礙間距依據，能大幅提升設計說服力。

---

### 3. 額外優化建議

1. **採用階層式邊界盒（Bounding Box）相對幾何斷言**：
   捨棄易受字型渲染影響的絕對座標或純像素比對，改用容器與子元件相對邊界盒運算（如 `is_centered(child, parent)`、`gap_below(a, b) >= 16`），提升檢查韌性。
   *來源：Galen Framework Layout Testing Guide (`susatest.com` / `susatest.com`)*。
2. **間距階全面綁定 8pt 網格語意常數**：
   在 `ui_base.gd` 定義 `GAP_XS=4`, `GAP_S=8`, `GAP_M=12`, `GAP_L=16`, `GAP_XL=24`，讓偵測器反向阻擋非 4 倍數的寫死魔術數字（如 +14, +22）。
   *來源：Google Material Design Spacing System 及 Built to Adapt 8-Point Grid System*。
3. **對齊微軟遊戲無障礙規範（XAG 101）門檻**：
   將 R2（標題下距 ≥16px）與 R9（彈窗文字到底部按鈕 ≥12px）明訂為剛性門檻，符合 XAG 101 關於層級可讀性與觸控防誤觸要求。
   *來源：Microsoft Xbox Accessibility Guidelines (XAG 101: Text display, `learn.microsoft.com`)*。
4. **大廳分頁圖層嚴格分離（Layer Separation）**：
   在 `lobby_view.gd` 明確界定繪製順序：(1) 底層紙面 -> (2) 書籤與分頁本體 -> (3) 選中金框與文字標籤，徹底根絕書籤咬框與覆蓋缺陷。
5. **違規自動輸出視覺化除錯疊圖（Debug Overlay）**：
   偵測器在輸出 `layout.jsonl` 的同時，在違規截圖直接標記容器邊界、中線與衝突紅框，接手者審查時 1 秒定位問題。
   *來源：Android Accessibility Test Framework (ATF)*。

---

有條件
