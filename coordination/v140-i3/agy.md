以下依檢查項目列出 diff 中的問題：

---

### 1. [高] 版面溢出：186 寬卡片放不下英文說明與大字級文字
* **檔案與行**：`game/scripts/ui/screens/game_modes.gd:1163-1170`、`game/data/strings.csv:1011, 1018`
* **重現情境**：
  切換英文（或開啟大字級）進入「遊戲間」。
  卡片寬度從 `350` 縮成 `186`，內文區可用寬度從 `302px` 縮水一半以上變成 `r.size.x - 36 = 150px`；而內文起點 `y = r.position.y + 140` 到下方按鈕上緣 `y = r.end.y - 62`（即 `r.position.y + 238`）只有 **98px** 的垂直空間（約 4 行）。
  * 英文 `pr_sealed_d` 長達 128 字元、`pr_waves_d` 長達 112 字元（舊的 `pr_wager_d`、`pr_draft_d` 也是為 302px 寬度寫的），在 `150px` 寬度下每行只能塞 2～3 個英文單字（約 15 字元），會折成 **8～10 行（約 160～220px 高）**，直接蓋過下方的「開始」按鈕甚至穿出卡片底邊。
  * 中文大字級在 `150px` 寬度下每行僅約 8 字，`pr_sealed_d`（44 字）會折成 6 行（約 120～135px 高），同樣會撞到下方按鈕。
  * 標題 `pr_sealed`（`"Sealed Orders"`）在 `166px` 寬度配 `tz("B")` 大字級若折成兩行，第 2 行也會壓到 `y + 140` 的內文起點。
* **建議修法**：
  1. 精簡四張卡的中英文 `pr_*_d` 文案（英文控制在 55～65 字元內、中文控制在 28 字內）。
  2. 將面板 `P` 再加寬（例如 `Rect2(140, 140, 1000, 500)`，4 張卡各寬 `224px`），或將圖示與標題上移（圖示 `y+42`、標題 `y+80`、內文 `y+112`）並把卡片高度從 `300` 拉高到 `320`。

---

### 2. [高] 車輪戰：第 2、3 波未鎖定殘兵，可全賣／清空當成純預算重擺
* **檔案與行**：`game/scripts/ui/screens/game_modes.gd:1349-1350`、`game/scripts/ui/screens/game_place.gd`
* **重現情境**：
  車輪戰第 1 波獲勝後按「下一波」進入第 2 波準備畫面。雖然 `_wave_setup` 把 `armies[0].units = surv.duplicate(true)` 放回場上，但 `game_place.gd` 完全沒有檢查 `wv_active` 來鎖住這些殘兵。玩家可以直接右鍵把殘兵賣掉（退還 100% 金幣）、按「清空」、套用預設陣型或自動配兵，拿「殘兵總價＋15 金」重新買一套全新的兵種與站位，與「擺一次陣迎三波／贏了只帶活下來的兵（站在原本的格子）」規則矛盾；反之若誤按「清空」也無法還原殘兵。
* **建議修法**：
  將本波繼承的殘兵存成 `wv_locked: Array`（或在單位 dict 標記 `"locked": true`）。在 `game_place.gd` 中，當 `wv_active` 為真時：
  * 禁止移除或移動 `wv_locked` 格子上的單位；
  * 按「清空」或「重擺」時，不是清空為 `[]`，而是還原成 `wv_locked.duplicate(true)`。

---

### 3. [高] 雙封蠟戰書：出現平手時第 4 局會重複拿第 3 封，甚至無限平手卡死
* **檔案與行**：`game/scripts/ui/screens/game_result.gd:526-531`、`game/scripts/ui/screens/game_modes.gd:1386`
* **重現情境**：
  `#13` 設定 `r.rounds = 3`，雙方僅封 3 個陣（索引 `0..2`）。
  若前 3 戰中出現平手（`w == -1`），尚未有人拿到 2 勝（若 `series_done` 以先拿 2 勝為準），按「下一局」進入 `round_no = 4` 時，`var k := clampi(round_no - 1, 0, 2)` 會再次讀取 `k = 2`（第 3 封）。
  由於《落子無悔》是 100% 確定性模擬，若第 3 戰（`k = 2`）本身就是平手且地圖未變，第 4 戰再拿一模一樣的 `sealed[0][2]` 對 `sealed[1][2]` 必然再次平手，陷入無限平手迴圈。
* **建議修法**：
  在 `sealed_on` 模式下，三封戰書打完（`round_no >= 3`）就應強制結束系列賽（例如在 `_finish_battle()` 中若 `bool(get("sealed_on")) and round_no >= 3: series_over = true`），3 戰打完直接以當下勝場數（如 1:0 或 1:1 平手）結算，不要進入第 4 局。

---

### 4. [高] 雙封蠟戰書：揭封後停在部署畫面（`blind_phase = 2`）可偷改陣型或破壞 `sealed` 狀態
* **檔案與行**：`game/scripts/ui/screens/game_place.gd:105-119`、`game/scripts/ui/screens/game_result.gd:526-531`
* **重現情境**：
  1. 紅方封完第 3 陣（`game_place.gd:115-119`）及第 2、3 局按「下一局」（`game_result.gd:526-531`）時，程式把 `blind_phase` 設成 `2` 並把雙方陣型放進 `armies[0]`、`armies[1]`，然後停在部署畫面（雙方陣型同時攤開可見）。
  2. 若 `game_place.gd` 在 `blind_phase == 2` 時未封鎖棋盤點擊、清空、預設陣型或指揮官切換，玩家看到對手的封陣後就能直接修改自己已封蠟的陣型。
  3. 若在部署畫面觸發重擺使 `blind_phase` 回到 `0`（但 `sealed` 仍保留 3 個陣），再次按開戰時 `sl.append(...)` 會塞入第 4 個陣（`sl.size() == 4`），HUD 顯示 `第 4／3 封`。
* **建議修法**：
  * 當 `sealed_on` 且 `blind_phase == 2` 時，在 `game_place.gd` 完全禁止任何增刪單位、清空、預設陣型與重擺操作；或者在紅方封完第 3 陣／按「下一局」時，直接進入戰鬥（呼叫 `_on_start()` 開戰流程）而不停留在部署畫面。
  * 若保留重置功能，重置時必須一併重置 `sealed = [[], []]`。

---

### 5. [中] 車輪戰：獲勝後看「重播」並使用時光機／跳出，按「下一波」會讀到錯誤的 `sim` 殘兵
* **檔案與行**：`game/scripts/ui/screens/game_modes.gd:1361-1367`、`game/scripts/ui/screens/game_result.gd:308`
* **重現情境**：
  第 1 或第 2 波獲勝後，結算畫面有「重播」與「下一波」兩個按鈕。若玩家先點「重播」，在重播中用時光機（Seek）拉回戰鬥中途、再返回結算畫面並點「下一波」，`_wave_next()` 執行 `wave_survivors(last_armies[0], sim)` 時讀到的是被拉回戰鬥中段的 `sim`，導致後半場死掉的兵全部復活帶進下一波。
* **建議修法**：
  在 `_finish_battle()` 首次結算當下（`play_kind == "official"`）就先算好 `wv_surv = wave_survivors(last_armies[0], sim)` 存起來；`_wave_next()` 改讀 `wv_surv` 而非即時讀 `sim`。

---

### 6. [中] 車輪戰：0 殘兵（靠召喚物贏）或低費殘兵時，`clampi` 會把預算免費補到 `BUDGET_MIN`
* **檔案與行**：`game/scripts/ui/screens/game_modes.gd:1342`
* **重現情境**：
  玩家在第 1 波原陣型單位全滅、靠召喚物獲勝（`wave_survivors` 不含召喚物，`surv` 為空、`cost = 0`），或殘兵花費極低，使得 `budget = cost + 15 < RuleSet.BUDGET_MIN`（例如 15 金 < 下限 50 金）。
  第 1342 行 `clampi(budget, RuleSet.BUDGET_MIN, RuleSet.BUDGET_MAX)` 會把玩家的預算直接補滿到 `RuleSet.BUDGET_MIN`，違反「預算＝殘兵花費＋15 整備」的規則（殘兵死光反而多拿免費金幣）。反之若無損過兩波使 `cost + 15 > RuleSet.BUDGET_MAX`，則會被截斷而吃掉應得的 15 金。
* **建議修法**：
  車輪戰的我方預算直接設為 `r.budget = [ maxi(budget, 15), WAVE_FOE[clampi(wv_no - 1, 0, 2)] ]`（或確保車輪戰不受一般大廳 `BUDGET_MIN` 下限拉高與 `BUDGET_MAX` 截斷影響）。

---

### 7. [中] 狀態洩漏：每日挑戰進車輪戰殘留 `daily_spec`、雙封蠟戰書回標題與結束再戰狀態異常
* **檔案與行**：`game/scripts/ui/screens/game_result.gd:20-25, 298-308`、`game/scripts/ui/screens/game_place.gd:28-32`、`game/scripts/ui/screens/game_modes.gd:1340-1348`
* **重現情境**：
  1. **每日挑戰 → 車輪戰**：`_start_mode(m)` 寫的是 `if m != Mode.VS_AI: set("daily_spec", {})`。玩家打完每日挑戰（`daily_spec` 非空）回主選單，再進遊戲間點「車輪戰」，`_wave_setup` 只清了 `challenge_army = null` 並呼叫 `_start_mode(Mode.VS_AI)`，`daily_spec` 不會被清空而殘留到車輪戰。
  2. **雙封蠟戰書 → 回標題**：`game_place.gd` 的 `_go_title()` 清了 `wv_active`、`wv_mode`、`wg_active`，但沒清 `sealed_on` 與 `sealed`。
  3. **雙封蠟戰書 → 結束後按「再來一局」**：`_draw_result()` 沒有為 `sealed_on` 客製再戰按鈕（不像 `wv_mode` 有 `wv_again`）。三戰兩勝打完後按結算畫面的再戰按鈕會呼叫 `_start_mode(Mode.DUEL)`，把 `sealed_on` 洗成 `false`，直接退化成普通單局雙人對決。
  4. **車輪戰 → 轉自由模式／練習**：若在車輪戰中途切到練習／自由模式使 `play_kind != "official"`，`_finish_battle()` 因判斷 `play_kind == "official"` 不會呼叫 `_wave_end`，但 `_draw_result()` 卻只看 `wv_mode` 和 `wv_active`，導致在非正式局贏了也能按「下一波」繼續推進車輪戰。
* **建議修法**：
  1. `_wave_setup()` 補上 `daily_spec = {}`。
  2. `_go_title()` 補上 `set("sealed_on", false)` 與 `set("sealed", [[], []])`。
  3. `_draw_result()` 在 `bool(get("sealed_on")) and mode == Mode.DUEL and series_over` 時，將再戰按鈕指向 `call("_sealed_start")`。
  4. `_draw_result()` 的「下一波」條件加上 `and play_kind == "official"`（或轉自由模式時清除 `wv_active` / `wv_mode`）。

---

### 8. [低] 玩法提示不足：雙封蠟第 3 封無換人提示、車輪戰無波數 HUD 與最佳紀錄顯示
* **檔案與行**：`game/scripts/ui/screens/game_place.gd:111-118, 553-557`、`game/scripts/ui/screens/game_modes.gd:1160-1172, 1373`
* **重現情境**：
  1. **雙封蠟戰書第 3 封沒提示**：`game_place.gd:111-114` 在封第 1、2 陣時會跳 `_toast(L.t("sealed_done", [sl.size()]))`（「第 X 封已上火漆，清空擺下一陣」），但藍方封完第 3 陣換紅方、以及紅方封完第 3 陣準備開戰時，直接 `return` 完全沒跳 toast，玩家容易不知道已經換紅方或已經全部封完。
  2. **雙封蠟戰書封完第 1 陣清空時未清復原堆疊（Undo）**：`game_place.gd:112` 只做 `_cur_army().units = []`，若部署畫面有復原（Undo）紀錄，封完第 1 陣後按復原可能會把上一封的兵叫回來。
  3. **車輪戰缺常駐波數 HUD 與紀錄展示**：車輪戰在部署畫面只有剛進去時的短暫 toast，上方 HUD（`_draw_place_hud`）沒有顯示「車輪戰 第 X／3 波」；且 `_wave_end` 寫入了 `Save.data["wave_best"]`，但遊戲間面板（`_draw_playroom`）完全沒把 `wave_best` 畫出來，玩家無從得知自己的最高紀錄。
* **建議修法**：
  1. 藍方封完第 3 陣時跳 `_toast` 提示換紅軍封陣；紅方封完第 3 陣時跳 `_toast` 提示雙方封陣完成。清空陣型時一併清空該方的部署 undo 紀錄。
  2. `_draw_place_hud()` 在 `wv_active` 時顯示波數與敵方預算；`_draw_playroom()` 顯示 `wave_best`（若 `> 0`）。
