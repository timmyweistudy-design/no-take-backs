以下為《落子無悔》V1.5.1 第 1 輪實作審查報告（比對方案 [2026-11-09-v1.5.1-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/2026-11-09-v1.5.1-plan.md)、裁決紀錄 [ledger.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md) 與 `game/`、`tools/` 實作）。

---

## 一、實作問題清單（共 12 條，依嚴重度排序）

### 1. [嚴重] 戰績兵種勝率把「敵方 AI 陣容」一併計入玩家場數與勝場（鏡像必 100% 勝率），且漏擋沙盒徽章與挑戰子模式
- **檔案與行號**：[`_record_match`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L879-L905)、[`_finish_battle`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L86-L87)、[`_progress_and_achievements`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_core.gd#L291-L321)
- **觸發條件**：
  1. 在對 AI（`Mode.VS_AI`）或遠征（`Mode.GAUNTLET`）完賽進入 [`_record_match(w)`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L884-L905)。
  2. 開啟「沙盒／實驗室徽章」（`Presets.BADGE_LAB`，例如單兵能力調 300%）完賽。
  3. 遊玩試煉、每日挑戰、每週挑戰、幽靈挑戰、車輪戰或輪抽對決（內部皆設 `mode = Mode.VS_AI`）。
- **後果**：
  1. **敵我陣容混算**：`seen` 迴圈跑 `for a in armies:`（同時掃描 `armies[0]` 玩家與 `armies[1]` 敵方），而 `won` 掃描 `for u in armies[w].units:`（勝方隊伍）。導致：
     - **鏡像兵種必 100% 勝率**：只要玩家與 AI 都帶了劍士，該局 `seen` 記劍士 1 場；無論玩家贏（`w=0`）或 AI 贏（`w=1`），`armies[w]` 都有劍士，`unit_wins_rec` 必 +1（永遠 100% 勝率）。
     - **輸給 AI 卻幫 AI 的兵種記勝場**：玩家沒帶弓兵但輸給 AI 的弓兵（`w=1`），玩家戰績裡的弓兵竟會增加 1 場上場與 1 場勝場。
  2. **沙盒與特殊挑戰全混入戰績**：[`_progress_and_achievements`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_core.gd#L291-L294) 在 `badge == Presets.BADGE_LAB` 時提早返回（「沙盒什麼都不記」），但 [`_finish_battle`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L86) 在其之前無條件呼叫 `_record_match(w)`，且未排除 `BADGE_LAB`、`trial_id > 0`、`daily_spec`、`weekly_on`、`ghost_id`、`wave_on`、`draft_on`，違反方案 0.2。

---

### 2. [嚴重] M0 返回堆疊：`hub_*` 開戰進入排兵畫面（`St.PLACE`）未清空 `nav_stack`，排兵中開圖鑑／陣型槽／提示按返回會跳出標題面板
- **檔案與行號**：[`_draw_hub`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1179)、[`_start_mode`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L4-L41)、[`_start_daily`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L481)、[`_nav_back`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L371-L374)、[`_unhandled_input`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L344)
- **觸發條件**：
  - 路徑 A：`主畫面 → 開始對戰(hub_play) → 對戰大廳(lobby) → 開始對局（進入 St.PLACE，nav_stack 殘留 ["hub_play"]） → 點兵種卡「?」或按 F1 開圖鑑(codex) → 按畫面「返回」鈕或 Esc／手把 B`。
  - 路徑 B：`主畫面 → 挑戰(hub_challenge) → 殘局(puzzles)／試煉(trials)／每日(daily)／每週(weekly)／幽靈(ghosts) → 選關進入排兵(St.PLACE，nav_stack 殘留 ["hub_challenge"]) → 開圖鑑(codex)／陣型槽(slots)／殘局提示(puzzle_hint)／預排軍令(puzzle_plan) → 按 Esc／手把 B（圖鑑含畫面返回鈕）`。
- **後果**：`_draw_hub` 點擊任何卡片都會先執行 `_nav_push(kind)`，但只有 [`_begin_battle`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_core.gd#L142) 與 [`_go_title`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L29) 清空 `nav_stack`，進入 `St.PLACE` 時未清空。結果在排兵畫面關閉圖鑑或子覆蓋層時，`_nav_back()` 彈出 `"hub_play"` 或 `"hub_challenge"`，直接在排兵畫面上疊出標題畫面的卡片面板。

---

### 3. [高] M0 返回堆疊：正式對局戰鬥中「暫停選單 → 離開確認(`leave`) → 按 Esc／手把 B」會卡在無選單的暫停狀態
- **檔案與行號**：[`_click_pause_menu`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L640)、[`_click_overlay` (`leave_stay`)](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L344)、[`_unhandled_input`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L344)
- **觸發條件**：`正式對局戰鬥中（St.BATTLE, play_kind == "official"，如遠征第 2 站以上或三戰兩勝已拿勝場） → 按 Esc 開暫停選單（overlay = "pause_menu", paused = true） → 點「離開對局(pm_leave)」（設 overlay = "" 後 _request_leave 設 overlay = "leave"，未 push "pause_menu"） → 按 Esc 或手把 B`。
- **後果**：點畫面上的「留下 (`leave_stay`)」會判斷 `overlay = "pause_menu" if (state == St.BATTLE and paused) else ""` 回到暫停選單；但按 Esc／手把 B 卻走 `call("_nav_back")` 將 `overlay` 設為 `""`，且 `paused` 仍維持 `true`。正式對局沒有底部重播時間軸可按播放，畫面直接凍結在「無暫停選單的暫停狀態」（必須再按兩次 Esc 才能恢復）。

---

### 4. [高] A3 轉身出手格：`atk_face` 跨正負號線性插值導致「前搖前半段朝反方向揮空刀」與「`face = 0` 寬度歸零消失」，且 `ta_tex` 漏畫表情
- **檔案與行號**：[`draw_units_and_fx`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L718-L725)、[`_draw_xray`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L754)、[`draw_unit`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L399-L408)
- **觸發條件**：單位原本朝左（`f0 = -1.0`），突然對右側目標出手（`tgt_f = +1.0`），`battle_units.gd:724` 執行 `face = lerpf(f0, tgt_f, kf)`（歷時 `0.12` 秒）並覆蓋了 `_face_of(u)` 的最小寬度夾限（`TURN_MIN_W = 0.45`）。
- **後果**：
  1. **朝反方向揮武器**：在前 `0.06` 秒（超過 `2 tick = 0.10s` 前搖的一半時間），`lerpf(-1.0, +1.0, kf)` 仍為負值，[`sprite_cache.gd:401`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L401) 的 `sg := -1.0 if face < 0.0 else 1.0` 會讓單位背對目標朝左蓄力揮刀，跨過 `0.0` 瞬間才鏡像翻到右邊。
  2. **跨過 `0.0` 時寬度壓扁為 0**：因為覆蓋了 `_face_of(u)` 的夾限，當 `kf = 0.5` 時 `face == 0.0`。走即時向量繪製的單位（如巨像首領 `scale > 1.4`、開啟簡化介面 `plain_ui`、或烘焙完成前）以及密陣半透明補畫 [`_draw_xray`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L754) 的 `Transform2D` X 縮放 `scale * face` 變為 `0`，角色在該幀壓成一條線消失並觸發奇異矩陣。
  3. **`ta_tex` 漏畫 `mood` 疊加**：[`sprite_cache.gd:399-408`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L399-L408) 貼完 `ta_tex` 後直接 `return`，漏掉 `if mood != 0: Art.overlay(...)`（其他分支皆有畫）。

---

### 5. [中] A6 圖鑑烘焙：`CodexBake` 的兩個 `SubViewport` 設為 `UPDATE_ALWAYS` 且關閉圖鑑後永不停用，整場遊戲每幀背景重繪
- **檔案與行號**：[`_init`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L41-L48)、[`_cx_ensure_bake`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L639-L643)
- **觸發條件**：遊戲啟動後只要打開過一次圖鑑（觸發 `_cx_ensure_bake()` 建立 `CodexBake` 並 `add_child`），之後關閉圖鑑回到主畫面或進入大型戰鬥。
- **後果**：[`codex_bake.gd:41, 48`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L41-L48) 將兩個 `380×330` 的 `SubViewport`（含 25 次紋理取樣的 `unit_bake.gdshader`）設為 `SubViewport.UPDATE_ALWAYS`，且關閉圖鑑時既未改為 `UPDATE_DISABLED` 也未釋放節點，違反同檔第 3 行註解「只在圖鑑開著時用」，在戰鬥中每幀白白消耗 GPU／CPU。

---

### 6. [中] A5 圖鑑近看模式：點過「召喚物」分頁後 `cx_zoom` 狀態殘留；劍士點「特殊招式」傳錯 `variant` 無反應
- **檔案與行號**：[`_open_codex`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L52-L64)、[`_click_codex`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L75-L77)、[`_draw_cx_zoom`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L667-L695)、[`_sword`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L72-L78)
- **觸發條件**：
  1. 打開圖鑑 → 點頂部「召喚物 (`cxz_summons`)」分頁（自動設 `cx_zoom = true`，且因 `cx_unit >= D.total()` 隱藏 `cxz_close` 鈕）→ 按返回或 Esc 關閉圖鑑 → 在排兵畫面點任意一般兵種卡上的「`?`」呼叫 `_open_codex(t)`。
  2. 在圖鑑選「劍士 (`D.SWORD`, type 0)」→ 點「近看 (`cxz_open`)」→ 點「特殊招式 (`cxz_alt`)」。
- **後果**：
  1. `_open_codex(t)` 未重設 `cx_zoom = false`，導致之後點兵種卡「`?`」打開一般兵種時直接卡在近看模式，看不到兵種數值與克制頁。
  2. [`_draw_cx_zoom`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L694) 固定傳 `2 if cx_zalt else 0`，但劍士的上挑動作在 [`kingdom.gd:72`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L72) 判斷的是 `if variant == 1:`（對照 [`sprite_cache.gd:482`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L482) 為 `1 if type < D2.CLASSIC else 2`），傳 `2` 導致劍士切換「特殊招式」時仍只揮一般斬擊。

---

### 7. [中] M0 返回堆疊：游藝室子頁、車輪戰代碼頁、試玩版戰後返回等多處路徑「畫面返回鈕 vs Esc／手把 B」不一致或回錯頁
- **檔案與行號**：[`_click_playroom`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1272)、[`_click_wager`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1321)、[`_click_draft`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1445)、[`_code_auto_apply`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1103)、[`_click_overlay`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L338-L339)、[`_go_title`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L45)、[`_progress_restore`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L884)
- **觸發條件與後果**（完整路徑對照表詳見第二節）：
  1. `游藝室(playroom) → 競猜眼力(wager)／輪抽對決(draft)`：進入時直接設 `overlay = "wager"/"draft"` 未 `_nav_push("playroom")`；點畫面「返回」鈕回 `playroom`，但按 **Esc／手把 B** 走 `_nav_back()` 卻直跳主畫面（`overlay = ""`）。
  2. `代碼(codes) → 貼上 NTW1 車輪戰代碼點自動辨識 → wave_codes`：進入時未 `_nav_push("codes")`；點畫面「返回」鈕回 `codes`，按 **Esc／手把 B** 卻直跳主畫面；且點「第 N 波」觀看重播結束後直接回主畫面，不會回到 `wave_codes` 看下一波。
  3. `試玩版(_demo() == true) → 從 hub_play / hub_challenge 打完或離開對局 (_go_title)`：[`game_place.gd:45`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L45) 寫了 `if nav_hub != "" and not _demo(): overlay = nav_hub`，試玩版明明也有三個 hub 面板，卻被 `not _demo()` 擋掉而掉回主畫面。
  4. `設定(settings) → 資料分頁 → 還原備份確認(restore) → 點確認(_progress_restore)`：[`game_menus.gd:884`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L884) 設 `overlay = ""` 跳回主畫面，而非像清除資料（845 行）一樣回到 `"settings"`。

---

### 8. [中] B1b 重播與時間軸軍令標記：同刻雙軍令去重不一致、`watch_code` 殘留舊局標記、`_seek_begin` 預設延遲不一致
- **檔案與行號**：[`_cmd_event`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L418-L423)、[`_seek_begin` / `_seek_tick`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L119-L140)、[`watch_code`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L308-L329)
- **觸發條件**：
  1. 同一隊在同一 tick 施放兩招軍令（例如殘局第 12 章預排同刻雙招，或同 tick 連按兩鍵），分別以「正常播放」與「點時間軸快轉跳過（`_seek_to`）」觀看。
  2. 從代碼頁輸入 `NTB1`／`NTW1` 呼叫 `watch_code` 觀看重播。
  3. 在 `view == null` 時呼叫 `_seek_begin(target)`。
- **後果**：
  1. `_cmd_event` 去重條件為 `m["kind"] == "cmd" and int(m["tick"]) == view.tick and int(m["team"]) == tm`（未比對 `skill`），正常播放時同隊同 tick 第二招會被當成重複而吃掉；但 `_seek_tick` 完全沒去重會塞入 2 筆，造成快轉前後標記數量不一致。
  2. `watch_code` 只清空了 `battle_marks`，未清空或產生時間軸頂部繪製用的 `replay_marks`，導致觀看他人對戰碼時，時間軸上方仍顯示自己上一場對局的標記。
  3. `_seek_begin` 在 `view == null` 時 fallback 減去 `ViewBuffer.DELAY`（2），但 [`_seek_finish`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L150) 針對 `cmd_scripted` 新建的 `ViewBuffer` 其 `delay` 為 `DELAY_LONG`（8），之後 `_pump_view` 推進 8 tick 會比目標 `target` 多跑 6 tick。

---

### 9. [中] C4 全螢幕 10 秒確認框：按 Esc／手把 B 會直接關掉設定頁隱藏確認框，10 秒後在背景無預警切回原視窗
- **檔案與行號**：[`_toggle_fullscreen` / `_settings_tick`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L509-L520)、[`_draw_fs_confirm`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L621-L632)、[`_unhandled_input`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L325-L327)
- **觸發條件**：在設定頁切換全螢幕彈出 10 秒確認框（`fs_wait = 10.0`）期間，按鍵盤 **Esc** 或 **手把 B**。
- **後果**：[`game_screens.gd:325-327`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L325-L327) 只檢查 `if get("bind_wait") == "": call("_settings_close")`，未攔截 `fs_wait > 0.0`。按 Esc 會直接關閉設定頁（確認框因為畫在 `_draw_settings` 內而一併消失），但 `fs_wait` 計時器仍在背景倒數，10 秒後玩家在主畫面或排兵時視窗突然被強制還原。

---

### 10. [中] E2 母語校對包：`l10n_build.py` 日文欄優先序寫反，母語者對 `OVERRIDE` 內 27 個 key 的校對修正會被靜默覆蓋
- **檔案與行號**：[`main`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_build.py#L113)、[`var_set`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_review.py#L40)
- **觸發條件**：
  1. 執行 `l10n_review.py export` 匯出 `review_ja.csv`，母語譯者修改了屬於 `OVERRIDE` 的 27 個日文條目（如 `sd_set_lang`、`pr_wager_d`、`pr_draft_d`、`rv_hint` 等，見 [`l10n_build.py:21-39`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_build.py#L21-L39)），經 `l10n_review.py import` 寫入 `ja_zz_review.json`，再執行 `l10n_build.py` 產出 `translations.csv`。
  2. 譯者校對含有 `%+d`、`%.1f` 等帶修飾符佔位符的字串。
- **後果**：
  1. [`l10n_build.py:113`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_build.py#L113) 簡中寫的是 `zr.get(k) or OVERRIDE.get(("zh_CN", k), ...)`（校對優先），但日文卻寫成 `OVERRIDE.get(("ja", k)) or jp(...)`（硬編碼 `OVERRIDE` 優先於讀取 `ja_zz_review.json` 的 `jp()`），導致這 27 條日文即便匯入了母語校對結果也完全不會生效。
  2. [`l10n_review.py:40`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_review.py#L40) 的 `var_set` 只用 `r"%[ds%]"` 檢查，與 [`l10n_build.py:42`](file:///mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_build.py#L42) 的 `r"%[-+0-9.]*[sdf]|\{[A-Z0-9_]+\}"` 不一致，漏驗 `%+d`／`%.1f`／`{VAR}`。

---

### 11. [低] A0 角色背面繪製：寶箱怪背面箱蓋懸空破圖、騎兵背面馬頭未鏡像仍朝右伸出
- **檔案與行號**：[`_f_mimic`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L99-L132)、[`_cavalry`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L370-L376)
- **觸發條件**：
  1. 寶箱怪（`D.MIMIC`, type 12）背對鏡頭（`back == true, turn_s > 0.04`）或於圖鑑近看模式拖曳看背面。
  2. 騎兵（`D.CAVALRY`, type 3）背對鏡頭。
- **後果**：
  1. **寶箱怪箱蓋懸空**：`if not back:` 跳過了深色口腔底色（`#3b0f1e`）、舌頭與牙齒，但箱蓋高度 `ly = mouth - 4 - open * 12` 仍維持張嘴狀態（`open >= 0.45`），導致箱蓋與箱身之間露出一大截透明背景空洞，背面兩枚金鉸鏈也跨越空洞懸在半空。
  2. **騎兵馬頭穿幫**：背面僅將 `_horse_head` 改在馬身橢圓之前繪製，未調整馬頭 X 座標（`x = 17..28` 遠超出馬身 `rx = 16`），整顆馬脖子與馬頭仍從右側完整伸出。

---

### 12. [低] B1b 軍令欄冷卻遮罩：開戰前 3 秒準備期（`START_TICKS = 60`）分母誤用 `sim.cmd_cd`
- **檔案與行號**：[`_draw_cmd_bar`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L475-L478)
- **觸發條件**：開啟軍令且自訂規則將軍令冷卻 `cmd_cd` 設為非 3 秒（例如 5 秒 = `100` ticks 或 8 秒 = `160` ticks），於開戰前 3 秒（`tick = 0..59`，此時 `c_ready == CmdD.START_TICKS == 60`）觀察左下角軍令欄。
- **後果**：第 477 行固定用 `clampf(float(wait) / maxf(1.0, float(sim.cmd_cd)), 0.0, 1.0)` 計算遮罩高度比例，當 `cmd_cd = 160` 時，開戰第 0 秒冷卻遮罩只蓋住 `60 / 160 = 37.5%`（而非滿格 100% 倒數）。

---

## 二、重點 1（M0 返回堆疊）問題路徑總表

| 具體操作路徑（從哪開 → 按什麼） | 目前實際去向 | 預期去向 | 根因（檔案:行號） |
| :--- | :--- | :--- | :--- |
| `主畫面 → 開始對戰(hub_play) → 對戰大廳(lobby) → 開始對局(進入 St.PLACE) → 點兵種卡「?」或按 F1 開圖鑑(codex) → 按畫面「返回」鈕或 Esc／手把 B` | 在排兵畫面上彈出 **`hub_play`（開始對戰面板）** | 關閉圖鑑回到 **`St.PLACE` 排兵畫面**（`overlay = ""`） | [`game_menus.gd:1179`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1179) 壓入 `"hub_play"`，但 [`_start_mode`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L4) 進入 `St.PLACE` 未清空 `nav_stack` |
| `主畫面 → 挑戰(hub_challenge) → 殘局／試煉／每日／每週／幽靈 → 選關進入排兵(St.PLACE) → 開陣型槽(slots)／提示(puzzle_hint)／預排軍令(puzzle_plan) → 按 Esc／手把 B` | 在排兵畫面上彈出 **`hub_challenge`（挑戰面板）**（點畫面返回鈕雖回排兵，但 `nav_stack` 仍殘留 `"hub_challenge"`） | 關閉子覆蓋層回到 **`St.PLACE` 排兵畫面**（`overlay = ""`） | 同上，[`_start_mode`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L4) 與 [`_start_daily`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L481) 未 `nav_stack.clear()` |
| `正式對局戰鬥中(St.BATTLE) → 按 Esc 開暫停選單(pause_menu) → 點「離開對局(pm_leave)」彈出確認框(leave) → 按 Esc／手把 B` | `overlay = ""` 但 **`paused` 仍為 `true`**（畫面卡死在無選單暫停狀態；點畫面「留下」則回 `pause_menu`） | 回到 **`pause_menu`（暫停選單）** | [`game_menus.gd:640`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L640) 先清 `overlay = ""` 再開 `"leave"`，且 [`game_screens.gd:344`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L344) 走 `_nav_back()` 未還原 `pause_menu` |
| `主畫面 → 游藝室(playroom) → 點「競猜眼力(wager)」或「輪抽對決(draft)」 → 按 Esc／手把 B` | 直接跳回 **主畫面（`overlay = ""`）**（點畫面「返回」鈕則回 `playroom`） | 回到 **`playroom`（游藝室）** | [`game_modes.gd:1272, 1384`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1272) 直接設 `overlay` 未呼叫 `_open()` 或 `_nav_push("playroom")` |
| `主畫面 → 代碼(codes) → 貼上 NTW1 點「自動辨識(code_auto)」進入 wave_codes → 按 Esc／手把 B` | 直接跳回 **主畫面（`overlay = ""`）**（點畫面「返回」鈕則回 `codes`） | 回到 **`codes`（代碼頁）** | [`game_menus.gd:1103`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1103) 直接設 `overlay = "wave_codes"` 未 `_nav_push("codes")` |
| `試玩版(_demo() == true) → 開始對戰(hub_play)／挑戰(hub_challenge) → 進入任一模式後離開或打完回標題(_go_title)` | 掉回 **主畫面（`overlay = ""`）** | 回到 **`nav_hub`（`hub_play` 或 `hub_challenge`）** | [`game_place.gd:45`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L45) 多寫了 `and not _demo()` |
| `設定(settings) → 資料分頁 → 點「還原上一份備份」彈出確認(restore) → 點「確認還原」` | 直接跳回 **主畫面（`overlay = ""`）** | 回到 **`settings`（設定頁）**（與清除資料確認一致） | [`game_menus.gd:884`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L884) 設 `overlay = ""` 而非 `"settings"` |

---

## 三、[ledger.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md) 各條「Ruling」表態與理由

1. **[M0 返回堆疊 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L16)**
   - **表態**：**部分同意（架構同意，實作有漏洞需修）**
   - **理由**：在 `ui_base.gd` 以 `nav_stack`＋`nav_hub` 統一二级面板返回與戰後回面板，並保留 `settings_ret`／`pt_back` 的設計簡潔合理；但實作漏在 `_start_mode`／`_start_daily` 進入 `St.PLACE` 時清空 `nav_stack`，且 `playroom` 子頁、`wave_codes`、戰鬥暫停的 `leave` 與試玩版 `_go_title` 未對齊，導致上述問題 2、3、7。

2. **[M0 戰績兵種勝率 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L23)**
   - **表態**：**不同意目前實作（欄位拆分方向同意，但計數邏輯錯誤）**
   - **理由**：保留 `unit_wins` 給圖鑑老兵筆記、另立 `unit_games_rec`／`unit_wins_rec` 並在存檔過渡期標註「從 V1.5.1 起算」的設計完全正確；但 `_record_match` 把敵方 `armies[1]` 也算進 `unit_games_rec` 與 `unit_wins_rec`，且未過濾 `Presets.BADGE_LAB`（沙盒）與各挑戰子模式（問題 1），反而讓勝率失真更嚴重。應在非雙人模式只統計 `armies[0]`（玩家隊伍，僅 `w == 0` 記勝），並與 `_progress_and_achievements` 共用同一組模式與徽章過濾條件。

3. **[A0 角色背面補齊 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L30)**
   - **表態**：**部分同意（20 種兵種合理，寶箱怪與騎兵需修）**
   - **理由**：將 `BACK_OK` 擴為 22 種並替投彈兵、醫者、綿羊、幽靈、詛咒娃娃、沙漏法師、骷髏法師、骷髏兵補齊背面特徵的作法符合方案；但寶箱怪背面漏把箱蓋 `open` 歸零導致箱蓋懸空破圖，騎兵背面僅調換繪製順序而未內收或鏡像馬頭 X 座標（問題 11）。

4. **[A3 轉身途中出手格 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L37)**
   - **表態**：**不同意目前 `atk_face` 插值實作（LRU 快取架構同意，朝向插值需修）**
   - **理由**：`sprite_cache.gd` 只烘本場出場兵種並以 `TA_MAX = 12` LRU 控制在約 27 MiB 內的設計非常穩健；但 `battle_units.gd` 直接對正負相反的 `f0` 與 `tgt_f` 做 0.12 秒線性插值並覆蓋最小寬度夾限，造成前搖前半段朝反方向揮刀與跨過 `0.0` 時寬度變 0，且 `ta_tex` 漏畫 `mood`（問題 4）。反方向出手時應直接從與 `tgt_f` 同號的側面（如 `tgt_f * TA_C`）插值到 `tgt_f`，使整段前搖都朝向目標且不跨過 `0.0`。

5. **[A5+A6 圖鑑近看模式、烘焙一致化、召喚物分頁 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L44)**
   - **表態**：**部分同意（功能與視覺一致化同意，SubViewport 生命週期與狀態需修）**
   - **理由**：以 `codex_bake.gd` 兩段 `SubViewport` 套用 `unit_bake.gdshader` 徹底解決了圖鑑轉身／出手掉外框的問題，近看控制列與召喚物分頁也很完整；但必須修正關閉圖鑑後 `SubViewport` 仍 `UPDATE_ALWAYS` 背景重繪（問題 5），以及 `_open_codex` 未重設 `cx_zoom = false`、劍士特殊招式 `variant` 傳錯（問題 6）。

6. **[B1+B1b 手動軍令局遠程飛行、重播與軍令欄同步 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L51)**
   - **表態**：**部分同意（`proj_wind` 與 `DELAY_LONG`＋`cmd_snap` 架構同意，細節需補）**
   - **理由**：短緩衝縮前搖 1 tick 讓出飛行時間，以及 `cmd_scripted` 改用 `DELAY_LONG = 8` 並以 `cmd_snap` 同步軍令欄，精準解決了飛行瞬間命中與重播軍令欄提早跳字；只需補齊 `_cmd_event` 去重納入 `skill`、`watch_code` 更新 `replay_marks`、`_seek_begin` fallback 延遲（問題 8）與開戰前 3 秒冷卻分母（問題 12）。

7. **[C1～C4 設定四項 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L58)**
   - **表態**：**部分同意（C1／C2／C3 同意，C4 全螢幕確認需攔截 Esc）**
   - **理由**：`DEFAULT_SETTINGS` 對齊 `25`/`50`、恢復本頁預設重同步顯示、預設組合預覽文字、以及 `tap` 模式非直線不隨拖曳延伸皆正確落實；但全螢幕 10 秒確認框開啟時按 Esc／手把 B 會直接關掉設定頁而未還原或攔截（問題 9）。

8. **[D1+D2 代碼自動辨識、車輪戰整包代碼 NTW1 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L65)**
   - **表態**：**部分同意（`NTW1` 編解碼與 `detect` 同意，`wave_codes` 導覽需接堆疊）**
   - **理由**：`NTW1` 打包三波種子與陣型以及 `BattleCode.detect` 自動分流實作乾淨且具向下相容性；但從 `codes` 進 `wave_codes` 未 `_nav_push("codes")`，造成 Esc 與返回鈕去向不一致（問題 7）。

9. **[E1+E2 試玩回報匯出、母語校對包工具 Ruling](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-impl/ledger.md#L72)**
   - **表態**：**部分同意（E1 白名單匯出同意，E2 `l10n_build.py` 日文優先序需修）**
   - **理由**：`Save.playtest_report` 嚴格限制 `PT_FIELDS` 白名單，無洩漏個資與路徑風險；但 `l10n_build.py` 日文欄把 `OVERRIDE` 放在 `jp()` 之前，導致 `OVERRIDE` 內 27 個日文條目的母語校對匯入後被蓋掉，且 `l10n_review.py` 佔位符正規表示式未對齊（問題 10）。
