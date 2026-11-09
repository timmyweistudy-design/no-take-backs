### 1. 第 2 輪「已修」項目逐條驗證

1. **轉身出手朝向（[`battle_units.gd:720-730`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L720-L730)）**
   - **已修好，無新問題**。反向出手自第 1 格起即取 `tgt_f` 方向並以 `0.45` 寬度走轉身攻擊格（[`sprite_cache.gd:407-419`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L407-L419)），過半（`kf >= 0.5`）再平滑回到正側面；同方向未滿側面者則直接從原寬度插值至 `tgt_f`，不再出現前半朝舊方向蓄力的問題。
2. **開戰準備期冷卻遮罩（[`battle_view.gd:475-479`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L475-L479)）**
   - **已修好，無新問題**。在 [`_draw_cmd_bar()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L445-L480) 中，`phase_len` 依 `c_ready <= CmdD.START_TICKS` 固定區分為開戰準備期總長 `START_TICKS`（60 tick）與施放後冷卻 `sim.cmd_cd`，開場遮罩由 100% 線性遞減至 0%，不再因 `cmd_cd` 與準備期長短差異而跳變。
3. **重播跳轉倒地與小旗重建、代碼觀戰清除刻度（[`replay_view.gd:164-171`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L164-L171)、[`replay_view.gd:322-324`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L322-L324)）**
   - **已修好，無新問題**。[`_seek_finish()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L150-L203) 對 `0.0 <= age < 1.0` 的陣亡單位重建 `dying`（保留當前 `t = age`），恢復播放跨過 1.0 秒時由 [`_process_inner()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L507-L512) 自然銜接生成 `graves` 小旗；[`watch_code()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L322-L338) 入口亦已清空 `replay_marks`。
4. **格子與自由排兵「只點選」點一下拿掉（[`game_screens.gd:273-286`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L273-L286)、[`free_place.gd:332-374`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L332-L374)）**
   - **已修好，無新問題**。格子排兵 [`_mb_cmd()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L233-L299) 記錄 `drag_press_p`、自由排兵 [`_fp_press()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L324-L343)／[`_fp_release()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd#L346-L399) 記錄 `fp_press_p`（手把 A 亦共用同一套座標），皆在放開距離 `< 10.0` 時才觸發撤兵並推入 `fp_undo`，不會因微偏中心而誤搬移，並有 [`test_free_tap_remove_v151()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd#L1317-L1358) 覆蓋。
5. **著色器 `y_off` 對戰場圖集影響與圖鑑烘焙（[`unit_bake.gdshader:13, 30`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/shaders/unit_bake.gdshader#L13-L30)、[`codex_bake.gd:78-82`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L78-L82)）**
   - **已修好，對戰場圖集完全無影響**。`y_off` 預設為 `-1.0`，戰場圖集烘焙 [`_post()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L272-L292) 不設 `y_off`，因此 `y_off >= 0.0` 為假，100% 走原本的 `mod(px.y, cell) / cell`。圖鑑 [`set_params()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd#L68-L83) 以 `k = scale / 1.6` 同步設定 `cell = 192.0 * k` 與 `y_off = FEET.y - 160.0 * k`（恒 `>= 0`），使圖鑑一般立繪與近看縮放的 `ly` 分布與戰場圖集完全一致。
6. **確認框、全螢幕確認與進度還原回原頁（[`game_menus.gd:490-544`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L490-L544)、[`game_menus.gd:745, 828, 908`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L745)）**
   - **已修好，無新問題**。[`_apply_preset()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L733-L745)、[`_settings_import()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L804-L828)、[`_fs_change()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L490-L497) 與 [`_guard_fs()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L538-L544) 皆保留當前 `overlay`（如 `"first_run"`、`"codes"`）作為返回目標；[`_progress_restore()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L890-L910) 還原成功後亦留在 `"settings"`；試玩版戰後回主畫面 [`_go_title()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L45-L46) 亦正常回到 `nav_hub`。

---

### 2. 必修問題

**無（0 條）**。本輪靜態審查未發現會導致錯誤、資料損失或畫面明顯錯誤的新問題或殘留問題。

---

### 3. 對剩下 Ruling 的表態

- **A4（3/4 角雙手武器前後手畫序不另做）**：**同意**。背面已由深度互換處理，且現有圖鑑支援 16 角度逐格與近看檢視，留作人工檢視若有穿插再個別微調即可，無須為此阻擋收尾。
- **挑戰局（試煉、每日、每週、幽靈、車輪戰、輪抽）照算連勝與兵種勝率**：**同意**。[`_record_match()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L879-L916) 已排除實驗室沙盒局並確保 `unit_games_rec` 與 `unit_wins_rec` 分子分母同口徑，符合方案 §0.2 要求。
- **C4（時間軸「選軍令再點時間」延後）**：**同意**。其實 [`_draw_plan_timeline()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L886-L900) 現有實作已支援點選木棋子選取（`plan_sel`）再點刻度尺下半部移過去，並有 `◀`／`▶` 微調鈕，操作已足夠順暢，不需重做時間軸互動。
- **C7（設定頁進階收合不做）**：**同意**。設定頁分頁後每頁最多 8 列（底端 `y = 634`），四語三字級皆不需捲動即可完整顯示，直接攤開比收合更好找。

---

### 4. 結論

同意收尾
