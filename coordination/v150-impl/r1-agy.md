以下為《落子無悔》V1.5.0（M1＋M2 前半及圖鑑檢視控制）唯讀審查報告，共 **12 條**，依嚴重度由高至低排序：

---

### 1. 【嚴重｜實際 Bug＋違反方案 §3.1】遠程施放者先死、高速出手或重播跳轉時，飛行中投射物會憑空消失或殘留舊目標
- **位置**：[`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L454-L456)、[`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L576-L591)、[`battle_state.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L66-L108)、[`battle_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L226-L232)、[`replay_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L156-L162)
- **觸發條件與後果**：
  1. **施放者先死**：[`_draw_units_of()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L454-L456) 只遍歷 `if u.alive`，且投射物是在遍歷存活單位時才塞入 `proj_draw`（[#L588-L591](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L588-L591)）。當遠程單位在出手 tick `hr` 後、命中 tick `h` 前死亡，飛行中的箭／炸彈／火球會在發射者死亡瞬間**半空蒸發**，到了 `h` 目標卻憑空爆血，直接違反方案 §3.1「施放者先死」回歸案例。
  2. **前瞻緩衝截斷與覆蓋**：[`ViewBuffer.DELAY_LONG = 8`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L19) 拉長至 8 tick 後，[`_pump_view()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L230) 仍限制 `if hs.size() > 4: hs.pop_front()`，且 [`proj_phase()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L104) 對 `hs = hits - fly` 呼叫 [`pick_hit()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L66-L81)。只要飛行時間長（如投彈兵 `fly = 6`、弓手 `fly = 5`）或含反擊／多目標事件使 8 tick 內累積超過 4 筆，或下一發前搖在上一發落地前開始，`pick_hit` 會提前切到下一發 `hr`，上一顆還在飛的投射物即半途消失。
  3. **重播跳轉殘留**：[`_seek_finish()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L158-L162) 只清了 `atk_hit` 與 `atk_seq`，漏清 `proj_tgt` 與 `alt_hit`，跳轉時間軸後舊目標座標殘留。

---

### 2. 【嚴重｜實際 Bug】圖鑑 16 方向轉身把背面（180°～360°）鏡像成正面，且 90°／270° 左右瞬跳、點「出手」時角度不會重置或共存異常
- **位置**：[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L554-L584)、[`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L27-L31)
- **觸發條件與後果**：
  1. 在 [`_cx_portrait()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L561-L565) 中，角度只取 `cf := cos(cx_angle / 16.0 * TAU)` 並算 `Art.turn_s = sqrt(1.0 - Art.turn_c * Art.turn_c)`（恆為正）。因為 $\cos(\theta) = \cos(2\pi - \theta)$，`cx_angle` 9～15（背面半圈）算出來的 `face`、`turn_c`、`turn_s` 與 `cx_angle` 7～1（正面半圈）**完全一模一樣**，根本轉不到背面。
  2. 當 `cx_angle` 從 3（67.5°）切到 5（112.5°）跨過 90° 時，`Art.turn_c` 被 `maxf(absf(cf), 0.3)` 夾在 `0.3`，而 `face` 從 `+1` 突變成 `-1`，角色在正面直接左右鏡像瞬跳。
  3. 先點 `◀`/`▶` 使 `cx_angle >= 0`，再點「出手」（[#L370](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L370)），`cx_angle` 未歸 `-1`；對一般單位（`CX_FIT <= 1.4` 走圖集），[`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L354) 會在 `atk > 0` 時強制把 `face` 夾回 `±1.0` 側面，放開後又跳回轉身幀。

---

### 3. 【高｜實際 Bug】設定頁右側說明欄滑鼠碰撞區錯位 30～60px、手把導覽完全不更新說明，且 `KEY_ESCAPE` 呼叫未定義函式
- **位置**：[`game_screens.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L331-L340)、[`game_screens.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L682-L693)、[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L509-L523)
- **觸發條件與後果**：
  1. [`_draw_settings()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L509-L520) 每列繪製在 `y0 + i * 60`（一般分頁 `y0 = 166.0`，無障礙分頁 5 因為頂端有預設組合列，`y0 = 226.0`）；但 [`_settings_hover()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L683-L691) 卻用舊常數 `196.0 + i * 66.0` 判定滑鼠懸停！導致滑鼠移到下方列或第 5 分頁時，右側說明卡顯示的是**錯位的一項**；且用手把／鍵盤移動 `_focus` 時完全沒更新 `settings_item`。
  2. [`_key()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L331-L340) 在 `overlay == "settings"` 按 Esc 呼叫 `call("_settings_close")`、`overlay == "pause_menu"` 呼叫 `call("_pause_resume")`、正式戰鬥中按 Esc 呼叫 `call("_open_pause_menu")`，但這三個函式在繼承鏈中皆未定義（實際關閉設定是直接設 `overlay = ""`）。

---

### 4. 【高｜實際 Bug】視窗最小化再還原後，`Engine.max_fps` 被強制設為 `0`，覆寫玩家的「幀率上限」設定
- **位置**：[`game_screens.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L385-L390)、[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L891-L892)
- **觸發條件與後果**：玩家在設定選了 30／60／120 FPS（由 [`_apply_display()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L892) 設定），只要把視窗最小化再切回來，[`_throttle_when_minimized()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L390) 就會執行 `Engine.max_fps = 10 if mini else 0`，把幀率上限洗成 `0`（無上限）。

---

### 5. 【高｜違反方案 §3.3、§3.4】轉身系統仍沿用 V1.3 單軸水平壓縮，未實作 360° 八關鍵姿態、前後手深度交換、背面遮擋與圖鑑直接繪製烘焙後處理
- **位置**：[`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L27-L115)、[`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L16-L31)、[`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L351-L360)、[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L581)
- **違反內容與後果**：
  1. 方案 §3.3 要求廢除 `turn_c >= 0.3` 水平壓縮，改為 0°／45°／90°／135°／180°／225°／270°／315° 八個關鍵姿態並依旋轉後深度動態交換前後手與武器繪製順序；目前 [`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L29) 仍用 `turn_c = 1.0` 與 `turn_s` 做 X 軸縮放平移，[`_infantry()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L120-L129) 永遠按「身體→頭→武器→前拳」固定順序畫，轉身時遠近手不會交換，也完全沒有 270° 背面（披風／髮髻／箭袋／盾背遮住五官）。
  2. 方案 §3.3 要求「攻擊途中轉身改走新系統（圖集沒有的就當幀直接繪製）」，但 [`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L354) 仍在 `atk > 0.0` 時把 `absf(face) < 0.9` 硬切回 `±1.0`。
  3. 方案 §3.4 要求圖鑑直接繪製也套用烘焙後處理（`unit_bake.gdshader` 外框、漬洗、乾掃），但 [`_unit()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L352-L355) 在 `scale > 1.4`（如長槍兵 `CX_FIT[5] = 1.41`）直接呼叫 `Art.unit` 時未經過烘焙 shader，外框與漬洗質感在放大／轉身時突變。

---

### 6. 【高｜實際 Bug＋違反方案 §2.1】套用／撤回預設組合與匯入 `NTS1` 設定碼未觸發套用副作用，且單次點擊連續寫入磁碟達 34 次
- **位置**：[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L554-L570)、[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L593-L611)、[`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L172-L176)
- **觸發條件與後果**：
  1. [`_apply_preset()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L554-L561)、[`_undo_preset()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L563-L570) 與 [`_settings_import()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L607-L609) 只呼叫 `Save.set_setting(k, ...)`，完全沒呼叫 `_apply_fullscreen()`、`_apply_display()`、`_load_fonts()`（更新 `plain_titles`）、`sfx.apply_settings()` 或 `_rebuild_sprites()`（更新 `colorblind` 圖集）。匯入設定碼後畫面、音量、色盲圖集與全螢幕都不會即時生效。
  2. `Save.set_setting()` 每次都會呼叫 `save_settings()` 寫檔；匯入一組 `NTS1` 會在迴圈裡同步寫入 `settings.json` 與 `.bak` **連續 34 次**。

---

### 7. 【中｜違反方案 §2.1、§2.2】設定 7 分頁 45 項有多項缺漏、錯置、預設值與步進不符，且匯入／還原無預覽確認、清除資料刪錯標的
- **位置**：[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L446-L542)、[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L593-L694)、[`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L10-L24)、[`ui_base.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L438)
- **違反內容**：
  1. **缺漏項目**：缺少方案 §2.2 的第 20 項「滑鼠／觸控擺放（點選／拖曳／兩者）」、第 21 項「持續操作方式（按住／切換）」、第 36 項「最近重播自動保存」、第 39 項「最近重播保留場數（20／50／100）」；以及方案 §2.1 的「每頁進階收合」、「單項／單頁恢復預設」、「視窗變更限時復原」。
  2. **錯置項目**：第 45 項「開啟塗裝室」被放在分頁 0（畫面，[#L455](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L455)）而非方案規定的分頁 1（介面進階區末）；無障礙三大預設只出現在分頁 5（[#L510](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L510)），未置於設定共通頂列，且套用前未列出差異預覽。
  3. **數值與預設不符**：
     - 10 提示停留：方案為「6 秒／12 秒／手動關閉（預設 6 秒）」，實作為 `toast_mult` `[1,2,3] × 2.0s`＝**2／4／6 秒**且無手動關閉（[`ui_base.gd#L438`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L438)）。
     - 11～15 音量：方案為「步進 5%」，實作僅 5 檔（`[0, 25, 50, 75, 100]`）。
     - 23 搖桿死區：方案為「5～40%，步進 5%，預設 20%」，實作為 `[20, 35, 50]`、預設 `35%`。
     - 24 預設播放速度：方案為「0.25／0.5／1／2／4／8 倍」，實作僅 `[0.5, 1.0, 2.0]`。
     - 27 特效／34 鏡頭震動／35 受擊閃白：特效缺「重點」檔；震動預設寫成 `100%`（方案為 `25%`）；閃白預設寫成 `100%`（方案為「柔和」）。
  4. **高風險操作無預覽／刪錯項目**：匯入設定碼（[#L593](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L593)）與還原備份（[#L640](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L640)、[#L668](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L668)）點下即直接覆寫存檔，無差異／覆蓋範圍預覽；第 41 項「清除資料」（[#L671](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L671)）做成了刪「教學進度／殘局星數」，而非方案規定的「快取／未收藏重播／戰績與宿敵／全部進度」。

---

### 8. 【中｜違反方案 §1】主畫面五大牌匾未在右側原地展開第二層，且缺少快速對 AI、10 格預設、遠征預覽、相簿、萬用代碼自動辨識與鍵盤 `1`～`5`
- **位置**：[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L205-L303)、[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L805-L870)、[`game_screens.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L303-L343)、[`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L6)
- **違反內容**：
  1. 方案 §1 要求「點了在右側展開第二層卡片，不另開畫面」；實作點牌匾會開全螢幕遮罩面板 `overlay = "hub_*"` 蓋掉主畫面，點「遠征」更直接進選關而不展開「繼續／新遠征、路線預覽、上一趟戰報」。
  2. 「對戰」缺少**快速對 AI**、**再來一場（含上一局摘要）**，且我的預設仍為 `MAX_PRESETS = 5`（[`save.gd#L6`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L6)，方案要求 10 格）；「收藏」缺少**重播與戰報相簿**與**陣型庫**；[`home_tag()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L813-L825) 漏掉第 5 塊牌匾「收藏」的「新宿敵」小籤；標題畫面按鍵盤 `1`～`5` 無法直接選牌。
  3. 「輸入代碼」([`_draw_codes()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L291-L303)) 仍是舊版三顆分開按鈕（觀戰／挑戰／每週種子），未實作方案 §1 的「一鍵貼上剪貼簿，自動辨識規則碼、陣型碼、重播碼、挑戰碼、殘局碼、備份碼／設定碼 `NTS1`」。

---

### 9. 【中｜違反方案 §3.4＋角色圖缺件】圖鑑缺少「逐格」、「假人標靶與投射物飛行區」、「完整棋子／近看細節切換」，導致遠程出手完全無投射物
- **位置**：[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L350-L372)、[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L554-L584)、[`units_sheet.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/review/v150/units/units_sheet.png)
- **觸發條件與後果**：
  1. 圖鑑右側目前只有「`◀`、角度／慢動作、出手、`▶`」4 顆按鈕（[#L364-L371](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L364-L371)），缺少方案 §3.4 規定的「逐格」、「完整棋子／近看細節切換」、以及「攻擊對象假人與飛行區（標明示意假人 vs 真實模擬）」。
  2. [`_cx_portrait()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L581) 只畫單一角色本體，完全不畫投射物；因此在圖鑑點「出手」以及 [`units_sheet.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/review/v150/units/units_sheet.png) 的打擊幀（第 9～10 欄）中，**列 3（弓箭手）、列 7（投彈兵）、列 8（醫者）、列 14（火法師）、列 16（巫毒娃娃）、列 18（死靈法師）、列 21（冰法師）** 出手後手上的箭／炸彈／法球直接消失、前面卻沒有任何投射物飛出（投彈兵列 7 第 9～10 欄變成空手揮拳）。

---

### 10. 【中｜角色圖缺件／穿模（列 1、2、3、6、9、10、22）】握持三層與長柄分段未落實：狂戰士遠斧未遮擋、長槍與騎槍未分段、弓手拳頭懸空、鼓手與小骷髏無手握持
- **位置**：[`units_sheet.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/review/v150/units/units_sheet.png)、[`kingdom.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd)、[`fantasy.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd)
- **具體列號與問題**：
  - **列 10（狂戰士，[`kingdom.gd#L289-L301`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L289-L301)）**：雙斧 `for k2 in 2` 都在身體與頭畫完之後才畫，轉身幀（第 2～4 欄）遠端那把斧頭直接疊在胸口與臉上，未依方案 §3.2 被身體遮住，且斧柄尾端無柄頭露出拳後。
  - **列 6（長槍兵，[`kingdom.gd#L183-L195`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L183-L195)）＆列 4（騎兵，[`kingdom.gd#L126-L130`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L126-L130)）**：長槍與騎槍整根槍桿只在同一層一次畫完，未依方案 §3.2 分成「身後柄尾＋身前槍身」兩段，且長槍只有單顆懸空前拳、無後手托柄。
  - **列 3（弓箭手，[`kingdom.gd#L66-L86`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L66-L86)）**：弓身圓弧頂點在 `bc.x + 18`（`x = 30`），但握弓的拳頭卻畫在 `bc + Vector2(12, 0)`（`x = 24`），導致全部 14 欄中握弓拳都**懸空浮在弓肚內側**、沒有握在木弓握把上。
  - **列 9（鼓手，[`kingdom.gd#L276-L277`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L276-L277)）＆列 22（小骷髏，[`fantasy.gd#L381-L382`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L381-L382)）**：鼓手的兩根鼓槌與小骷髏的骨刀完全沒有畫手掌／拳頭（`_fist`），也沒有露出手後的短柄尾，武器直接懸空飄在身體旁（違反方案 §3.2）。
  - **列 1（劍士，[`kingdom.gd#L19-L36`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L19-L36)）＆列 2（盾兵，[`kingdom.gd#L40-L60`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L40-L60)）**：轉身幀（第 2～4 欄）劍士的劍刃與護手直接橫切在臉正中央；盾兵的盾牌未隨角度做透視縮窄與厚度邊，整塊側面大盾像紙板一樣橫移蓋住半張臉，且無持盾手。

---

### 11. 【中｜角色圖紙片感／斷裂（列 4、5、8、9、12、13、16、19）】四足獸與圓鼓轉身成紙片壓扁、五官與圍巾未隨角度轉動、吸塵貓軟管與背包脫節
- **位置**：[`units_sheet.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/review/v150/units/units_sheet.png)、[`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L14-L21)、[`kingdom.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd)、[`fantasy.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd)
- **具體列號與問題**：
  - **列 19（吸塵貓，[`fantasy.gd#L276-L315`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L276-L315)）**：集塵背包放在 `_part(ci, 4.0, 0.6)`（轉身時往右移並疊在貓頭／耳朵上），而軟管起點 `Vector2(-6, -18)` 卻放在 `_part(ci, -4.0, 1.0)`（轉身時往左移），導致第 2～4 欄轉身幀中**吸塵軟管與背後集塵桶完全斷開**（違反方案 §3.2「吸塵貓吸管接到背後集塵桶」）。
  - **列 4（騎兵，[`kingdom.gd#L90-L120`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L90-L120)）＆列 12（爆爆羊，[`fantasy.gd#L52-L81`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L52-L81)）**：轉身幀（第 2～4 欄）只是把側面馬身／馬頭與羊身絨球做水平壓縮，馬嘴、馬眼與羊眼仍維持側面朝右構圖，呈現明顯「紙片壓扁感」。
  - **列 5（刺客，[`kingdom.gd#L141-L160`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L141-L160)）、列 13（寶箱怪，[`fantasy.gd#L116-L118`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L116-L118)）、列 16（巫毒娃娃，[`fantasy.gd#L207-L212`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L207-L212)）**：刺客的雙尾長圍巾（`x = -30`）未包進 `_back()`，轉身時仍僵硬往左平伸，雙眼也未透過 `_eyes()` 隨角度移位；寶箱怪與巫毒娃娃的鈕扣眼／縫線座標寫死，第 2～4 欄轉身時五官完全不動。
  - **列 8（醫者，[`kingdom.gd#L234-L250`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L234-L250)）＆列 9（鼓手，[`kingdom.gd#L265-L267`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L265-L267)）**：轉身幀（第 2～4 欄）醫者高帽不縮但十字杖被壓成細線；鼓手的大圓鼓被 `_part(ci, -10.0, 0.7)` 水平壓扁成細長膠囊狀，鼓框 `draw_arc` 與鼓面比例變形。

---

### 12. 【低｜違反鐵則＋實際 Bug】搖桿死區只套用在設定選單一處（其餘畫面仍寫死 `0.3`／`0.6`），且多處 UI 違反「字串不寫死」鐵則
- **位置**：[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L92-L95)、[`game_screens.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L193-L201)、[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L368)、[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L618)
- **觸發條件與後果**：
  1. `Save.s("deadzone")` 只在 [`game_menus.gd#L92`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L92) 被讀取，而且公式 `maxf(0.6, int(Save.s("deadzone")) / 100.0 + 0.2)` 在死區 20% 與 35% 時都被 `maxf(0.6, ...)` 吃掉（恆為 `0.6`，形同虛設）；同時 [`game_screens.gd#L193-L200`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L193-L200) 的左搖桿推方向仍寫死 `0.6` 與 `0.3`，完全沒讀 `deadzone` 設定。
  2. 違反 [`CLAUDE.md`](file:///mnt/c/Users/timmy/projects/no-take-backs/CLAUDE.md#L28)「字串不寫死（統一走 `loc.gd`）」鐵則：例如 [`codex_view.gd#L368`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L368) 直接寫死 `"0.25×"`、[`game_menus.gd#L618`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L618) 直接寫死 `" (save_backup.json)"`、[`game_modes.gd#L1057-L1082`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1057-L1082) `ACH_DESC` 與 [`#L855`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L855) `AI_TPL_EN` 仍將雙語字串寫死在腳本常數中而非 `strings.csv`。（註：舊 10 種兵 `FINGERPRINT = 3357149161` 與模擬層不讀畫面狀態兩項鐵則目前檢查未違反。）
