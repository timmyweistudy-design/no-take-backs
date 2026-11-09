以下為《落子無悔》V1.5.0 第二輪實作唯讀審查結果（依嚴重度由高至低排列，共 9 條實際問題），以及對 [`ledger.md`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-impl/ledger.md)「裁決」項目的逐條表態。

---

### 一、實際問題清單（依嚴重度排序）

1. **[高] 設定頁「一般」分頁第 8 列按鈕與底欄「製作人員／返回」按鈕垂直重疊 14px，點「返回」上半部會誤開塗裝室**
   - **位置**：[`game_menus.gd:466-474`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L466-L474)、[`game_menus.gd:557-594`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L557-L594)、[`game_menus.gd:698-707`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L698-L707)
   - **觸發條件**：打開「設定」切到第 1 個分頁「一般」（`settings_tab == 0`，共 8 列），檢視或點擊右下角「開啟塗裝室」與底欄「製作人員」、「返回」按鈕。
   - **後果**：[`_settings_row_y()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L698-L707) 對第 7 索引列（`set_paint`）算出的 `ry` 為 `272 + 46 + 50 * 6 = 618.0`，按鈕區域為 `Rect2(790, 618, 220, 42)`（`y = 618..660`）；而底欄按鈕 `by = R.end.y - 54 = 646`，「製作人員」（`x = 660..830, y = 646..690`）與「返回」（`x = 840..1010, y = 646..690`）和「開啟塗裝室」在 `x = 790..1010, y = 646..660` 重疊了 14px。因 `set_paint` 先推入 `_btns`，點擊「返回」或「製作人員」上緣會直接跳進塗裝室。

2. **[高] `_pump_view()` 僅排除 `EV.BONK`，導致投彈手濺射（`EV.SPLASH`）覆蓋炸彈飛行目標、同 tick 塞爆 `atk_hit`，且醫者近戰（`EV.HIT`）會射出補血球**
   - **位置**：[`battle_view.gd:214-224`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L214-L224)、[`battle_state.gd:97-115`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L115)、[`battle_sim.gd:679-684`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd#L679-L684)
   - **觸發條件**：
     1. 投彈手丟出火罐（`EV.BOMB`）並波及周圍敵兵（同 tick 產生 `EV.SPLASH`）。
     2. 場上只剩支援兵時，醫者以近戰敲擊敵兵（產生 `EV.HIT`）。
   - **後果**：
     1. `EV.SPLASH` 的 `event_route(e)` 同為 `"attack"` 且 `e["kind"] != EV.BONK`，後處理的 `EV.SPLASH` 會執行 `bt[int(fr["tick"])] = int(e["tgt"])` 覆蓋掉同 tick `EV.BOMB` 的主目標，使飛行中的炸彈飛向最後一隻被波及的副目標，但命中爆炸特效 `_burst`（[`battle_view.gd:556`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L556)）卻爆在主目標身上；同時每隻波及對象都會對 `atk_hit` 重複 `append` 相同 tick，且 `proj_tgt` 長度上限仍為 `6`（第 223 行）而非 `8`。
     2. 醫者近戰 `EV.HIT` 也會寫入 `proj_tgt`，導致 [`proj_phase()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L115) 將近戰揮杖當作遠程補血回推 4 tick，並朝受擊敵兵發射綠色補血飛行物。

3. **[高] 戰鬥中從暫停選單點「離開本局」，彈出離開確認框時已先解除暫停，背景戰鬥繼續偷跑甚至直接結算**
   - **位置**：[`game_menus.gd:546`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L546)、[`game_place.gd:14-21`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L14-L21)、[`battle_view.gd:74`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L74)
   - **觸發條件**：在有進度風險的對局戰鬥中（`St.BATTLE`，如遠征第 2 關以後、或系列賽已拿過勝場），按 `Esc` 開啟 `pause_menu` 後點「離開本局」。
   - **後果**：第 546 行先執行 `overlay = ""; paused = false; _request_leave()`。當 [`_leave_at_risk()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L7-L12) 為真時，[`_request_leave()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L14-L21) 打開 `overlay = "leave"` 確認框，但 `paused` 已被設為 `false`。玩家在閱讀確認框期間，背景戰鬥仍持續推進，甚至會在確認框尚未關閉前打完並跳進 `St.RESULT`（結算畫面上仍蓋著離開確認框）。

4. **[高] 暫停選單進「設定」再開啟子彈窗時，按 `Esc`／手把 `B` 會直接清空 `overlay`，造成戰場卡在無選單暫停且 `settings_ret` 殘留污染標題畫面**
   - **位置**：[`game_menus.gd:488-490`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L488-L490)、[`game_menus.gd:528-545`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L528-L545)、[`game_menus.gd:592-600`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L592-L600)、[`game_screens.gd:327-337`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L327-L337)
   - **觸發條件**：對局中從 `pause_menu` 點「設定」（設 `paused = true`、`settings_ret = "pause_menu"`），再點「操作與快捷鍵」（`keys`）、「製作人員」（`credits`）、「從備份還原」（`restore`）或「清除所有進度」（`clear_data`），接著按鍵盤 `Esc` 或手把 `B`。
   - **後果**：
     1. [`game_screens.gd:336`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L336) 的 `elif overlay != "": overlay = ""` 直接把 `overlay` 清為 `""` 而不退回 `"settings"`。在 `St.BATTLE` 下會導致畫面無任何選單卻維持 `paused == true`（且若曾改過設定也繞過了 `_settings_close()` 的未儲存確認）。
     2. 因 [`_open("settings")`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L528-L536) 未重置 `settings_ret`，殘留的 `settings_ret = "pause_menu"` 會在之後回到標題畫面（`St.TITLE`）開關設定時，讓 [`_settings_close()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L600) 在標題畫面上彈出對局暫停選單。

5. **[高] 進度還原與清除資料未檢查 `Save.save_data()` 結果、未解除 `Save.data_locked`、未重套塗裝快取，且滿 10 筆或同秒備份時會誤刪／覆蓋備份**
   - **位置**：[`game_menus.gd:710-747`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L710-L747)、[`game_menus.gd:782-801`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L782-L801)、[`save.gd:411-425`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L411-L425)
   - **觸發條件**：
     1. 曾因較新 `schema_version` 觸發 `Save.data_locked = true` 後執行「從備份還原」或「清除所有進度」，或磁碟寫入失敗。
     2. 備份滿 10 筆時點選最舊的第 10 筆還原，或同一秒內連續觸發備份與還原／清除。
     3. 修改塗裝後執行還原或清除資料。
   - **後果**：
     1. [`_progress_restore()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L734-L747) 與 [`_clear_data()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L782-L801) 未重置 `Save.data_locked = false`，使 [`Save.save_data()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L421) 直接略過寫檔；且兩處皆未檢查 `Save.save_data()` 回傳值即顯示成功 toast（第一輪 Codex #1 指出之未檢查寫檔結果仍存在）。
     2. [`_progress_backup()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L714-L727) 檔名只精確到秒，同秒內第二次備份會覆蓋前檔；且在 `Save.save_data()` 落盤前就先 `remove_absolute` 刪掉超過 10 筆的最舊檔。
     3. 還原／清除後未呼叫 `_paint_apply()` 與 `_rebuild_sprites()`，小人與旗幟配色仍維持舊狀態。

6. **[中] 大廳「我的預設」超過 5 組時，雙欄下拉選單左欄與底層「展開規則設定」按鈕重疊，點擊左欄會穿透觸發底層按鈕**
   - **位置**：[`lobby_view.gd:488-509`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L488-L509)、[`lobby_view.gd:532-549`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L532-L549)、[`game_screens.gd:749-760`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L749-L760)
   - **觸發條件**：在對戰大廳展開詳細規則（`lobby_open == true`），當已儲存 6～10 組預設時點開「我的預設 ▾」，點擊左欄（第 1～5 組預設或刪除鈕）。
   - **後果**：`ps.size() > 5` 時選單左移至 `x = 730..1222, y = 186..448`，左欄與底層 [`_draw_lobby_detail()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L649-L666) 左區 `L0`（`x = 250..850`，含各列數值調整鈕 `▶` `x = 788..840`、兵種池、實驗室與軍令按鈕）重疊。因底層按鈕先加入 `_btns` 且 [`_do_click()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L749-L756) 由前往後取第一個命中項執行，點選左欄預設會誤觸底下的規則按鈕而點不到選單。

7. **[中] 觀戰競猜直接複用 `"replay"` 模式，戰鬥中按返回／`Esc` 可無損逃逸保連勝（刷 `SHARP_EYE` 成就），且底欄重播列直接劇透全場戰力走勢**
   - **位置**：[`game_modes.gd:1301-1303`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1301-L1303)、[`replay_view.gd:235-237`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L235-L237)、[`replay_view.gd:319-320`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L319-L320)、[`battle_view.gd:712-717`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L712-L717)
   - **觸發條件**：在「觀戰競猜」押注開戰後，於結算前點右上角「返回」或按 `Esc`；或直接查看／拖動底部的重播控制列。
   - **後果**：[`_wager_go()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1301-L1303) 呼叫 `watch_code` 將 `play_kind` 設為 `"replay"`、`watch_mode = true`。戰鬥中按返回／`Esc` 會走 [`_replay_back()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L235-L237) → [`_go_title()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_core.gd#L353) 直接將 `wg_active = false` 而不結算敗場，玩家看到押錯即可中斷保住 `eye["streak"]` 輕鬆取得 V1.5 新成就 `SHARP_EYE`；且底欄重播時間軸一開始就畫出完整 `sim.power_log` 戰力曲線與跳至結尾鈕。

8. **[中] 提示時間設為「手動關」（`toast_mult == 0`）時，滑鼠左鍵放開會瞬間消掉按下時剛觸發的提示；手把／鍵盤玩家則完全無法關閉提示**
   - **位置**：[`game_screens.gd:237-294`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L237-L294)、[`game_screens.gd:744-746`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L744-L746)、[`ui_base.gd:438-440`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L438-L440)
   - **觸發條件**：將「提示訊息時間」設為「手動關」（或套用「低操作負擔」預設）：
     1. 排兵時用滑鼠左鍵點擊非法格子或鎖定兵種（`mb.pressed` 下壓時呼叫 `_toast` 設 `toast_t = 600.0`），隨即放開左鍵（`mb.pressed == false`）。
     2. 純手把或鍵盤操作下觸發任何 `_toast`。
   - **後果**：
     1. 滑鼠左鍵放開時進入 [`_do_click()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L744-L746)，立即把剛在 `pressed` 階段設為 `600.0` 的 `toast_t` 改成 `0.4`，導致錯誤提示在放開滑鼠後 0.4 秒即消失（比預設 2 秒還短）。
     2. 手把與鍵盤輸入不經過 `_do_click()`，一旦跳出提示就會在畫面上停留整整 600 秒無法按鍵收起。

9. **[低] 圖鑑 8 方向轉盤切到左側角度（135°、180°、225°）時，小人面向左方出手，但飛行物仍從右側生成並往右飛**
   - **位置**：[`codex_view.gd:40-41`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L40-L41)、[`codex_view.gd:364-375`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L364-L375)
   - **觸發條件**：在圖鑑選取弓箭手、投彈兵或醫者，點選方向轉盤左半側角度（`cx_dir` 為 3、4、5，此時 `cx_face = -1.0`）。
   - **後果**：第 368 行繪製小人已依 `cx_face` 翻轉為面向左方，但第 374 行繪製出手飛行物時仍寫死 `proj_launch(codex_sel, 1.0)` 與右側終點 `u_pos + Vector2(92, ...)`，造成小人朝左拉弓／投擲，箭矢與火罐卻從背後往右飛。

---

### 二、對 [`ledger.md`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-impl/ledger.md)「裁決」逐條表態

1. **Codex #2（確認框期間背景 timer／連點）**
   - **表態**：**不同意**
   - **理由**：「確認框不在對局進行中出現」的前提不成立。對局進行中（`St.PLACE`／`St.BATTLE`）可由 `pause_menu` 進入「設定」，觸發放棄未存設定的 `_ask_confirm`（`overlay = "confirm"`）、還原備份（`overlay = "restore"`）或清除資料（`overlay = "clear_data"`）；且由 `pause_menu` 點「離開本局」觸發 `overlay = "leave"` 時因先把 `paused` 設回 `false`（見上方問題 #3），背景戰鬥與雙人輪流落子計時器確實會在確認框期間繼續跑。

2. **Codex #3（設定頁取消仍寫入：改為按返回／Esc 時一次寫檔與套用視窗）**
   - **表態**：**同意**
   - **理由**：以 `settings_snap` 記錄進入設定前的快照，`settings_dirty` 時透過 [`_ask_confirm()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L604-L608) 確認後才由 [`_apply_all_settings()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L619-L632) 一次呼叫 `Save.save_settings()` 與套用語言／視窗，放棄則還原快照並重套音量，能有效避免頻繁切換視窗模式與重複寫檔（惟需補齊子彈窗按 `Esc` 退回 `"settings"`，見問題 #4）。

3. **Codex #6／AGY #7（鼓手側身鼓面朝向：維持現狀）**
   - **表態**：**同意**
   - **理由**：檢視 `docs/review/v150/units/units_sheet.png` 中鼓手四態，大鼓斜掛於身側、雙槌擊鼓動作在實際戰場縮放比例下清晰易辨，重排繪圖層級的風險高於視覺收益。

4. **AGY #3（`proj_phase` 只看最後一筆：改用 `pick_hit`）**
   - **表態**：**同意**
   - **理由**：[`proj_phase()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L115) 改為將命中時刻回推 `fly` 後交由 `pick_hit` 選出當前動作對應的發射事件，並回傳 `[出手 tick, 命中 tick, k]` 讓呼叫端用命中 tick 查 `proj_tgt`，已解決第一輪只看 `hits[-1]` 造成連發覆蓋的問題（只需在 `_pump_view` 過濾掉非投射物事件 `EV.SPLASH`／`EV.HIT`，見問題 #2）。

5. **AGY #5（按鈕最小間距 2px：維持）**
   - **表態**：**同意**
   - **理由**：2px 屬於多語系長字串下的自動化版面檢查容差下限，實際按鈕並無重疊壓字（設定頁「一般」分頁的重疊另有原因，見問題 #1）。

6. **AGY #6（殘局／試煉結果頁無再來一局：維持既有「下一關／重試」流程）**
   - **表態**：**同意**
   - **理由**：[`game_result.gd:261-265`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd#L261-L265) 在殘局與試煉模式提供專屬的「下一關／再試一次／看重播／選關」四鈕，比對戰模式的「同陣再戰／回大廳」更貼合闖關流程。

7. **AGY #8（狂戰士雙斧對稱：維持）**
   - **表態**：**同意**
   - **理由**：檢視 `units_sheet.png` 狂戰士四態，[`_berserk_axe()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L371-L382) 雙持戰斧隨前後手揮動錯開角度，造型對稱合理且剪影清楚。

8. **AGY #9（骷髏兵打擊幀頭骨旋轉：屬誇張卡通動態，維持）**
   - **表態**：**同意**
   - **理由**：檢視 `units_sheet.png` 骷髏兵 `strike` 幀，頭骨前傾約 14° 搭配下顎張開與骨棒揮擊，視覺上呈現用力猛砸的卡通動態，並無破圖或脫節。

9. **AGY #10（弓手箭袋角度：維持）**
   - **表態**：**同意**
   - **理由**：檢視 `units_sheet.png` 弓箭手四態，背後箭袋與三支箭羽自肩後探出、不遮擋臉部與拉弓手勢，辨識度良好。

10. **AGY #12（成就雙語陣列：簡中／日文有轉碼表，維持既有結構）**
    - **表態**：**同意**
    - **理由**：[`strings.gd:28-53`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/strings.gd#L28-L53) 的 `L.pick_for()` 會以繁中原文為鍵查詢 [`l10n_extra.csv`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/data/l10n_extra.csv#L26-L63)，且 V1.5 新增的 7 個成就名稱與條件說明均已完整增補至 `l10n_extra.csv` 的 `zh_CN` 與 `ja` 欄，四語顯示正常。
