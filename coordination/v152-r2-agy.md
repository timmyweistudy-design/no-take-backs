針對《落子無悔》V1.5.2 排版防禦方案（第 2 輪），經純讀檔比對原始碼（`game/`）、截圖（`build/tmp/lay151e/zh_TW_100/22_lobby.png`）與前輪意見，具體審查與修訂意見如下：

---

### 1. L2 紅書籤「貼頂」的定義與具體幾何

#### (1) 使用者原話「紅色標籤沒有至頂」的語意與現狀缺陷
在 [22_lobby.png](file:///mnt/c/Users/timmy/projects/no-take-backs/build/tmp/lay151e/zh_TW_100/22_lobby.png) 與 [lobby_view.gd:1146-1153](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L1146-L1153) 中：
1. **破壞按鈕金框**：分頁按鈕底緣在 `y = 164`，當前代碼寫死 `by0 = r.end.y - 4.0 = 160.0`，在 `y = 160..164` 處直接覆蓋了選中分頁的 3px 金色亮框（`ACCENT`），造成底部邊框被「咬掉一口」的破圖感。
2. **懸空跨縫**：分頁底緣（`y = 164`）與羊皮紙筆記本頂緣（`y = 168`）之間存在 4px 底色暗縫。書籤從 160 跨過暗縫垂到 190，造成「懸在半空、未貼實任何容器」的視覺假象。
3. **軸線嚴重偏右**：分頁按鈕寬 154、中線在 `x = 157`，但書籤掛在 `r.end.x - 34 = 200..220`（中線 210），右偏達 53px。
4. **「至頂」的雙重可能**：
   - **解讀 A（物理筆記本書籤）**：書籤頂端未貼齊紙頁/木板的上緣（或分頁底緣），懸空且反咬按鈕。
   - **解讀 B（分頁標記誤解）**：使用者以為它是像資料夾頂部突出的頁籤（Tab 耳朵），質問為何掛在底部而非按鈕頂端（`y = 96`）。

#### (2) 最符合物理隱喻的具體幾何定義
維持「攤開戰術筆記本上方垂下的書籤帶」隱喻，幾何必須「**下緣垂入紙面、上緣嚴格貼齊木底板頂緣、水平鎖定分頁中軸**」：
* **依附宿主邊**：分頁木底座下緣 / 羊皮紙背板木框上緣 `y = 164.0`（補平 4px 縫隙，使分頁與筆記本木框連成一體）。
* **垂直座標**：
  * 上緣 `by0 = 164.0`（**絕對不可逆向畫進 `y < 164`**，完整保留按鈕金框）。
  * 下緣 `by1 = 164.0 + 26.0 = 190.0`（燕尾凹槽在 `y = 183.0`），垂入羊皮紙內距呼吸區，不壓到 `y = 196` 的地圖列。
* **水平座標**：
  * 嚴格居中於當前選中分頁的中線：以標準分頁為例，`cx = r.get_center().x = 157.0`。
  * 書籤寬度 `w = 20.0`，水平區間為 `x = 147.0 .. 167.0`。
* **附屬規則**：徹底移除 [lobby_view.gd:1141](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L1141) 未選分頁的暗褐色殘耳（`#6e3b25`），避免按鈕底部出現鋸齒感。

---

### 2. 偵測器宿主宣告介面與反例測試

#### (1) 最不易遺漏的宿主宣告：容器堆疊（Container Scope Stack）
若要求每個 UI 函式手動傳 `parent_id` 字串必會遺漏。最佳實踐是在 [`ui_base.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd) 實作**內部容器堆疊**：
1. **基底容器自動入棧**：
   * `_panel(r)` 自動執行 `_push_container("modal", r, "panel")`；
   * `_tex_box(r, "paper")` 自動執行 `_push_container("paper", r, "sheet")`；
   * 複合區塊提供 `_begin_group(id, rect, role)` 與 `_end_group()`。
2. **子元件自動歸屬**：
   * 所有 `_text()`、`_btn()`、`_h1()`、`_box()` 在註冊探針時，自動抓取 `_container_stack.back()` 作為 `parent_id` 與參考邊界，**既有畫面程式 0 額外負擔**。
3. **幀末防呆校驗**：
   * 畫面繪製結束若 `_container_stack.size() > 0`，代表漏呼叫 pop，直接報 FAIL。

#### (2) 反例測試（Negative Test Suite）設計
在 [`dev_main.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/dev_main.gd) 建立 `_test_layout_rules_negative()` 獨立無頭測試，刻意構造畸形幾何，斷言偵測器必出特定錯誤：
1. **R1 偏心反例**：宣告 `modal` 面板，座標刻意設為 `x = 200`（偏 40px），斷言抓到 `FAIL: 模態面板未水平置中`。
2. **R2 緞帶壓字反例**：呼叫 `_h1` 並刻意將文字排在 `下緣 + 4px`，斷言抓到 `FAIL: 緞帶下距不足 (<12px)`。
3. **R3 書籤懸空反例**：刻意將書籤上緣設在 `宿主下緣 + 4px`，斷言抓到 `FAIL: 依附裝飾接縫留空 (>1px)`。
4. **R8 內容溢出反例**：容器高 200，刻意塞入 `end.y = 220` 的按鈕，斷言抓到 `FAIL: 元件溢出容器邊界`。
5. **探針零註冊守衛（Zero-Registration Guard）**：故意模擬未登記任何探針的空畫面，斷言觸發 `FAIL: 畫面未登記任何容器`，防止因探針斷線造成虛假 0 違規。

---

### 3. 規則數值衝突剖析（R2 緞帶下距 16px 的連鎖反應）

R2 要求「緞帶實際下緣到首個內容 ≥ 16px」在現有固定面板中**存在具體垂直預算衝突**，不能只推移文字，否則會向下引發次級碰撞：

1. **[`game_place.gd:936`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L936)（`_draw_plan_overlay` 軍令時間面板）**：
   * 面板高 470（`y = 170..640`）。緞帶底邊在 `226.4`（150% 下為 `230.75`）。
   * 說明字若下移至 `230.75 + 16 = 246.75`，字高 20.8px，字底達 `267.55`。
   * 下方的 `_draw_plan_timeline` 固定在 `R.position.y + 90 = 260.0`，**文字直接撞入時間軸 7.55px**！
   * 若時間軸跟著下移，時間軸高 300，底邊達 `576`，距離底部的「完成」鈕（`y = 580`）僅剩 4px，焦點框必破框。
   * **結論**：面板高度必須由 470 加高至 **490px**（或時間軸高度壓到 280px）。
2. **[`game_modes.gd:1816`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1816)（`_draw_ghosts` 幽靈賽）**：
   * 緞帶底在 `116.4`。說明字移到 `132.4`，字底達 `155.8`。
   * 下方 3×3 卡片固定排在 `y = 150`，**文字直接壓住第一列卡片 5.8px**！
   * **結論**：卡片起排 Y 必須同步從 150 推至 **160px**（下方至換頁鈕有 22px 餘裕，面板不需加高）。
3. **[`game_modes.gd:1209`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1209)（`_draw_nemeses` 宿敵戰記）**：
   * 6 個宿敵滿載時，每張卡步距 98px。卡片若從 `132.4` 起排，第 6 張卡底邊達 `720.4`。
   * 返回鈕寫死在 `y = 684..728`，**第 6 張卡直接與返回按鈕重疊**。
   * **結論**：宿敵戰記 6 筆記錄時本來就垂直超載，必須導入動態高度或雙欄/捲動，不能只墊高間距。
4. **R6 留白率衝突**：
   * 空狀態（宿敵無記錄、存檔無備份）內容佔比不足 15%，若 R6 設為硬規則會引發大量誤報；**R6 必須設為警告，並對 `#empty_state` 豁免**。

---

### 4. 修訂稿漏列與筆誤清單

1. **漏列自訂分頁書籤遺失**：
   * [`lobby_view.gd:489`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L489) 與 [919](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L919)（`_draw_lobby_detail`）：修訂稿只修 `_draw_lobby_main`，但玩家點開「自訂細項」後，頂部預設列仍在，`_draw_lobby_detail` 卻完全**漏呼叫 `_draw_bookmark()`**，導致書籤在展開時瞬間消失。
2. **L3 漏列遠征兵種選擇**：
   * [`game_menus.gd:43-44`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L43-L44)（`_draw_gauntlet_pick`）：標題緞帶底邊在 `168.4`，下方說明字 `_text(Vector2(640, 182), ...)`，間距僅 13.6px（< 16px），漏列於 8 處名單。
3. **L5 標題安全包絡漏算光圈與左界**：
   * [`game_menus.gd:180-191`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L180-L191)：標題木牌左右各擴 34px，外側雙劍光圈半徑 22px（中心在 `plq.position.x - 4`）。當標題字寬逼近 430px 時，光圈左緣抵達 `x = -18`，**直接被螢幕左緣裁切**。限寬公式應將整體裝飾包絡 `tw + 68 + 44 = tw + 112` 納入計算。
4. **L5 角色腳點與縮短木牌脫節**：
   * [`game_menus.gd:223`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L223)：當 150% 隱藏副標時，木牌高 `ph` 縮為 48px，但角色的腳點寫死在 `mr2.position + Vector2(34, 54)`，角色直接踩出木牌底部 6px。應改以 `ph` 動態垂直置中。
5. **L8 設定頁按鈕置中基準錯誤**：
   * [`game_menus.gd:721-722`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L721-L722)：修訂稿稱中心在 550，但未指明該畫面有「左側頁籤（寬 190）」與「右側說明欄（寬 236）」。底部「製作名單／返回」若直接對畫面 640 置中會壓到右側說明欄底部重置鈕，應明定是以「全螢幕 640 置中」並將說明欄重置鈕移位，或以「中央操作欄（x=340..900，中心 620）」為基準置中。

---

### 5. 人時估算逐項對比與假設

第 1 輪兩方差距主因在於：**AGY 假設為「局部單點修復＋跑既有腳本自動驗收」**；**Codex 假設為「語意架構重構＋連鎖幾何推移＋全量人工逐圖聯審」**。依合併修訂稿之規格，逐項人時重估如下：

| 里程碑與工作項 | 預估人時 | 核心假設與工作內容細節 |
| :--- | :---: | :--- |
| **M0 偵測器基建與反例** | **8～11 h** | • `ui_base.gd` 實作自動容器堆疊（`_container_stack`）、探針擴充（panel/ribbon/bookmark 語意）。<br>• `dev_main.gd` 實作 R1～R10 檢驗邏輯。<br>• 撰寫 6 組負向反例測試（Negative Tests）與零註冊攔截。<br>• 初跑輸出違規 Baseline 全表。*(非 AGY 樂觀的 5h，包含反例實作)* |
| **M1 修復 P0（L1～L6）** | **8～11 h** | • L1 模態面板水平置中（x=240）、卡片群左右邊距平衡。<br>• L2 大廳紅書籤對齊木底板（by0=164）、置中分頁中軸、補齊 `_draw_lobby_detail`。<br>• L3 緞帶安全距推移（含 `plan_overlay` 加高、`ghosts` 與 `draft` 卡片連鎖下移）。<br>• L4 確認彈窗高度動態計算；L5 主畫面雙劍光圈限寬與角色腳點；L6 大廳列高聯集。 |
| **M2 修復 P1（L7、L8 及衍生）** | **6～8 h** | • L7 留白收縮（首次啟動、空備份自適應高度；定義空狀態豁免）。<br>• L8 設定頁與對戰模式雙按鈕等寬及幾何中軸重排。<br>• 清理 M0 Baseline 產出的零星違規。 |
| **M3 回歸驗收與收尾** | **7～10 h** | • `layout_check.sh` 補齊簡中與日文 125% 截圖參數。<br>• 執行 4 語系 × 3 字級全量截圖回歸，確保 Detector 0 FAIL。<br>• 人工審閱 18 張核心畫面接觸表（Contact Sheet），逐項核對無光學破破疵。 |
| **合計總人時** | **29～40 h** | **中軸約 34 人時**。平衡防禦深度與交付效率，杜絕「代碼改了但次級元件被壓爆」之隱患。 |
