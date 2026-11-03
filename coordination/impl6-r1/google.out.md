以下為根據 [review-input.md](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/review-input.md) 對照 [plan-ui.md](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md)、[free_place.gd](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd)、[ui.diff](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff) 與 7 張截圖之審查結果（依嚴重度由高至低排序，共 8 條）：

---

### 1. 外部清空或載入陣型未重置 `fp_sel`／`fp_drag`，按 Delete 或 M 會索引越界崩潰或誤刪
- **位置**：[free_place.gd:200-219](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L200-L219)、[free_place.gd:446-473](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L446-L473)、[ui.diff:309-332](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L309-L332)
- **問題**：`fp_sel` 儲存的是 `a.units` 的陣列索引（`int`）。當玩家框選數隻兵後，點選右下角「清空」或「陣型」載入較少兵數的存檔時，`a.units` 被外部替換或清空，但 `fp_sel` 與 `fp_undo` 未同步清理。此時若按 `Delete`（[`_fp_delete_sel`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L200-L210) 直接 `a.units.remove_at(i)`）或 `M`（[`_fp_flip_sel`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L212-L218)），會因舊索引超出 `a.units.size()` 而發生越界錯誤，或誤刪／誤翻新載入陣型中的兵。
- **建議**：在執行「清空」、載入陣型（[`_load_checked`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L309)）或切換操作隊伍時，清空 `fp_sel = []`、`fp_drag = -1`；並在 [`_fp_delete_sel`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L208-L209) 與 [`_fp_flip_sel`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L212-L218) 加上 `i >= 0 and i < a.units.size()` 防護。

### 2. 拖曳中開啟覆蓋層會讓畫筆／搬移／框選／擦除狀態卡死；整群平移拖出界外會誤刪單兵
- **位置**：[free_place.gd:222-301](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L222-L301)、[ui.diff:207-216](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L207-L216)
- **問題**：
  1. 若在按住滑鼠拖曳（`fp_stroking`、`fp_drag >= 0`、`fp_box`、`fp_erasing`）或手把按住 A/X 期間觸發 `overlay != ""`（例如點到「?」或按熱鍵開視窗），放開按鍵時 [`_fp_mb`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L223) 與 [`_fp_pad_button`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L357) 會因 `overlay != ""` 直接返回 `false`，而 `game_screens.gd` 的 `_mb_release_cleanup()` 未清理自由模式狀態，關閉覆蓋層後會卡在拖曳／擦除狀態。
  2. 在 [free_place.gd:279-283](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L279-L283) 中，當玩家框選整群兵（`fp_sel.size() > 1`）進行剛體平移時，若滑鼠不小心滑出戰場邊界（如左側工具列）放開，會先觸發 `not _fp_in_field(p)` 而**直接把被拉的那一隻兵刪除並清空選取**，其餘兵留在原地，與「整群剛體平移」預期不符。
- **建議**：在 `_mb_release_cleanup()` 中呼叫 [`_fs_cancel()`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L136) 並重設 `fp_drag = -1`、`fp_box = false`、`fp_erasing = false`、`fp_pad_a = false`、`fp_pad_x = false`；當 `fp_sel.size() > 1 and i in fp_sel` 時，應走整群平移檢查而非單兵拖出界刪除。

### 3. 框選整群拖曳缺乏整群預覽，且單兵搬移預覽朝向寫死為藍方
- **位置**：[free_place.gd:446-447](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L446-L447)、[free_place.gd:470-473](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L470-L473)、對照 [plan-ui.md:10](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L10)
- **問題**：
  1. 框選多隻兵後拖曳其中一隻時，[`_fp_draw`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L470-L473) 只隱藏並畫出 `fp_drag` 單隻兵的半透明預覽，同群其他兵完全不動，玩家看不出整群平移後陣型是否出界或撞到其他兵。
  2. 第 473 行 `_unit(..., 1.0, ...)` 將搬移中單位的朝向寫死為 `1.0`（面向右），雙人暗擺輪到紅方搬兵時會反向。
- **建議**：當 `fp_drag in fp_sel and fp_sel.size() > 1` 時，依位移差 `tgt - fp_drag_from` 一併繪製 `fp_sel` 所有單位的預覽小人；並將朝向改為 `1.0 if a.team == 0 else -1.0`。

### 4. 手把操作漏做規格中的「LT+A 框選」、「LB/RB 換兵」，且按住 A/X 配十字鍵無法畫筆或擦除
- **位置**：[free_place.gd:341-401](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L341-L401)、[ui.diff:189-192](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L189-L192)、對照 [plan-ui.md:21-22](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L21-L22)
- **問題**：
  1. [plan-ui.md:22](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L22) 明訂手把「按住 LT＋A 拖＝框選」與「LB／RB：換兵種」，目前 [`_fp_pad_button`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L356-L401) 完全未實作 LT 框選，且 `ui.diff:189` 未攔截或確認 LB/RB 在自由模式下換兵種。
  2. 按住 A（畫筆）或 X（連續清除）並用**十字鍵（DPAD）**每 0.5 格移動游標時（第 394-400 行），只更新了 `fp_cur` 座標，**漏了呼叫 `_fs_extend(Vector2i(fp_cur))` 與 `_fp_erase_at(Vector2i(fp_cur))`**，導致十字鍵無法用來拉直線／畫筆或連續清除。
  3. 搖桿游標夾限為 `200..15800` / `200..8800`（第 348-349 行），但十字鍵夾限為 `500..15500` / `500..8500`（第 398-399 行），兩者邊界不一致。
- **建議**：在 DPAD 更新 `fp_cur` 後補上 `if fp_stroking: _fs_extend(Vector2i(fp_cur))` 與 `elif fp_pad_x: _fp_erase_at(Vector2i(fp_cur))`；統一搖桿與十字鍵的邊界夾限；補齊 LT+A 框選與手把搬群邏輯。

### 5. 畫面回饋多處未達規格：工具列位置與規格不符、缺金幣條預扣斜線、缺多隻預覽首尾射程、缺密集區腳底中心點透出
- **位置**：`27_free_place.png`、`27b_free_brush.png`、[free_place.gd:475-529](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L475-L529)、[free_place.gd:547-567](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L547-L567)、對照 [plan-ui.md:17, 30-37](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L17)
- **問題**：
  1. **金幣條預扣斜線未做**（[plan-ui.md:33](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L33)）：`27b_free_brush.png` 拖曳預覽花費 25 金時，頂部金幣進度條完全沒有畫出預扣斜線段。
  2. **多隻預覽首尾射程未做**（[plan-ui.md:32](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L32)）：規格要求多隻同時預覽時「只畫第一隻和最後一隻的射程」，但 [free_place.gd:514](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L514) 寫 `if not drag_on:`，把拖曳中的射程預覽全部關掉了。
  3. **密集區腳底中心點透出未做**（[plan-ui.md:30](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L30)）：游標進入密集區時，沒有將所有兵的腳底中心點透到最上層。
  4. **新手引導缺 1.5 秒手勢動畫**（[plan-ui.md:37](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L37)）：[ui.diff:337-340](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L337-L340) 只改了說明文字，未實作部署區前排 1.5 秒手勢動畫（且工具列改為左側直排雖避開戰場，但註解第 547 行仍寫「戰場上緣的浮動膠囊列」並壓在左側背景樹上）。
- **建議**：補上拖曳中頂部金幣條的預扣斜線、在 `fp_stroking` 時針對 `fp_stroke[0]` 與 `fp_stroke[-1]` 繪製射程圈、補上游標周圍兵的腳底中心亮點透出，並更新 `plan-ui.md` 或補齊手勢動畫。

### 6. 解鎖橫幅（Toast）嚴重遮擋畫面標題與戰場底部單位，且全場敵兵禁區紅圈疊加過濃並超出戰場邊框
- **位置**：`28_free_full_ai.png`、`29_free_duel_full.png`、`30_lobby_deploy.png`、`31_review_free.png`、[free_place.gd:424-425](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L424-L425)
- **問題**：
  1. **橫幅遮擋**：在 `30_lobby_deploy.png` 與 `31_review_free.png` 中，「新兵種解鎖：醫者！…」橫幅直接蓋在視窗主標題（「對 AI 快速對戰」、「覆盤：如果當初改一隻兵」）正上方造成文字重疊；在 `28_free_full_ai.png` 與 `29_free_duel_full.png` 中，下方同一個橫幅又直接蓋住戰場下緣，把 `28_free_full_ai.png` 下方的藍方騎兵與紅方弓騎兵整個遮住。
  2. **禁區紅圈疊加與溢界**：在 `28_free_full_ai.png` 中，[free_place.gd:424-425](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L424-L425) 逐一對敵兵畫 `alpha = 0.10` 的紅圓，密集處十幾個圓重疊成深紅塊（未如 [plan-ui.md:34](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/plan-ui.md#L34) 融合成均勻一片淡紅），且上下兩端的紅圈超出戰場木框畫到了頂部資訊列與底部卡牌列邊界。
- **建議**：修正 Toast 繪製位置（避免同時出現在上下兩處或壓住標題與戰場內單位）；敵兵禁區紅圈應限制（clip）在 `Rect2(ORIGIN, FIELD)` 內並以統一透明度融合繪製。

### 7. 大廳「全場明牌」開啟時「部署縱深」仍顯示可調（誤導），且覆盤全場模式漏畫敵兵禁區
- **位置**：`30_lobby_deploy.png`、`31_review_free.png`、[ui.diff:541-575](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L541-L575)
- **問題**：
  1. 在 `30_lobby_deploy.png` 中，「全場明牌（AI 先擺好公開）」已設為「開」，右側說明也顯示「可以擺在全場任何地方」，但左側「部署縱深」仍顯示 `7.50 格` 且左右箭頭亮起可按，右側差異列表也同時列出「部署縱深 6.00→7.50」與「全場部署 開」，誤導玩家以為全場模式下縱深設定仍有效。
  2. 在 [ui.diff:379-384](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L379-L384) 中，全場模式覆盤雖有設定 `rv_army.enemy_pos` 限制搬移不可進敵兵 1.5 格內，但 [`_rv_free_board`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/ui.diff#L565-L567) 繪製全場小戰場時卻沒畫敵兵禁區紅圈，玩家點空地搬移失敗時看不出哪裡是禁區。
- **建議**：大廳開啟全場部署時，將「部署縱深」列設為停用（顯示「全場」）並從差異列表排除；全場覆盤小戰場應一併畫出敵兵禁區淡紅圈。

### 8. 畫筆滑過既有兵或禁區時取樣步進過大導致多跳空位，且費用泡泡文案與邊界處理不當
- **位置**：`27b_free_brush.png`、[free_place.gd:123-135](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L123-L135)、[free_place.gd:482-488](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L482-L488)
- **問題**：
  1. 在 [`_fs_extend`](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6/free_place.gd#L128-L134) 中，每次迴圈無論 `_fs_try(p)` 成功與否，都直接將 `fp_last` 往前推進整段 `step`（例如 800 或 1000）。當畫筆滑過既有友軍或敵兵禁區邊緣導致該點 `_fs_try` 失敗時，下一次嘗試會直接跳過整段 `step`，在障礙物後方留下將近兩倍間距的空洞。
  2. 在 `27b_free_brush.png` 中，玩家剩 29 金（19/24 隻），預覽 5 隻劍士（25 金）後剩 4 金買不起第 6 隻，泡泡卻顯示「`-25 金・5 隻　錢或人數用完`」，讓人誤以為這 5 隻放完剛好 0 金或滿 24 隻；且泡泡座標 `mouse + Vector2(18, -36)` 未做邊界夾限，靠近戰場右緣或上緣拖曳時會跑出戰場外。
- **建議**：當 `_fs_try(p)` 因位置重疊／禁區失敗時，改用細步幅（如 `100`）推進 `from` 與 `fp_last`，直到成功放下一隻後再恢復以 `step` 步進；費用泡泡加上畫面邊界 `clamp`，並區分「餘額不足」與「人數已滿」提示。

結論：需修正
