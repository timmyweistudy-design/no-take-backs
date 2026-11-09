### 1. 第 1 輪「已修」項目驗證與指定重點檢查

#### （A）使用者指定重點逐項檢查

1. **[`battle_state.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L125) 的 [`proj_phase`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L125) 回傳 5 欄與所有呼叫端**
   - **驗證結果：已修妥，無呼叫端不相容問題。**
   - [`proj_phase`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L125) 現固定回傳 5 欄 `[出手 tick, 命中 tick, 飛行進度, 動作起點 tick, 前搖長度]`（空陣列回傳 `[-1, -1, -1.0, -1, ViewBuffer.DELAY]`）。投彈兵被貼身敲擊（`bonk_ticks` 含該命中 tick）時，`f` 強制為 `0`、`w` 強制為 `ViewBuffer.DELAY`，不會誤用遠程 1 tick 短前搖。
   - 全專案呼叫端共 4 處：
     - [`battle_units.gd:579-585`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L579-L585)：以 `ph[3]`（動作起點）與 `ph[4]`（前搖長度）傳入 [`atk_progress`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L37-L49)。
     - [`battle_units.gd:785-792`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L785-L792)：讀取 `phd[2]` 與 `phd[1]` 繪製飛行投射物。
     - [`ui.gd:1065-1079`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd#L1065-L1079)、[`ui.gd:1245-1248`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd#L1245-L1248)：測試皆以索引讀取欄位，並已涵蓋 `pb[3]`、`pb[4]` 驗證。

2. **[`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L197-L202) 轉身出手格兩列與 [`_post`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L140-L162) 的 `per` 參數**
   - **驗證結果：已修妥。**
   - [`ensure_turn_atk`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L197-L202) 的 `SubViewport` 高度已改為 `2 * CELL`（16 欄 × 2 列共 32 格），並以 `_post(img, ATK_FRAMES * 2)` 傳入 `per = 16`。
   - 對照 [`unit_bake.gdshader:17-18`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/shaders/unit_bake.gdshader#L17-L18)，第 0 列（`cidx = 0..15`）的 `team = 0` 套用藍方墨線 `ink0`，第 1 列（`cidx = 16..31`）的 `team = 1` 套用紅方墨線 `ink1`；[`draw_unit`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L410) 的 `fi` 索引亦與兩列座標一致。（唯 [`sprite_cache.gd:54`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L54) 註解仍寫 `16 欄 × 1 列`，屬舊註解殘留）。

3. **[`codex_bake.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L53-L73) 自動停用與著色器參數**
   - **驗證結果：自動停用已修好，但著色器 `cell` 參數計算引入了乾掃消失／漬洗過高的視覺問題（詳見第 3 節新問題 #1）。**
   - [`_process`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L62-L73) 在離開圖鑑超過 `300 ms` 後會將兩個 `SubViewport` 設為 `UPDATE_DISABLED`，再進圖鑑呼叫 [`set_params`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L68-L73) 時恢復 `UPDATE_ALWAYS`。
   - 但 [`codex_bake.gd:55`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L55) 將 `cell` 設為 `FEET.y / (160.0 / 192.0) = 444.0`，忽略了圖鑑立繪小人高度佔畫布比例遠小於圖集單格，導致一般立繪與 2.5 倍近看的頭頂 `ly > 0.50`，頂部乾掃亮邊完全變為 `0`。

4. **[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L844-L847) 的 [`_guard_fs`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L492-L496) 與確認框覆蓋層順序**
   - **驗證結果：設定頁內的覆蓋順序已修好，但從 `first_run` 與 `codes` 觸發確認框時有導覽跳頁問題（詳見第 3 節新問題 #3、#4）。**
   - [`_draw_confirm`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L844-L847) 先執行 `overlay = confirm_ret` 再呼叫 `confirm_cb.call()`，因此設定頁重置／匯入觸發 [`_guard_fs`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L492-L496) 時，`overlay = "fs_confirm"` 不再被蓋回 `"settings"`。

5. **[`replay_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L130-L168) 陣亡小旗重建**
   - **驗證結果：已修好 `age >= 1.0` 的小旗重建，但漏掉跳轉前 `1` 秒內（`age < 1.0`）陣亡的單位（詳見第 3 節新問題 #5）。**
   - [`_seek_tick`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L130-L152) 改以字典 `_seek_deaths[id] = sim.tick` 記錄死亡時間，並在 [`_seek_finish`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L155-L168) 先建立 `view = ViewBuffer.new(sim)` 再查 `view.unit_by_id(did)`，解決了原本 `view == null` 崩潰問題；但 `age < 1.0` 的陣亡單位因 `dying` 被清空且未進 `graves`，跳轉後既無倒棋也不會長出小旗。

6. **[`game_screens.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L264-L293) 點一下拿掉兵與拖曳搬移的分辨**
   - **驗證結果：格子模式已修好，但遺漏了預設的「自由排兵」模式 [`free_place.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L330-L387)（詳見第 3 節新問題 #2）。**
   - 格子模式在 [`game_screens.gd:268-291`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L268-L291) 按下一律記 `drag_from`，放開時若 `c == drag_from and Save.s("place_mode") == "tap"` 則撤兵，若 `c != drag_from` 則搬移，兩者不再衝突；然而自由排兵 [`_fp_release`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L344-L387) 沒有同步實作此邏輯。

---

#### （B）第 1 輪其餘「已修」項目逐條驗證

- **擺陣開圖鑑／規則後返回跳出大面板（Codex #1）**：[`game_screens.gd:101-128`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L101-L128) `_nav_back` 在 `state != St.TITLE` 時過濾掉 `hub_*` 並退回 `""`；開局入口已清空 `nav_stack`（已修妥）。
- **`wave_codes` 按 Esc 與手把 B 行為不一致（Codex #2、Antigravity #3）**：[`game_screens.gd:552-554`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L552-L554) 已將 `"wave_codes"` 從回設定清單移出，改設 `overlay = "codes"`（已修妥）。
- **重播／接力／時光機結束後蓋掉 `last_wave_codes`（Codex #6、Antigravity #2）**：[`game_result.gd:20-21`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L20-L21) 限定 `play_kind == "official"` 才寫入或清空 `last_wave_codes`（已修妥）。
- **`_record_match` 勝率口徑（Antigravity #1）**：[`game_result.gd:82-104`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L82-L104) 已改用 `unit_games_rec`／`unit_wins_rec` 新鍵並排除教學、殘局、遠征、沙盒，雙人模式改記勝方 `w` 的兵種；但對 AI 仍未排除試煉／每日／每週／幽靈／車輪戰／輪抽（見第 3 節新問題 #6）。
- **重播跳轉漏掉最後 `delay` tick 的軍令與逆轉標記（Antigravity #6）**：[`replay_view.gd:227-228`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L227-L228) 與 [`replay_view.gd:268-269`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L268-L269) 已移至 `if not fx_on: return` 之前（已修妥）。
- **`l10n_review.py` 格式碼正規表示式與 `l10n_build.py` 日文校對優先順序（Codex #10、#11）**：[`l10n_review.py:41`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_review.py#L41) 與 [`l10n_build.py:73-76, 120`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_build.py#L73-L76) 均已修妥。
- **寶箱怪與騎兵背面破綻（Antigravity #11）**：[`fantasy.gd:98-99, 132-134`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L98-L99) 與 [`kingdom.gd:370-378`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L370-L378) 已修妥。

---

### 2. 對「重新裁決」四條表態

1. **「再來一局」清掉 `nav_hub`（Antigravity #8）**
   - **表態：同意維持現狀（不改）。**
   - 理由：[`_play_again()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L279-L315) 在所有模式的重打分支之後才清 `nav_hub`，因此只要之後是透過 [`_go_title()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L66-L69) 回主畫面，`nav_hub` 實際上只有在打完不想再打、點「主畫面」時才被讀取，清掉只在重打那一局期間為空，不影響單局重打體驗，維持現狀合理。

2. **圖鑑預覽在 `cbm()`（色盲高對比）下仍套塗裝室的漬洗／乾掃（Antigravity #9）**
   - **表態：同意維持現狀（不改）。**
   - 理由：[`sprite_cache.gd:153-154`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L153-L154) 與 [`game_modes.gd:1651`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1651) 的設計就是色盲模式只鎖定兩隊底漆色（`row <= 1`），漬洗與乾掃在戰場圖集與圖鑑都照常生效，兩邊行為一致。

3. **軍令預演在試玩版被 `_demo()` 擋住（Antigravity #7）**
   - **表態：建議拿掉 [`game_place.gd:45`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L45) 的 `and not _demo()`（只需改同一行條件，不擴大範圍）。**
   - 理由：第 12 章殘局在試玩版原本就不開放（[`presets.gd:6`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/presets.gd#L6) `DEMO_PUZZLES = 5`），但在試玩版透過大廳自訂規則開啟軍令、或貼入含軍令的挑戰碼／工坊碼時，同畫面的 `plan_open`（時間軸按鈕，[`game_place.gd:802`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L802)）並未擋 `_demo()`，唯獨擺陣頂部「預演」按鈕被 `and not _demo()` 隱藏。拿掉這半句條件可消除試玩版自訂軍令局的操作不一致，且零風險。

4. **「只點選」模式在重播頁仍可拖時間軸（Antigravity #10）**
   - **表態：同意維持現狀（不改）。**
   - 理由：設定鍵名為 `set_place_mode`（「擺兵方式」），文案與功能範圍明確限定於擺陣階段，重播時間軸維持可點可拖最符合直覺。

---

### 3. 新問題與殘留問題（共 6 條）

1. **[`game/scripts/ui/codex_bake.gd:55`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L55)、[`game/shaders/unit_bake.gdshader:29-31`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/shaders/unit_bake.gdshader#L29-L31)**
   - **觸發條件**：打開圖鑑檢視任意兵種（一般立繪 `scale = 1.41～2.0` 或近看 `2.5x` 放大）。
   - **後果**：`codex_bake.gd:55` 將著色器 `cell` 設為 `FEET.y / (160.0 / 192.0) = 444.0`。在戰場圖集中，`CELL = 192`、小人高約 `80px`（頭頂 `ly ≈ 0.42 < 0.50`）；但在圖鑑 `600×400` 畫布中，`FEET.y = 370`，一般立繪與 `2.5x` 近看的小人高度僅 `70～125px`（頭頂 `px.y ≈ 245～300`，即 `ly = px.y / 444.0 ≈ 0.55～0.68`）。因為 [`unit_bake.gdshader:30`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/shaders/unit_bake.gdshader#L30) 的乾掃亮邊條件為 `ly < 0.50`（`px.y < 222`），導致圖鑑立繪與 `2.5x` 近看的**頂部乾掃（`hi_amt`）完全為 0（消失）**；同時 `ly > 0.62`（`px.y > 275`，腳底往上 `95px`）整段被當成底部漬洗區，導致小人從胸口／頭部以下整隻被壓暗。

2. **[`game/scripts/ui/free_place.gd:330-387`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L330-L387)（對照 [`game/scripts/ui/game_screens.gd:282-283`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L282-L283)）**
   - **觸發條件**：將「擺兵方式」設為「只點選」（`place_mode == "tap"`），在自由排兵模式（快速對戰／大廳預設 `deploy = "free"`、30 關試煉等）用左鍵、觸控或手把 A 點一下已擺好的我方單位。
   - **後果**：C4「只點選模式點一下自己的兵＝拿掉」只寫在格子排兵 [`game_screens.gd:282-283`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L282-L283)，自由排兵的 [`_fp_release()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L344-L387) 完全未處理 `place_mode == "tap"` 的點選撤兵。且因 [`_fp_press()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L325) 命中半徑為 `PICK_R = 350`，而放開時比較量化座標 `tgt = _q(w)` 與單位中心 `fp_drag_from`，點擊只要稍微偏離單位中心，不但不會撤兵，反而會把兵微幅搬移並多塞一筆 `fp_undo`。

3. **[`game/scripts/ui/screens/game_menus.gd:1261`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1261)、[`game/scripts/ui/screens/game_menus.gd:742`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L742)**
   - **觸發條件**：全新安裝首次啟動跳出 `first_run` 詢問框（`overlay == "first_run"`）時，點選底部三個無障礙預設按鈕（「大字體 150%」「減少動態」「色盲高對比」）任一個。
   - **後果**：[`_draw_first_run()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1261) 呼叫 [`_apply_preset(kk)`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L740-L742)，其中 `_ask_confirm(..., "settings")` 把 `confirm_ret` 寫死為 `"settings"`。無論玩家點確認、取消或按 Esc，都會直接跳進設定頁（`overlay = "settings"`）而非回到 `"first_run"`，且 `first_done` 維持 `false`，下次啟動仍會重複彈出首次啟動詢問。

4. **[`game/scripts/ui/screens/game_menus.gd:1116-1117`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1116-L1117)、[`game/scripts/ui/screens/game_menus.gd:820-825`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L820-L825)、[`game/scripts/ui/screens/game_menus.gd:499-507`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L499-L507)**
   - **觸發條件**：在「代碼」頁（`overlay == "codes"`）複製 `NTS1.` 設定碼，點「貼上並自動辨識」（[`_auto_code()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1090-L1120)）。
   - **後果**：`_auto_code()` 呼叫 [`_settings_import()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L820-L825)，而 `_settings_import()` 的 `_ask_confirm` 與全螢幕確認的 [`_fs_keep()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L499)／[`_fs_revert()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L506) 都將返回覆蓋層寫死為 `"settings"`。從代碼頁一鍵貼上設定碼後（無論確認或取消），畫面會從 `"codes"` 被強制跳轉到 `"settings"`。

5. **[`game/scripts/ui/replay_view.gd:138`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L138)、[`game/scripts/ui/replay_view.gd:161-168`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L161-L168)**
   - **觸發條件**：重播拉動時間軸跳轉到 `target`，而有單位在 `[target - 20, target - delay]`（目標時間前 `0.4s～1.0s`，手動軍令局為 `0.1s～1.0s`）期間陣亡。
   - **後果**：[`_seek_finish()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L161-L168) 清空了 `dying`，又只將 `age >= 1.0 and age < 4.0` 的陣亡單位放進 `graves`。因為小旗是在 `dying` 倒棋滿 1 秒退場時才生成（[`battle_view.gd:169-170`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L169-L170)），跳轉前 1 秒內陣亡的單位既不在 `dying` 也不在 `graves`，跳轉後不但倒棋消失，後續播放也**永遠不會長出陣亡小旗**。

6. **[`game/scripts/ui/screens/game_result.gd:82-104`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L82-L104)、[`game/scripts/ui/screens/game_core.gd:295-306`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_core.gd#L295-L306)**
   - **觸發條件**：遊玩試煉（`trial_id >= 0`）、每日挑戰（`not daily_spec.is_empty()`）、每週棋盒（`wk_active`）、幽靈軍團（`ghost_id != ""`）、車輪戰（`wv_active`）或遊戲間輪抽（`draft_on`）。
   - **後果**：上述 6 種模式皆共用 `mode = Mode.VS_AI`：
     1. [`_record_match()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L96-L103) 只判斷 `mode == Mode.VS_AI` 就更新連勝：玩家在試煉、每日／每週挑戰或車輪戰落敗會把一般對 AI 的連勝（`streak`）歸零；反之重複打幽靈或試煉第 1 關可洗高 `best_streak` 與解鎖 `STREAK_5`。
     2. 這些挑戰與遊戲間模式（因 `rounds == 1` 或非標準規則，`standard == false`）的場數與兵種勝率，會全部混入個人戰績的「自訂規則（`custom_stats`）」與兵種出戰／勝率統計中。
