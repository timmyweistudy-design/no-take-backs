### 1. B1 手動軍令局遠程同步：(甲) vs (乙) 風險對照與選擇

對照實際程式：
- [`view_buffer.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L8-L75)：`DELAY := 2`（100ms）、`DELAY_LONG := 8`（400ms）；`reset()` 只要 `bool(sim.get("cmd_on"))` 為真就設 `delay = 2`。
- [`battle_state.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L138)：[`proj_phase`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L101) 以 `fly = maxi(0, mini(proj_fly(type), delay - ViewBuffer.DELAY))` 算飛行 tick，故 `delay == 2` 時 `fly == 0`；[`atk_timing`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L117-L120) 與 [`atk_progress`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L123-L127) 寫死 `float(ViewBuffer.DELAY)`（2.0 tick 前搖）。
- [`battle_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L377-L469)：[`_cmd_press`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L377-L389) 呼叫 `sim.cast(team, skill)`，排入 `sim.tick + 1`（即 `view.tick + delay + 1`）結算；但 [`_draw_cmd_bar`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L448-L466) 的可用狀態、剩餘次數與冷卻秒數（`sim.cmd_ready[tm][s] - sim.tick`）卻**直接讀領先 `delay` tick 的 `sim`**，而橫幅、法陣、隕石與時間軸標記 [`_cmd_event`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L409-L439) 則在 `view` 播到該 tick 時才觸發。

#### 方案風險對照
- **(乙) 改 `delay = 4`＋前搖 1／飛行 3＋0ms 預回饋（高風險，不建議）**：
  1. **軍令手感與視覺穿幫**：玩家在畫面 `view.tick = T` 按下時，`sim` 已在 `T + 4`，實際結算在 `T + 5`（250ms 後）。若在 `T` 播 0ms 預回饋（法陣/隕石/音效），畫面單位仍在 `T` 的舊位置，250ms 後 `T + 5` 的 `CMD_HIT` 跳字與冰凍才生效，造成「特效先爆、0.25 秒後才扣血」或重複觸發。
  2. **時間軸與重播跳轉不一致**：`sim.cmd_log` 記錄的是 `T + 5`。重播/時光機 [`_seek_battle`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L194-L246) 重跑 `sim` 時只認 `T + 5`，導致對局中 0ms 看到的施放時點與戰後重播、時間軸刻度差 0.25 秒。
  3. **第 12 章殘局軍令連鎖時序錯位**：第 12 章（[`puzzles.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/puzzles.gd#L153-L217)）與軍令局重播同樣開啟 `sim.cmd_on = true`（[`battle_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L369-L375)）。若 `delay = 4`，[`_draw_cmd_bar`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L457-L465) 讀 `sim.tick` 會讓冷卻倒數與次數在畫面單位實際出手前 **提早 0.2 秒（4 tick）跳變**，干擾玩家對秒數的判讀。
- **(甲) 維持手動局 `delay = 2`，壓縮遠程前搖讓出飛行段（低風險，建議採用）**：
  1. **手感與時間軸零副作用**：完全不改 `sim.cast` 與 `view` 的 2 tick 差，手動軍令回饋、時間軸標記與重播 100% 一致。
  2. **順手修正腳本軍令局緩衝**：第 12 章殘局與重播 (`sim.cmd_scripted == true` 或 `play_kind != "official"`) 根本沒有即時手動輸入（[`_cmd_press`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L378) 已擋），[`view_buffer.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L75) 改判 `bool(sim.get("cmd_on")) and not bool(sim.get("cmd_scripted"))` 才用 `DELAY (2)`，使第 12 章與軍令重播直接享有 `DELAY_LONG (8)` 的完整遠程飛行表現。
  3. **實作細節**：在 [`battle_state.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L70-L138) 將 `delay` 傳入 `pick_hit` / `atk_timing` / `atk_progress`（同步更新 [`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L585)）。當 `delay <= 2` 且 `proj_fly(type) > 0`（弓手 2、投彈 6、醫官 7、骨法 17）時，將 2 tick 拆為 **前搖 `w = 1.0` tick（`h - 2 → h - 1`）＋飛行 `fly = 1` tick（`hr = x - 1 → x`，60fps 下約 3 幀飛行弧線）**。

- **選擇**：**選 (甲)**（外加 `cmd_scripted` 走 `DELAY_LONG`）。
- **驗收條件**：
  1. 即時手動軍令局中，4 個遠程兵種皆在 `disp = h - 2` 起手前搖、`h - 1` 離手生成投射物（`pk` 由 `0→1` 飛行 1 tick）、`disp = h` 命中並同步跳血與音效，無命中後才飛出的「回馬槍」。
  2. 第 12 章軍令殘局與軍令重播自動使用 `delay = 8`，遠程飛行時間為完整 3～5 tick，且第 12 章預設解法（[`puzzles.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/puzzles.gd#L153-L217)）與碼錶標記 0 誤差。

---

### 2. A3 轉身攻擊烘 2 個中繼角：格數與記憶體估算

查看 [`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L18-L45)：
- 單格尺寸：`CELL = 192`（[`L18`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L18)），RGBA8 未壓縮單格 = `192 × 192 × 4 = 147,456 B`（**144 KiB**）。每列 `COLS = 16`（寬 3072px，每列 **2.25 MiB**），單頁高上限 4096px（最多 21 列 = 336 格 = **47.25 MiB**）。
- 現有快取（22 兵種 × 2 隊 = 44 組）：主頁 `44 × 28 = 1,232` 格（173.25 MiB）＋`turn_tex`（`TURN_C = 3` 角，`44 × 3 = 132` 格，20.25 MiB）＋`fid_tex`（`44 × 5 = 220` 格，31.5 MiB）＋`wt_pages`（`WT_C = 1` 角 × 4 相位 = `176` 格，24.75 MiB）。注意 [`L33`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L33) 註解已明載：「*V1.3.1 驗收：兩個角度實測貼圖記憶體 +126 MiB 超過 §0 的 104，改一個角度*」。
- **A3 新增估算**：每個兵種攻擊有 `ATK_FRAMES = 8` 格，含特殊/交替共 `8 × 2 = 16` 格（[`L24-L26`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L24-L26)）：
  - 若烘 **2 個中繼角 × 16 攻擊格 × 44 組** = **+1,408 格（88 列，約 4.2 頁 4K 圖集）= +198.0 MiB**！
  - 就算只烘一般攻擊 8 格（不含 alt）：`2 × 8 × 44` = **+704 格（44 列，2.1 頁）= +99.0 MiB**。
- **可行性結論**：**烘完整攻擊格 × 2 中繼角不可行**（記憶體暴增 99～198 MiB 且啟動烘焙時間翻倍）。
- **可行替代方案**：因 [`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L716-L720) 轉身攻擊只需過渡**前搖到出擊前段（`atk < 0.53`）**，收招時 `face_now` 已轉正為 `±1.0`：
  1. 只烘 **1 個中繼角（`c = 0.55`）× 前搖/出擊 2 個關鍵格 × 44 組 = +88 格（6 列 = +13.5 MiB）**；或
  2. **0 額外記憶體**：在 `atk < 0.30`（前搖段）直接複用現有 `turn_tex`（已有 `[0.8, 0.55, 0.3]` 3 個角度）搭配微幅位移/傾斜，`atk >= 0.30` 揮擊瞬間切回正側面攻擊格並疊加刀光。

---

### 3. A5 近看細節「展開獨立畫布」具體版面配置

查看 [`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L16-L20)：`CX_PANEL = Rect2(180, 96, 920, 628)`，左欄 `CX_LEFT = Rect2(204, 204, 376, 388)`，右欄為技能鈕 `y: 212..250`、`CX_DESC = Rect2(596, 256, 474, 58)`、小劇場 `CX_BOX = Rect2(596, 318, 474, 267)`。
若在一般模式左欄 `y = 351` 強塞第 5 顆按鈕，寬度會從 `x = 208` 延伸到 `416`，在 125%/150% 字級下必撞 `x = 364..572` 的職能與標語文字（[`L476-L485`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L476-L485)）。

**不撞版具體配置（收合右欄文字與小劇場，於右欄 `x: 596..1070, y: 204..592` 展開獨立近看畫布，或覆蓋中段）**：
建議將「獨立近看畫布」配置於**右欄全區 `CX_ZOOM_RECT := Rect2(596, 204, 474, 388)`**（開啟 `cx_zoom` 時暫時收合右側技能文字與舊小劇場，左欄 `CX_LEFT` 能力值與文字完全保留不重排、不撞版）：
1. **入口按鈕（左欄不撞字）**：維持左欄原有 4 顆按鈕（`x: 208..374`），將「`🔍 近看`」按鈕放在**立繪框左上角內側 `Rect2(210, 210, 40, 36)`**（立繪中心在 `(274, 336)`，左上角完全空白），或放在右欄技能列最右側 `Rect2(1030, 212, 40, 38)`。
2. **展開畫布區 `Rect2(596, 204, 474, 388)` 內部切分**：
   - **頂部狀態列 `Rect2(608, 210, 450, 32)`**：左側顯示動作相位與秒數（如 `前搖 0.10s / 飛行 0.15s`），右側放 `✕ 返回小劇場` 按鈕 `Rect2(968, 208, 90, 34)`。
   - **獨立演武舞台 `Rect2(608, 248, 450, 242)`**（設 `canvas_item_set_clip` 裁切防穿版）：
     - 攻擊者站位 `Vector2(696, 420)`（面朝右）或 `Vector2(970, 420)`（面朝左），標靶假人站位在對側（間距 **274px**）。
     - 遠程投射物（箭、炸彈、骨彈、治療波）有完整 **274px 飛行軌跡與命中爆點**，2 倍放大（`scale = 2.2`）亦絕不穿出 `450×242` 畫布邊界。
   - **底部雙排控制列 `Rect2(608, 496, 450, 88)`**：
     - 第 1 排（`y = 498, h = 38`，6 鈕均分寬 68px、間距 8px）：`◀ 轉向`、`▶ 轉向`、`⏮ -1格`、`⏯ 暫停/播`、`⏭ +1格`、`0.25x/0.5x/1x`。
     - 第 2 排（`y = 542, h = 38`，3 鈕均分寬 144px）：`⚔ 一般出手`、`✦ 特殊/交替出手`、`🎯 切換敵/友標靶`。

---

### 4. 人時估計與假設（對照 V1.5.0 實際速度）

**估算假設**：以 Claude 在本專案的實測產能（V1.5.0 核心程式約 1 個工作日 8～10h 完成，三方審查、全語系 100%/125%/150% 版面微調與無頭驗收另占 1 倍時間）為基準。Codex 估 178～269h 是按傳統人工團隊重構估算（高估約 6 倍）；我方第 1 輪估 21～26h 則未計入新增的 D1～D4 及多輪驗收成本。
依修訂稿逐項實作＋驗收人時估計如下：

| 項目 | 實作 (h) | 驗收/修版 (h) | 小計 (h) | 關鍵工作與假設 |
| :--- | :---: | :---: | :---: | :--- |
| **C0 四項先修** | 1.5 | 1.0 | **2.5** | 備份順序、死區、倍率、快取失效（皆單點修改） |
| **A1/A2/A4/A6 圖鑑與著色** | 3.5 | 2.5 | **6.0** | 召喚物入圖鑑、冷卻/光環接線、雙動作、立繪 SubViewport 套 shader |
| **A3 轉身攻擊順暢** | 1.5 | 1.5 | **3.0** | 採 1 中繼角關鍵格或複用 `turn_tex`，免重構多頁圖集 |
| **A5 近看細節獨立畫布** | 2.5 | 2.0 | **4.5** | 右欄 `474×388` 展開舞台、274px 遠程飛行與逐格控制列 |
| **B1/B2 遠程同步與殘局校正** | 2.0 | 2.5 | **4.5** | `battle_state.gd` 2-tick 拆前搖/飛行＋跑完 12 章殘局自動測試 |
| **C1/C2 每日紀錄與對戰歷史** | 2.0 | 1.5 | **3.5** | `Save.data` 結構擴充、列表滑動與重播碼連動 |
| **D1～D4 連戰重播/電腦/名冊/引導** | 4.5 | 3.5 | **8.0** | 三波段重播打包與切換器、電腦分級、解鎖置頂、首局氣泡 |
| **總計** | **17.5** | **14.5** | **32.0** | **約 30～36 人時（約 3.5～4.5 個工作日）** |

---

### 5. 修訂稿遺漏與錯誤（附 `檔案:行號`）

1. **C0 寫檔順序遺漏「清除資料」**：[`v151-r1-plan.md:9`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-r1-plan.md#L9) 只提 [`_progress_restore`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L757-L762)，但同檔 [`_clear_data`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L820-L837) 一樣先覆寫 `Save.data` 並呼叫 `_after_data_swap()`，最後（`L835`）才檢查 `if not Save.save_data():`，必須一併修正。
2. **C0 手把死區遺漏 3 處硬編碼**：[`v151-r1-plan.md:10`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-r1-plan.md#L10) 只提 [`game_menus.gd:92`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L92)，但 [`game_screens.gd:200`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L200)（`absf(ev.axis_value) > 0.6` 切 `pad_mode`）、[`game_place.gd:147`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L147) 與 [`game_place.gd:268`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L268) 仍寫死 `0.5` / `0.6`。
3. **C0 速度倍率遺漏戰中 HUD 與重播控制列**：[`v151-r1-plan.md:11`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-r1-plan.md#L11) 只改 [`game_menus.gd:500`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L500)，但戰中點擊速度鈕 [`battle_view.gd:716`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L716) 只在 `1.0 → 2.0 → 4.0 → 0.5` 循環（選 `0.25x` 或 `8x` 進場點一下就會跳回 `1.0x` 且切不回去），重播速度列 [`replay_view.gd:32`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L32) 也只寫死 `[0.5, 1.0, 2.0]`。
4. **A1 召喚物（編號 20 小史萊姆、21 骷髏兵）進圖鑑會引發陣列越界崩潰**：[`unit_defs.gd:175`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/unit_defs.gd#L175) 的 `D.total()` 為 `20`（不含 20、21）。若在圖鑑切換 `cx_unit = 20` 或 `21`，[`codex_view.gd:300-307`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L300-L307)（`_cx_ranks` 的 `hp[t]`）與 [`codex_view.gd:328-335`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L328-L335)（`_cx_bars` 的 `vals[t]`）只算 `0..19`，讀取 `t = 20, 21` 會直接 Key/Index 越界報錯。
5. **A6 圖鑑立繪套烘焙著色器不能直接走 `sprites.draw_unit`**：[`codex_view.gd:551-552`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L551-L552) 特意維持 `CX_FIT >= 1.41` 以繞過 [`ui_base.gd:971`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L971) 的快取，因為 [`sprite_cache.gd:461`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L461) 只烘正面半圈（`Art2.back = false`），沒有 16 角度的背面（`back = true`）。A6 必須為圖鑑立繪建一個小型 `SubViewport` 即時渲染 `Art.unit` 並掛載 `unit_bake.gdshader`，才能兼顧 16 角度背面旋轉與像素描邊質感。
