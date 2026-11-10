以下為《落子無悔》V1.5.1 初稿（[v151-r0-draft.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v151-r0-draft.md)）第 1 輪審查報告：

### 1. A～F 逐項評估

* **A1. 補齊剩餘 6 兵種背面與修正 `05dabc6` 殘留問題**
  * **評估**：**必做**（使用者最在意圖鑑轉身與手持物完整度）。
  * **技術風險**：
    * [`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L30) 的 `BACK_OK` 在 `05dabc6` 擴為 16 種，但**騎兵（3）**在 [`_k_cavalry`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L358-L393) 只加了騎士後腦髮（[`L374`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L374)），馬頭（`L361`）、馬眼（`L363-L364`）、馬尾（`L359`）完全沒處理 `back`，背面看是「人轉背、馬正臉」，且騎槍護手盤（`L391`）蓋在手掌上。
    * **寶箱怪（12）**有兩套繪製路徑：[`_f_mimic`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L81-L122) 與戰場閉箱態 `mimic_closed`（[`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L701)）。
  * **漏掉細節**：初稿寫「骷髏法師（兜帽背、法杖）」，但 [`_f_bone`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L248-L289) 設定是「左手托展開魔導書＋紫火、不拿杖（與醫者區隔）」；背面時書與紫火（`z = -5.0`）應被斗篷背面局部遮擋而非畫在最上層。
* **A2. 既有背面圖層遮擋整理**
  * **評估**：**必做**。
  * **技術風險**：[`kingdom.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd) 在 `back == true` 時，多處正面裝備仍畫在最上層：
    * 盾衛面罩眼縫（[`L94`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L94)）與整面大盾（[`L100-L110`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L100-L110)）在背面蓋住披風背與後腦。
    * 投彈手護目鏡片（[`L200-L203`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L200-L203)）畫在後腦上，手捧炸彈（[`L214-L221`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L214-L221)）蓋在背後火藥桶（[`L308`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L308)）上。
    * 醫者帽前綠十字（[`L231-L232`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L231-L232)）與前披肩（[`L41`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L41)）、劍士前領巾（[`L76`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L76)）、戰鼓手胸前大鼓（[`L260-L274`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L260-L274)）、長槍兵槍桿（[`L186`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L186)）背面皆未分前後段遮擋。
* **A3. 戰場轉身中出招不瞬跳側面**
  * **評估**：**應做**。
  * **技術風險**：[`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L716-L720) 在 `at > 0.0` 時將 `face` 與 `face_now[u.id]` 強制鎖死為 `±1.0`；[`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L354) 也將 `atk > 0.0` 強制歸正。
  * **漏掉細節**：若轉身出招改走即時直繪（`Art.unit`），會跳過 [`unit_bake.gdshader`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L219)（外框墨線＋水洗乾刷），戰場上會出現明顯畫風閃跳。建議在烘焙圖集補 2 個轉身出招中繼角，或保留 `face_now` 連續插值並在 `absf(face) < 0.88` 時走預烘焙過渡格。
* **A4. 人形兵種 8 方向關鍵姿態**
  * **評估**：**可延後**（建議縮減併入 A1/A2）。
  * **技術風險**：目前 [`_part`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L84-L94) 靠 `z` 位移與 `turn_c` 寬度達成 3/4 角，若改為 8 向手調關鍵表，工作量極大且易破壞 `ANCHOR/CLIP` 邊界。建議只針對 3/4 角（`absf(turn_c) < 0.75`）修正雙手武器（長槍、標槍、騎槍、戰鼓）的前後手繪製順序即可。
* **A5. 圖鑑檢視控制補強（單步、標靶、2x 放大、角度標籤）**
  * **評估**：**必做**（直接支援使用者在圖鑑驗收小人與射出物）。
  * **技術風險**：
    * **版面擠壓**：[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L207) 左欄 `CX_LEFT` 寬 376px，小人區僅寬 160px（文字從 `x + 160` 開始，見 [`L386`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L386)），目前 4 顆按鈕（[`L366-L380`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L366-L380)）已佔 166px，再塞單步與縮放鈕會撞右欄文字或撐破 `head_h = 260`（[`L211`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L211)）。
    * **投射物穿版**：[`_draw_projectile`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L600) 終點固定 `pc + Vector2(face * 150.0, -30.0)`；朝右時直接穿過名稱文字區，朝左時（`cx_angle` 5..11，`pc.x = 274`）飛到 `x = 124`，超出羊皮紙左界（`180`）。
  * **漏掉細節**：建議「2x 放大＋標靶模式」點擊放大鏡時展開左側預覽區（暫時收合右半部文字或給獨立畫布框），讓遠程投射物有完整飛行與命中標靶空間。
* **A6. 驗收圖包（`tools/unit_review.gd`）**
  * **評估**：**必做**。
  * **漏掉細節**：[`unit_review.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/unit_review.gd#L28-L55) 目前硬編碼 `2.0` 倍、未套用 [`unit_bake.gdshader`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L219) 後製，且完全沒畫遠程投射物。必須把投射物與命中瞬間一併渲染進驗收圖。
* **B1. 手動軍令局遠程同步**：**必做**（詳見第 3 點）。
* **B2. 重播跳轉（Seek）半空投射物與特效重建**
  * **評估**：**應做**。
  * **技術風險**：[`replay_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L148-L183) 的 `_seek_finish` 雖回退 `view.delay` 格並呼叫 `_pump_view()` 與 `_sim_step(false)`，但因 `fx.clear(); dying.clear(); graves.clear()`（[`L153-L155`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd#L153-L155)）且 `_sim_step(false)` 傳入 `with_fx = false`（[`battle_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L529)），導致跨 `target` 格存續的箭矢殘留、爆炸、隕石／時鐘法陣、倒地動畫與墓碑全部清空。應在最後 `delay` 格將事件帶入 `dt` 衰減補償的輕量特效重建。
* **C1～C7. 設定頁 V1.5 延後項**
  * **C1（搖桿重綁）、C2（設定頁搜尋）、C5（分類重置）**：**可延後**（目前 26 項已有 6 分頁籤與全頁重置 [`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L660)，搜尋與單頁重置非急迫）。
  * **C3（跨螢幕記憶位置）**：**應做**，改 [`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L172-L194) `apply_window` 即可，風險低。
  * **C4（無邊框全螢幕 `WINDOW_MODE_FULLSCREEN`）**：**應做**，[`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L175) 目前 `full` 直接設 `EXCLUSIVE_FULLSCREEN`，改為三態（視窗／無邊框／獨佔）很直觀。
  * **C6（21:9 超寬螢幕）**：**可延後**（全 UI 座標皆以 `W=1280, H=720` 為基準寫死，如 [`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L204-L209)，改動面過大）。
  * **C7（開局預設面板開關）**：**應做**，在 [`battle_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L67-L69) 初始化 `show_dps` / `show_log` 時讀取 `Save.s()` 即可。
* **D1～D4. V1.4 玩法尾項**
  * **D1（長碼 V3）、D2（遠端排行榜）**：**可延後**（牽動網路後端與版本相容，不適合放在視覺打磨小版）。
  * **D3（每日／每週挑戰歷史回顧）**：**應做**，[`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L53) 已有 `daily` 結構，擴充近 7 筆紀錄即可。
  * **D4（Steam 房主斷線接管）**：**可延後**（[`lobby_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd) 狀態機複雜，高風險）。
* **E1～E5 & F. 驗證、工具與不變量**：**必做**，維持 `FINGERPRINT` 與 `288176c5c9af5a79` 不變。

---

### 2. 初稿漏掉、但 V1.4／V1.5 確實留下的問題（附依據）

1. **`05dabc6` 新增背面中的破圖與斷裂（初稿未列）**
   * **吸塵貓（18）吸塵管與背桶在轉身／背面時斷開**：[`_f_cat`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L301-L322) 背桶用 `_part(ci, 4.0, 0.6)`，但軟管卻用相反深度的 `_part(ci, -4.0, 1.0)` 從 `(-6, -18)` 畫到噴嘴；在轉身與 `back == true`（`z` 翻轉）時，軟管起點與背桶往反方向位移而懸空脫節。
   * **燈靈（16）背面仍有空白人頭且翅膀圖層反置**：[`_f_sprite`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L226-L245) 在 `back == true` 時只跳過 `_eyes`，仍畫出正臉膚色圓（`L244`），且背後的翅膀（`L226-L232`）先畫、被玻璃瓶身（`L234`）蓋在底下。
2. **圖鑑缺少「孢子使（10）」與「巫毒偶（15）」攻擊投射／連線特效**
   * 依據：[2026-11-09-v1.5.0-plan.md §3.1](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/2026-11-09-v1.5.0-plan.md#L120-L127) 點名孢子與巫毒偶，但 [`PROJ_FLY`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L89) 僅含 `{2, 6, 17, 7}`。在圖鑑點「攻擊」時，孢子使與巫毒偶沒有任何射出物或紫線脈衝（[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L597-L600)）。
3. **圖鑑大圖未套用烘焙 Shader，導致塗裝室「水洗／乾刷」在圖鑑完全無效**
   * 依據：[2026-11-09-v1.5.0-plan.md §3.4](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/2026-11-09-v1.5.0-plan.md#L152-L157)。[`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L552) 的 `CX_FIT` 縮放為 `1.41..2.0`，超過 [`ui_base.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L455) 的 `scale <= 1.4` 門檻而走 `Art.unit` 向量直繪，跳過了 [`unit_bake.gdshader`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L219)，圖鑑小人既無墨線外框，也看不到玩家在塗裝室調的水洗與乾刷質感。
4. **左搖桿死區（Deadzone）公式被 `0.6` 常數吃掉，5%～40% 設定形同虛設**
   * 依據：[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L92) 寫 `maxf(0.6, int(Save.s("deadzone")) / 100.0 + 0.2)`。因 `deadzone` 範圍是 `5..40`（[`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L18)），`deadzone / 100.0 + 0.2` 永遠落在 `0.25..0.60`，被 `0.6` 完全吞沒。
5. **預設播放速度缺少 `0.25x / 4x / 8x` 檔位**
   * 依據：[2026-11-09-v1.5.0-plan.md §2.2 #24](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/2026-11-09-v1.5.0-plan.md#L84) 要求 `0.25／0.5／1／2／4／8` 倍，[`save.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L123) 也支援 `0.25..8.0`，但 [`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L500) 只給 `[0.5, 1.0, 2.0]`。
6. **設定頁 2 項 V1.5 規格遺漏與 1 項存檔順序缺陷**
   * 戰鬥暫停進設定未標示「立即生效／下一局生效」（[2026-11-09-v1.5.0-plan.md §8](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/2026-11-09-v1.5.0-plan.md#L223)）。
   * 主選單「輸入代碼」（[`game_menus.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L308-L315)）仍彈 3 顆手動分類鈕，未實作單鍵自動辨識 `NTB*`/`NTC1`/`NTP*`/`NTBR*`/`NTS1`（[v1.5.0-plan.md §1](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/2026-11-09-v1.5.0-plan.md#L28)）。
   * [`_progress_restore`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L757-L762) 先覆寫 `Save.data` 與執行 `_after_data_swap()`，最後才判斷 `if not Save.save_data()`，磁碟寫入失敗時記憶體與磁碟狀態不一致。

---

### 3. B1（手動軍令局遠程同步）建議做法與理由

* **不建議初稿選項 1（維持 2 格緩衝、只延後遠程命中視覺）**：
  * **理由**：這在 V1.5.0 R2 已被否決過（見 [2026-11-09-v1.5.0-plan.md §6](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/history/2026-11-09-v1.5.0-plan.md#L194)）。因為 [`ViewBuffer`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L64-L114) 的單位座標、存活與目標選擇是全場連動的：若 `EV.DEATH` 在 `t` 格發生，該單位在 `t+1` 格已從模擬移除，近戰兵會直接穿過其空位或轉火下一個目標；若強行把血條與倒地延後到 `t+5` 箭到才播，會出現「人還沒倒、敵軍已經穿過他身體打後排」或「範圍技／連鎖閃電打在空地上」的嚴重因果錯亂。
* **建議做法：「4 格緩衝（`DELAY_CMD = 4`，0.2 秒）＋遠程拉弓壓縮為 1 格、飛行 3 格」＋「軍令按鈕 0ms 即時預回饋」**：
  1. 在 [`view_buffer.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L8-L10) 新增 `DELAY_CMD := 4`（0.2 秒），手動軍令局使用 4 格緩衝。
  2. 在 [`proj_phase`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L97-L98) 與 [`atk_timing`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L117-L120) 中，當 `delay == 4` 時將遠程拉弓前搖設為 1 格、飛行 3 格（0.15 秒飛行，1+3=4 格），讓弓手、標槍、投彈、骷髏法師都能在命中前清楚飛出投射物並在命中格精準落地。
  3. 手動施放軍令時（[`_cmd_press`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L377-L386)），按鈕冷卻、音效與地面預警法陣在點擊當下（0ms）立即觸發，0.2 秒後模擬事件接手結算。
* **核心優勢**：完全零因果矛盾、不需維護複雜的延遲血量表、不碰模擬層（`FINGERPRINT` 100% 安全），且玩家按軍令鍵體感仍是 0 秒即時回饋。

---

### 4. M1～M3 範圍與人時估計（總計約 21～26 人時）

* **M1：角色 12 角度與背面完整度（約 10～12 人時）**
  * 修正 `05dabc6` 騎兵馬頭／馬尾、吸塵貓軟管、燈靈背面（2.5h）。
  * 補齊剩餘 6 兵種（11、12、14、15、17、21）背面並將 `BACK_OK` 推至 22/22（4.5h）。
  * 修正 A2 王國兵正面裝備遮擋與 3/4 角雙手武器前後層、A3 轉身出招過渡（3～5h）。
* **M2：圖鑑驗收強化與戰場遠程／重播時間同步（約 6～8 人時）**
  * A5 圖鑑單步控制、2x 放大檢視、標靶與孢子／巫毒偶特效、修正投射物穿版，加上圖鑑套用烘焙 Shader（3.5～4.5h）。
  * B1 手動軍令局 `DELAY_CMD = 4` 遠程同步與 B2 重播跳轉特效重建（2.5～3.5h）。
* **M3：設定與生活品質補遺、驗收圖包產出（約 5～6 人時）**
  * 修死區公式、播放速度檔位、單鍵代碼自動辨識、戰鬥中設定生效標示、C3/C4/C7、D3 每日歷史與存檔順序（3～3.5h）。
  * A6/E1～E5 更新 `unit_review.gd`（含投射物與烘焙效果），跑滿 7 套測試並產出 `docs/review/v151/` 驗收包（2～2.5h）。
