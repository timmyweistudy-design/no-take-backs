以下為根據 [review-input.md](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/review-input.md)，對照上一輪 [round1.md](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/round1.md) 的 8 條意見、修正後的 [free_place.gd](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd)、[ui-fix.diff](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/ui-fix.diff)、規格 [plan-ui.md](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/plan-ui.md) 與本輪 7 張截圖之第二輪複查結果：

---

## 一、第一輪 1～8 條意見複查結果

### 1. 外部清空或載入陣型未重置 `fp_sel`／`fp_drag`，按 Delete 或 M 會索引越界崩潰或誤刪
- **狀態**：**部分修好**（[free_place.gd:77-81](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L77-L81)、[free_place.gd:256-277](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L256-L277)、[free_place.gd:288](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L288)、[free_place.gd:571](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L571)）
- **說明**：新增了 [`_fp_clean_sel()`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L77-L81) 過濾 `i >= 0 and i < n`，已解決清空或載入較少兵數時按 `Delete`／`M` 索引越界崩潰的問題；但點選「陣型」載入其他存檔（`_load_checked`）時仍未將 `fp_sel` 重設為 `[]`，若新載入陣型的兵數大於等於原選取索引（滿足 `< n`），舊索引會直接指向新陣型中對應編號的兵，此時按 `Delete` 或 `M` 仍會誤刪或誤翻新陣型的單位。

### 2. 拖曳中開啟覆蓋層會讓畫筆／搬移／框選／擦除狀態卡死；整群平移拖出界外會誤刪單兵
- **狀態**：**已修好**（[free_place.gd:347-354](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L347-L354)、[free_place.gd:375-381](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L375-L381)、[ui-fix.diff:43-45](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/ui-fix.diff#L43-L45)）
- **說明**：已在 [`_mb_release_cleanup()`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/ui-fix.diff#L43-L45) 串接 [`_fp_abort_drag()`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L375-L381) 清理所有拖曳與手把按住狀態；整群平移（`group == true`）拖出戰場外放開時已改為取消移動而非刪除被拉的單兵。

### 3. 框選整群拖曳缺乏整群預覽，且單兵搬移預覽朝向寫死為藍方
- **狀態**：**已修好**（[free_place.gd:621-634](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L621-L634)）
- **說明**：搬移預覽已依隊伍設定朝向 `face := 1.0 if a.team == 0 else -1.0`，且當 `fp_sel.size() > 1 and fp_drag in fp_sel` 時會依位移差 `dv` 驗證 `trial.move_group` 並繪製整群單位的半透明預覽（但原位置的同群單位未同步隱藏，詳見下方新問題第 4 條）。

### 4. 手把操作漏做規格中的「LT+A 框選」、「LB/RB 換兵」，且按住 A/X 配十字鍵無法畫筆或擦除
- **狀態**：**部分修好**（[free_place.gd:451-459](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L451-L459)、[free_place.gd:484-494](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L484-L494)）
- **說明**：已補上按住 `LT＋A` 框選（第 455 行讀取 `JOY_AXIS_TRIGGER_LEFT > 0.5`）、十字鍵移動後觸發 `_fs_extend`／`_fp_erase_at`（第 490-493 行），並將十字鍵與左搖桿邊界統一夾限為 `200.0..15800.0`／`200.0..8800.0`；但 [plan-ui.md:22](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/plan-ui.md#L22) 規定的手把 **「LB／RB：換兵種」**（`JOY_BUTTON_LEFT_SHOULDER`／`JOY_BUTTON_RIGHT_SHOULDER`）在 [free_place.gd](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L446-L495) 與 [ui-fix.diff](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/ui-fix.diff) 中仍未實作。

### 5. 畫面回饋多處未達規格：工具列位置與規格不符、缺金幣條預扣斜線、缺多隻預覽首尾射程、缺密集區腳底中心點透出
- **狀態**：**已修好**（[27b_free_brush.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/27b_free_brush.png)、[free_place.gd:552-567](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L552-L567)、[free_place.gd:612-619](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L612-L619)、[free_place.gd:654-657](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L654-L657)、[free_place.gd:698-717](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L698-L717)、[free_place.gd:747](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L747)）
- **說明**：頂部金幣條預扣斜線段（[`_fp_gold_preview`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L552-L567)，見 [27b_free_brush.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/27b_free_brush.png)）、畫筆首尾兩隻射程預覽（第 654-657 行）、游標附近密集區腳底中心點透出（第 612-619 行）、新手 1.5 秒手勢動畫（[`_fp_gesture`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L698-L717)）與工具列註解皆已補齊。

### 6. 解鎖橫幅（Toast）嚴重遮擋畫面標題與戰場底部單位，且全場敵兵禁區紅圈疊加過濃並超出戰場邊框
- **狀態**：**部分修好**（[28_free_full_ai.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/28_free_full_ai.png)、[29_free_duel_full.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/29_free_duel_full.png)、[30_lobby_deploy.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/30_lobby_deploy.png)、[31_review_free.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/31_review_free.png)、[free_place.gd:517-549](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L517-L549)）
- **說明**：
  1. 全場敵兵禁區已改由 [`_fp_zone_raster`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L527-L549) 轉為戰場內部的點陣長方形並以單一透明度 `0.16` 繪製，[28_free_full_ai.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/28_free_full_ai.png) 與 [29_free_duel_full.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/29_free_duel_full.png) 已融合成均勻淡紅且不超出戰場木框。
  2. `28`、`29`、`30` 的解鎖橫幅已清除；但在 **[31_review_free.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/31_review_free.png)** 中，上方「新兵種解鎖：醫者！（殘局「新兵試玩」可以先練習）」橫幅**依然存在**，直接壓在「覆盤：如果當初改一隻兵」標題文字正上方造成遮擋重疊。

### 7. 大廳「全場明牌」開啟時「部署縱深」仍顯示可調（誤導），且覆盤全場模式漏畫敵兵禁區
- **狀態**：**部分修好**（[30_lobby_deploy.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/30_lobby_deploy.png)、[ui-fix.diff:76-80](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/ui-fix.diff#L76-L80)、[ui-fix.diff:100-103](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/ui-fix.diff#L100-L103)）
- **說明**：
  1. 大廳雙人全場已隱藏縱深列，對 AI 全場則將左側標籤改為「AI 的部署縱深」（[30_lobby_deploy.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/30_lobby_deploy.png)），覆盤全場模式也已補畫敵兵禁區紅圈（[ui-fix.diff:100-103](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/ui-fix.diff#L100-L103)）。
  2. 但 [30_lobby_deploy.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/30_lobby_deploy.png) 右側「和標準不同 4 項」摘要仍寫「`・部署縱深 6.00→7.50`」（未區分是 AI 縱深，且雙人全場若 `depth != 6000` 仍會顯示該項差異）；另外覆盤全場禁區直接用 `draw_circle` 疊加且未裁切邊界（敵兵靠近小戰場邊緣時紅圈會超出綠底外）。

### 8. 畫筆滑過既有兵或禁區時取樣步進過大導致多跳空位，且費用泡泡文案與邊界處理不當
- **狀態**：**部分修好**（[27b_free_brush.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/27b_free_brush.png)、[free_place.gd:163-171](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L163-L171)、[free_place.gd:643-662](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L643-L662)）
- **說明**：費用泡泡已區分「錢不夠了（剩 N 金）」／人數／本手上限並加上戰場邊界 `clampf`（見 [27b_free_brush.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/27b_free_brush.png)）；但 [`_fs_extend`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L164-L171) 的細步幅 `cur_step` 被寫成區域變數，在一般滑鼠跨事件拖曳時會失效（詳見下方新問題第 2 條）。

---

## 二、修正後新出現或暴露的問題（共 6 條，依嚴重度排序）

### 1. `_fp_reset()` 未重設 `fp_tool`，且雙人輪流未攔截框選，會導致雙人輪流模式卡在「選取」完全無法放兵
- **位置**：[free_place.gd:313-319](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L313-L319)、[free_place.gd:455](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L455)、[free_place.gd:750](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L750)、[free_place.gd:780-795](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L780-L795)
- **問題**：
  1. [`_fp_reset()`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L780-L795) 漏了重設 `fp_tool = "brush"`。若玩家先在對 AI 模式點選工具列的「選取」（如 [27c_free_select.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/27c_free_select.png)，`fp_tool = "select"`），之後開一局雙人輪流對決（[29_free_duel_full.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/29_free_duel_full.png)），工具列雖隱藏了「選取」鈕（第 750 行），但 `fp_tool` 仍為 `"select"`；此時玩家在空地按左鍵或手把 A，[`_fp_press`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L316) 會一律進入 `fp_box = true` 框選，導致無法放任何兵。
  2. 在雙人輪流模式下按住 `Ctrl`＋左鍵（第 308 行）或手把 `LT＋A`（第 455 行），第 316 行 `if box` 仍會啟動無意義的框選。
- **建議**：在 [`_fp_reset()`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L780) 補上 `fp_tool = "brush"`，並將第 316 行改為 `if not _fp_duel_turns() and (box or (fp_tool == "select" and hit < 0)):`。

### 2. `_fs_extend` 的細步幅 `cur_step` 為區域變數，跨滑鼠移動事件時會重設回 `step`，使小步幅尋位失效
- **位置**：[free_place.gd:164-171](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L164-L171)
- **問題**：第 164 行 `var cur_step := step` 在每次收到滑鼠移動事件呼叫 [`_fs_extend`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L140) 時都會重設為完整 `step`（800 或 1000）。當滑鼠滑過既有兵或禁區導致 `_fs_try(p)` 失敗時，第 169-170 行雖設 `cur_step = 100.0` 並將 `fp_last` 移到失敗點 `from`，但當次事件的剩餘距離 `dist` 通常小於 `100.0` 而立即跳出 `while` 迴圈；下一幀滑鼠移動再進 `_fs_extend` 時，`cur_step` 又變回 `step`，必須從失敗點再拉滿整個 `step` 才會重試，依然留下兩倍空洞。
- **建議**：將 `cur_step`（或 `fp_retry_step := false`）改為成員變數，於 [`_fs_begin`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L97) 重設，跨事件保持 `100.0` 步進直到 `_fs_try(p)` 成功為止。

### 3. 按 `Enter` 鍵放兵繞過 `_allowed(selected)` 禁用／未解鎖檢查，且放置失敗時無任何提示
- **位置**：[free_place.gd:401-406](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L401-L406)、對照 [free_place.gd:328-331](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L328-L331)
- **問題**：[`_fp_press`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L328-L331) 放兵前會檢查 `if not call("_allowed", selected): _toast(L.t("err_type"), true)`，但 [`_fp_key`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L401-L406) 處理 `KEY_ENTER`／`KEY_KP_ENTER` 時直接呼叫 `_fs_begin(at)` 與 `_fs_commit()`，繞過了 `_allowed(selected)` 檢查；且若游標在禁區或部署區外導致 `_fs_try` 失敗，`_fs_commit()` 會因 `items.is_empty()` 直接靜默返回，沒有任何錯誤提示。
- **建議**：`KEY_ENTER` 應先檢查 `call("_allowed", selected)`，若 `_fs_begin(at)` 未能加入任何預覽點則顯示對應錯誤 Toast。

### 4. 框選整群搬移時，原位置只隱藏被拉的那一隻兵，同群其餘兵仍以 100% 不透明度留在原地
- **位置**：[free_place.gd:588-592](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L588-L592)、[free_place.gd:624-631](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L624-L631)
- **問題**：框選多隻兵並拖曳其中一隻時（`fp_sel.size() > 1 and fp_drag in fp_sel`），第 629-631 行在目標位置畫出整群半透明預覽，但第 589 行繪製既有單位時只寫 `if ar == a and i == fp_drag: continue`，導致原陣型只有 `fp_drag` 一隻消失，同群其他兵仍原封不動留在原位，畫面同時出現原位實心兵與新位半透明兵。
- **建議**：當 `fp_drag >= 0 and fp_sel.size() > 1 and fp_drag in fp_sel` 時，第 589 行應一併跳過所有 `i in fp_sel` 的單位。

### 5. 新手手勢動畫在全場模式會畫到敵方底線並超出畫面右緣，且未持續到落下一筆、「?」也無法重看
- **位置**：[free_place.gd:698-718](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L698-L718)、[free_place.gd:791-795](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L791-L795)、對照 [plan-ui.md:37-38](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/plan-ui.md#L37-L38)
- **問題**：
  1. 第 706 行以 `var ox: int = maxi(Army.EDGE, a.depth - 600)` 決定手勢 X 座標。若首次進入自由擺放是全場模式（`a.depth == 15800`），`ox` 會落在 `15200`（最右側敵方底線），手勢圓圈與右側說明文字 `hp + Vector2(20, ...)` 會直接壓在敵陣並超出畫面右緣。
  2. [plan-ui.md:37-38](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/plan-ui.md#L37-L38) 明訂手勢動畫「放下第一筆就消失」且「『?』裡可以重看手勢動畫」，但目前第 702 行播完一次 1.5 秒即關閉（未循環至第一筆落子，拖曳開始時也未立即關閉），且點「?」無法重播。
- **建議**：將 `ox` 改為 `maxi(Army.EDGE, mini(a.depth, 6000) - 600)`；以 `fmod(time - fp_gesture_at, 1.5) / 1.5` 循環播放並在 `_fs_begin`／`_fs_commit` 時設 `fp_gesture_at = -1.0`；點開或關閉「?」時可重設 `fp_gesture_at = time`。

### 6. 手把模式（`pad_mode`）下占地圈與對齊點陣仍以滑鼠座標為中心，且搬移／框選中按 Esc 或 B 無法取消
- **位置**：[free_place.gd:407-413](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L407-L413)、[free_place.gd:468-471](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L468-L471)、[free_place.gd:595-599](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L595-L599)、[free_place.gd:669-675](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6b/free_place.gd#L669-L675)
- **問題**：
  1. 第 595-599 行（友軍占地虛線圈）與第 669-675 行（對齊 3×3 點陣）只讀 `mouse` 與 `_fp_in_field(mouse)`，未在 `pad_mode` 時改用 `Vector2i(fp_cur)`，導致手把操作時占地圈與對齊點陣畫在滑鼠位置（或因滑鼠在場外而不顯示）。
  2. 搬移單位（`fp_drag >= 0`）或框選（`fp_box`）途中按 `Esc`（第 407 行）、右鍵（第 290 行）或手把 `B`（第 468 行）皆未取消 `fp_drag`／`fp_box`；手把按住 A 搬兵時按 `B` 甚至會因回傳 `false` 而穿透觸發返回選單。
- **建議**：第 595、669 行於 `pad_mode` 時改用 `Vector2i(fp_cur)`；右鍵、`Esc` 與手把 `B` 在 `fp_drag >= 0` 或 `fp_box` 時一併重設為 `-1`／`false` 並回傳 `true`。

結論：需修正
