以下為 V1.4.0 變更的程式碼審查問題清單：

---

### 1. 【嚴重】`load_code6` 允許玩家透過 NTB6 代碼無上限塞入免費「巨獸」繞過預算、人數與卡池限制
- **嚴重度**：嚴重（Critical）
- **位置**：`game/scripts/core/army.gd` `load_code6()`（第 560–575 行）
- **重現**：
  1. 在任何接受陣型代碼輸入的地方（自訂對戰、挑戰碼、重播或匯入陣型），構造一段 `NTB6` 代碼，將多隻單位的 `type` 設為 `19`（石魔）並把第 4 位元組最高位元設為 `1`（`bossb = true`）。
  2. `if bossb:` 分支完全跳過 `tmp.place()`，只檢查 `b[o + 2] > 8` 與格子是否重疊，既不扣預算、不檢查人數上限（`unit_cap`）、不檢查當前規則卡池是否開放石魔（`pool`），也不限制最多只能有 1 隻巨獸，且未檢查 `b[o + 1]` 或 `b[o + 2]` 是否小於 0（雖然 `PackedByteArray` 為 `0..255`）。
  3. 藍方（玩家）可直接匯入塞滿 6×9 = 54 隻免費巨獸的非法陣型。
- **修法**：
  - `Army` 應新增屬性（如 `allow_boss := false`），僅在遠征終點 AI 或重播內部載入時開啟；或限制一般玩家不可載入含 `bossb` 的代碼，且即使允許載入，也必須限制全隊最多 1 隻（`boss_count == 0`）。

---

### 2. 【嚴重】護符（`STK.WARD`）在計算完 `dmg_dealt` 與 `last_hit` 後才歸零傷害，導致已死／未造成實際傷害卻觸發吸血、統計膨脹、護盾與擊殺歸屬錯亂，且 `dmg_taken` 可變負數
- **嚴重度**：嚴重（High）
- **位置**：`game/scripts/core/battle_sim.gd` `step()`（第 804–886 行）
- **重現**：
  1. 在 `for h in hits:` 迴圈（第 807 行）中，`dmg_in[h[1]] += h[2]`、攻擊者的 `units[h[0]].dmg_dealt += h[2]`、`units[h[1]].dmg_taken += h[2]`、`last_hit[h[1]] = h[0]` 都已經先寫入（且可能還有其他邏輯在 `hits` 階段寫入或讀取）。
  2. 到第 882 行結算時：
     ```gdscript
     if u.ward and dmg_in[i] > 0:
         u.dmg_taken -= dmg_in[i]
         dmg_in[i] = 0
         u.ward = false
     ```
  3. **問題 A**：攻擊者的 `dmg_dealt` 沒有扣回，結算報告的輸出傷害虛高。
  4. **問題 B**：`last_hit[i]` 仍保留該次被護符擋掉的攻擊者；若同一 tick 該單位因火牆（`_ev_tick` 直接扣 `u.hp`，不走 `dmg_in`）或上一 tick 殘留狀態死亡，擊殺歸屬（`_v8_on_death(i, last_hit[i])`）會算在被護符完全免疫的攻擊者頭上。
  5. **問題 C**：同一 tick 若有多下攻擊打在護符單位上，護符說明是「第一次受到的傷害無效」（單筆 `hit` 還是整 tick 所有 `hits`？若是單筆卻擋了整 tick 總和 `dmg_in[i]`；且若先經過 `_boss_parts` 扣了部位血量，護符又在後面把本體 `dmg_in` 歸零，巨獸貼護符時部位還是會掉血）。
- **修法**：
  - 將 `u.ward` 的判定移至 `for h in hits:` 迴圈內（且在 `_boss_parts` 之前或整合在一起）：當 `tg.ward and h[2] > 0` 時，直接將 `h[2] = 0`、`tg.ward = false`，不累加 `dmg_in`、`dmg_dealt`、`dmg_taken`，也不更新 `last_hit`。

---

### 3. 【嚴重】沙盤機關 `_ev_tick` 的火牆傷害與崩塌推擠發生在 `step()` 開頭，導致單位 `hp <= 0` 卻在該 tick 繼續移動、索敵、普攻與放技能，且崩塌未清導航途經點 `_nav_wp`
- **嚴重度**：嚴重（High）
- **位置**：`game/scripts/core/battle_sim.gd` `step()`（第 348–349 行）與 `_ev_tick()`（第 2119–2161 行）
- **重現**：
  1. **死人出手**：在 `beacon`（烽火關）地圖，火牆在 `_ev_tick(n)`（第 349 行，快照與移動／攻擊之前）直接扣減 `u.hp -= MapDefs.FIRE_DMG`。但死亡判定（`if u.alive and u.hp <= 0: u.alive = false`）在 `step()` 尾端（第 924 行）才執行。這導致被火牆燒到 `hp <= 0` 的單位，在整個當前 tick 依然 `u.alive == true`，照常移動、阻擋、普攻、放技能、甚至在尾端 `_apply_heals(heals)` 被補血活過來。
  2. **導航快取失效**：在 `quarry`（崩塌礦坑）地圖第 400 tick，`collapse` 呼叫 `terrain.apply_rects(...)` 重建了 `terrain.nav` 並清空 `terrain._fields`，但**沒有清空 `battle_sim.gd` 的 `_nav_wp`（單位導航途經點快取，每 4 tick 才重算一次）**。在 tick 400～403 之間，未輪到重算 `_nav_wp` 的單位仍會朝著崩塌前算好的舊途經點直走撞牆。
- **修法**：
  - 在 `collapse` 事件觸發 `terrain.apply_rects(...)` 後，立即執行 `_nav_wp.clear()`。
  - 火牆傷害應改為產生環境傷害並在 `step()` 傷害結算階段（`_apply_heals` 前後與死亡判定同階段）結算，或在 `_ev_tick` 扣血導致 `hp <= 0` 時立即處理死亡流程。

---

### 4. 【高】沙盤機關 `in_rect` 與 `collapse` 推擠存在左右鏡像不對稱（邊界 `<` vs `<=` 及 `free_near` 搜尋方向）
- **嚴重度**：高（High — 破壞左右鏡像對稱）
- **位置**：
  1. `game/scripts/core/terrain.gd` `in_rect()`（第 64–68 行）
  2. `game/scripts/core/battle_sim.gd` `_ev_tick()`（第 2127–2132 行）
- **重現**：
  1. **`in_rect` 整數除法與開區間不對稱**：
     ```gdscript
     var ox: int = x if x < w / 2 else w - x
     var nx: int = ox * 1000 / (w / 2)
     var ny: int = y * 1000 / h
     return nx >= int(rc[0]) and nx < int(rc[2]) and ny >= int(rc[1]) and ny < int(rc[3])
     ```
     當左半某點為 `x = 4480`（在 `w = 16000` 時 `ox = 4480`，`nx = 4480 * 1000 / 8000 = 560`），鏡像點為 `w - x = 11520`，其 `ox = 16000 - 11520 = 4480`，這點對稱；但注意 `_paint()` 是以格子中心 `c * Q + Q / 2` 塗 `grid[c]` 與 `grid[n - 1 - c]`，而 `in_rect` 直接用世界座標 `x`。當 `x == w / 2`（中線 `x = 8000`）時，`ox = 8000`，`nx = 1000`，因為判斷式是 `nx < int(rc[2])`，當 `rc[2] == 1000`（如烽火關 `[880, 240, 1000, 760]`）時，**恰好站在中線 `x = 8000` 的單位 `nx = 1000 < 1000` 為 `false`，站在中線不會被火牆燒到**！
  2. **`collapse` 推擠的 `free_near` 鏡像性**：
     崩塌時若左右兩軍對稱站在崩塌區邊緣，`terrain.free_near(u.x, u.y, u.team)` 若內部搜尋格子的順序是固定的（例如從小到大 `dc` 或固定方向螺旋），左軍（`team 0`）與右軍（`team 1`）在平手距離時若未將搜尋方向依 `team` 或 `x < w / 2` 鏡像反轉，推出來的座標 `u.x` 與 `fw - u.x` 就會不對稱。
- **修法**：
  - `in_rect` 若 `rc[2] == 1000`，中線 `x == w / 2` 應包含在內（或改為查 `terrain` 的格子座標 `c = clampi(x / Q, 0, n - 1)`，直接與 `_paint` 用同一套格子鏡像邏輯 `c if c < n / 2 else n - 1 - c`）。
  - 確認 `terrain.free_near` 對 `team == 1`（或右半場）的 X 軸搜尋順序與回傳座標完全滿足 `w - x` 鏡像。

---

### 5. 【高】倒下自爆（`STK.BLAST`）在同 tick 炸死敵軍時，不會在當 tick 觸發死亡，且若最後雙雙同歸於盡會改變勝負判定時序
- **嚴重度**：高（High）
- **位置**：`game/scripts/core/battle_sim.gd` `step()`（第 934–946 行）
- **重現**：
  1. 單位 A（貼有 `STK.BLAST`）在第 T tick `hp <= 0` 倒下，對周圍敵人 E 造成 `STK.BLAST_DMG (30)` 傷害，`e.hp -= 30`。
  2. 若 E 的 `hp` 因此降到 `<= 0`，因為死亡迴圈（第 922 行）已經跑完，E 在第 T tick 結束時仍然 `e.alive == true`。
  3. **後果 A**：若第 T tick 場上原本只剩 A 與 E，A 先在死亡迴圈變成 `alive = false`，而 E 被炸到 `hp <= 0` 卻仍 `alive = true`。在 `step()` 尾端檢查勝負（`alive_count`）時，**A 的隊伍已經全滅（0 活人），E 的隊伍還有 1 活人（雖然 `hp <= 0`）**，模擬直接在第 T tick 結束並判定 E 的隊伍獲勝，而不是平手或繼續！
  4. **後果 B**：若戰鬥沒結束，E 在第 T+1 tick 會整個 tick 以 `alive == true, hp <= 0` 的狀態繼續移動、索敵、出招攻擊，直到第 T+1 tick 尾端才死，且 `last_hit[j]` 在第 T+1 tick 若沒被打到會是 `-1`，遺失擊殺者歸屬。
- **修法**：
  - 將 `STK.BLAST` 改為像爆爆羊 `_pending_blast` 一樣放入佇列在下一 tick 傷害結算階段透過 `hits` 處理，或者在自爆迴圈結束後再跑一次死亡判定迴圈（處理被炸到 `hp <= 0` 的單位死亡，並記錄 `last_hit`）。

---

### 6. 【高】`ViewBuffer.apply()` 長度判斷寫錯（`a.size() > 30`），導致貼紙、護符、巨獸與部位血量在畫面／重播永遠不會更新！
- **嚴重度**：高（High — 畫面與重播功能壞損）
- **位置**：`game/scripts/ui/view_buffer.gd` `capture()` 與 `apply()`（第 65 行、第 101–102 行）
- **重現**：
  1. 在 `capture(sim)` 中，每個單位陣列 `us.append([...])` 共有 **31 個元素**（索引 `0` 到 `30`）：
     - `0..23`：原有 24 個欄位（`id` 到 `summon`）
     - `24`: `u.st`
     - `25`: `1 if u.ward else 0`
     - `26`: `1 if u.boss else 0`
     - `27`: `u.arm_hp`
     - `28`: `u.plate_hp`
     - `29`: `u.shield`
     - `30`: `u.haste_t`
  2. 在 `apply(fr)`（第 98–103 行）中：
     - **漏讀了 `shield`（索引 29）與 `haste_t`（索引 30）？** 原先 `shield` 與 `haste_t` 在索引 24、25，現在你把 `st, ward, boss, arm_hp, plate_hp` 插在索引 24..28，把 `shield` 與 `haste_t` 擠到索引 29、30！如果 `apply()` 上方（第 90–97 行未顯示於 diff 的部分，或舊有讀取 `a[24]`、`a[25]` 的程式碼）還在讀 `a[24]`、`a[25]` 當作 `shield` 與 `haste_t`，那**手動技能的護盾圈（`u.shield`）與戰吼加速（`u.haste_t`）會誤讀成 `u.st`（貼紙編號 1~6）與 `u.ward`（0/1）**，導致貼了貼紙的兵在畫面上全程顯示藍色護盾圈與戰吼特效！
     - 若舊快照（例如舊重播）只有 26 個元素（索引 0..25），`a.size()` 為 26；新快照為 31 個元素。若 `shield` 和 `haste_t` 原本在 `24, 25`，新欄位應該排在 `26..30`（最後面），而不是插在中間破壞索引 `24, 25`！
- **修法**：
  - 在 `capture(sim)` 中，將新欄位 `u.st, 1 if u.ward else 0, 1 if u.boss else 0, u.arm_hp, u.plate_hp` 放到陣列**最尾端**（索引 `26..30`，在 `u.shield, u.haste_t` 之後），並在 `apply()` 中用 `if a.size() > 28:` 讀取 `a[26]..a[30]`，保持 `a[24]`（`shield`）與 `a[25]`（`haste_t`）向後相容。

---

### 7. 【高】`Army.mirrored()` 與 `load_code6()` 在自由部署（`deploy == "free"`，`u.has("x")`）時遺失貼紙與巨獸屬性
- **嚴重度**：高（High — 鏡像與編解碼不一致）
- **位置**：`game/scripts/core/army.gd` `mirrored()`（第 399–400 行）、`to_code6()` / `load_code6()`（第 520–560 行）
- **重現**：
  1. 在 `mirrored()` 中：
     ```gdscript
     if u.has("x"):
         a.units.append({"type": u["type"], "x": fw - int(u["x"]), "y": u["y"]})
     ```
     只處理了 `else`（格子模式）的 `st` 與 `boss` 複製，若自由部署的單位帶有 `st` 或 `boss`，呼叫 `mirrored()` 後會全部遺失，直接破壞左右鏡像對稱。
  2. 在 `battle_sim.gd` `_init()`（第 278–289 行）：
     ```gdscript
     if has_st:
         ...
     elif free:
         _hash.update("free".to_utf8_buffer())
     ```
     使用了 `elif free:`！如果一場自由部署（`free == true`）且沒有規則（`legacy == true`）的對局同時有貼紙（`has_st == true`），原本會執行的 `_hash.update("free")` 被 `elif` 吃掉了。應改為獨立的 `if free:`（或把 `if has_st:` 放在 `if not legacy: ... elif free:` 之後）。
- **修法**：
  - `mirrored()` 的 `if u.has("x"):` 分支也要複製 `st` 與 `boss`。
  - `battle_sim.gd` 第 280 行的 `if has_st:` 不要拆斷原本的 `if not legacy: ... elif free:`，應把 `if has_boss:` 與 `if has_st:` 移到 `elif free:` 區塊之後。

---

### 8. 【中】GodotSteam 4.x 排行榜 API 參數順序與回呼簽名錯誤，實際接上 Steam 時上傳與下載都會失敗或報錯
- **嚴重度**：中（Medium — Steam 排行榜功能失效）
- **位置**：`game/scripts/game/steam.gd`（第 166–207 行）
- **重現**：
  1. **`findOrCreateLeaderboard` 常數值錯誤**：
     第 174 行：`_steam.findOrCreateLeaderboard(name, 1, 1)`。
     在 Steamworks / GodotSteam 中，`ELeaderboardSortMethod` 的 `1` 是 `LEADERBOARD_SORT_METHOD_ASCENDING`（正確），但若排行榜已存在且後台設定不同，或玩家未傳正確 enum；更重要的是下方的 `uploadLeaderboardScore` 與 `downloadLeaderboardEntries`。
  2. **`downloadLeaderboardEntries` 區間與參數**：
     第 205 行：`_steam.downloadLeaderboardEntries(0, 19, 0, handle)`。
     Steamworks 的グローバル排名是 **1-based**（第 1 名到第 20 名應傳 `1, 20`，傳 `0, 19` 在 Steamworks 中第 0 名是無效索引，只會拿到 1~19 共 19 筆或異常）。
  3. **`_on_lb_found` 沒有拿到排行榜名稱時無法上傳，且並發衝突**：
     `leaderboard_find_result` 訊號在進行 `ghost_fetch`（呼叫 `findLeaderboard`）時**也會觸發**！
     當玩家已經連上 `_steam.connect("leaderboard_find_result", _on_lb_found)`，之後呼叫 `ghost_fetch` 時，`_on_lb_found` 與 `ghost_fetch` 的 `on_found` 都會收到同一個 `leaderboard_find_result` 訊號；且若玩家連續觸發兩次 `weekly_upload` 或 `ghost_fetch` 的 `CONNECT_ONE_SHOT` 撞上前一次尚未回傳的查詢，會抓錯 `handle`。
  4. **`pack_army` 對自由排兵回傳空陣列卻仍呼叫上傳**：
     第 169 行 `var det := pack_army(army.units)`，若 `det` 為空（或 0 兵），仍會把空 `details` 上傳覆蓋掉玩家原本帶有陣型的紀錄。
- **修法**：
  - `downloadLeaderboardEntries(1, 20, 0, handle)` 使用 `1, 20`。
  - 不要混用永久連線的 `_on_lb_found` 與 `CONNECT_ONE_SHOT` 的 `on_found`，統一用佇列或檢查 `_lb_pending` 狀態，且 `det.is_empty()` 時不上傳 details。

---

### 9. 【中】遠征終點若同時觸發「宿敵（Nemesis）」，巨獸會被宿敵陣型直接覆蓋消失，但畫面上卻已經跳出「巨獸登場」提示
- **嚴重度**：中（Medium — 邏輯與 UI 矛盾）
- **位置**：`game/scripts/ui/screens/game_core.gd` `_reset_place()`（第 107–113 行）
- **重現**：
  ```gdscript
  if node == "boss" and not _demo():
      call("add_boss", armies[1])   # V1.4 #12：遠征終點多一隻巨獸
      _toast(L.t("boss_here"))
  if int(get("gauntlet_nemesis")) >= 0:
      armies[1] = call("_nemesis_army", int(get("gauntlet_nemesis")))
  ```
  如果 `gauntlet_nemesis >= 0` 在 `boss` 節點成立（或未來改動、存檔讀入異常使終點有宿敵），第 108 行剛加進 `armies[1]` 的巨獸會在第 111 行被 `armies[1] = call("_nemesis_army", ...)` 整支軍隊覆蓋掉，而且前面第 91 行已經扣了 `BossD.BUDGET_CUT`（42 金）。
- **修法**：
  - 將 `if node == "boss" and not _demo():` 的 `add_boss` 放在 `gauntlet_nemesis` 處理之後（或明確確保 `boss` 節點不會有宿敵，並在 `nemesis` 覆蓋後仍補上 `add_boss`）。

---

### 10. 【中】遠征獎勵「木座貼紙（`rw_sticker`）」在 `_take_reward` 存檔前套用，但若玩家該戰有更換／拖曳過單位，`_sticker_pick()` 取樣來源與 `_apply_sticker()` 目標不一致導致貼紙遺失
- **嚴重度**：中（Medium）
- **位置**：`game/scripts/ui/screens/game_modes.gd` `_sticker_pick()` 與 `_take_reward()`（第 635–696 行）
- **重現**：
  1. `_sticker_pick()` 挑選目標單位時，優先看 `last_armies[0].units`（上一場出戰陣型），回傳 `[st, col, row]`。
  2. 在 `_take_reward(k)` 中：
     ```gdscript
     var sp := _sticker_pick() if k == 6 else []
     ...
     call("_gauntlet_next")
     if not sp.is_empty():
         _apply_sticker(sp)
     ```
  3. 若上一場有觸發其他戰間機制（例如車輪戰殘兵、或 `_gauntlet_next` 重建 `armies[0]` 時從 `gauntlet_prev` 載入，而 `last_armies[0]` 因為場地或臨時變動與 `gauntlet_prev` 的 `(col, row)` 不同），`_apply_sticker` 用 `(col, row)` 比對會找不到單位，導致玩家選了貼紙獎勵卻什麼都沒拿到。
  4. 此外，玩家在下一戰部署階段若把貼了貼紙的兵**拖曳換位**或**撤下再放上**（在 `game_place.gd` 中），需確認拖曳移動格子時 `u["st"]` 有沒有保留（若拖曳是 `remove` + `place` 新 Dictionary，貼紙會在移動位置時直接蒸發！）。
- **修法**：
  - `_sticker_pick()` 應統一從 `gauntlet_prev`（若非空）或轉入 `_gauntlet_next` 後實際生成的 `gauntlet_prev` 選取。
  - 檢查 `game_place.gd` 拖曳移動單位時，務必保留原單位 Dictionary 的 `"st"` 欄位。

---

### 11. 【低】每週棋盒跨週結算漏洞：週一換題前開局、換題後打完，會把舊週題目的成績寫進新的一週並上傳到新週排行榜
- **嚴重度**：低（Low — 排行榜公平性）
- **位置**：`game/scripts/ui/screens/game_modes.gd` `_weekly_start()` 與 `_ghost_settle()`（第 1657–1700 行）
- **重現**：
  1. 玩家在第 `W` 週結束前進入每週棋盒（`_weekly_start()` 用當下時間算出 `W` 週的 120 金題目）。
  2. 跨過 UTC 週一 00:00 後打贏，`_ghost_settle()` 重新呼叫 `week_no(int(Time.get_unix_time_from_system()))` 得到 `W + 1` 週，於是把第 `W` 週題目的花費寫入第 `W + 1` 週的 `Save.data["weekly"]` 並呼叫 `SteamApi.weekly_upload(W + 1, spent, ...)` 污染新週排行榜。
- **修法**：
  - 將開局時的週數存在成員變數（如 `var wk_cur := -1`），`_weekly_start()` 時記錄 `wk_cur = wk`，`_ghost_settle()` 結算與上傳時使用 `wk_cur`。

---

### 12. 【低】`battle_units.gd` 崩塌碎石繪製在極窄矩形時 `fposmod` 除數為負或零
- **嚴重度**：低（Low）
- **位置**：`game/scripts/ui/battle/battle_units.gd` `_draw_map_events()`（第 370 行）
- **重現**：
  - `fposmod(k * 37.0 + side * 11.0, R.size.x - 12.0)`：若未來地圖定義的 `collapse` 矩形寬度或高度在畫面上小於等於 `12.0 px`（即千分比寬度 `<= 23`），`R.size.x - 12.0 <= 0` 會導致 `fposmod` 算出 `NaN` 或負值，使 `draw_circle` 座標異常。
- **修法**：
  - 將除數包上 `maxf(1.0, R.size.x - 12.0)` 與 `maxf(1.0, R.size.y - 12.0)`。
