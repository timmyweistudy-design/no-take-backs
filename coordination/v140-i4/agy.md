以下針對 V1.4.0（#4 軍令連鎖、#15 塗裝室、#17 簡中日文）進行代碼、狀態、邊界、在地化與介面審查：

---

### 一、 狀態錯誤與架構問題

#### 1. 【高】塗裝室未經「完成」離開（如按 Esc / 手把返回）會導致執行期塗裝髒掉且圖集與即時繪製不一致
- **位置**：`game_modes.gd` (`_paint_open` / `_paint_close` / `_paint_pick`)、`kit.gd` (`Art.paint`)、`sprite_cache.gd` (`is_ready`)
- **重現情境**：
  1. 進入塗裝室，點擊更換底漆或木座（`_paint_pick` 直接修改全域靜態陣列 `Art.paint[row] = k`）。
  2. 不點畫面下方的「完成」按鈕，而是按鍵盤 `Esc` 或手把返回鍵關閉 overlay（若全域返回邏輯直接將 `overlay = ""` 或切回 `"profile"` 而未經過 `_paint_close()`）。
  3. 此時 `Art.paint` 已被改動，但既沒有寫入 `Save.data["paint"]`，也沒有呼叫 `_rebuild_sprites()`。
  4. 進入戰鬥後：即時向量繪製的部分（例如 `ring_base` 木座、無快取時的向量單位）會畫出新塗裝；同時 `sprite_cache.is_ready(cb)` 因為 `ready_paint == Art.paint_sig()` 為 `false`，會導致戰鬥中拒絕使用已烘焙的快取圖集（或退回慢速向量繪製），且重開遊戲後設定又會跳回舊存檔。
- **建議修法**：
  - 全域 overlay 關閉攔截處若 `overlay == "paint"`，應強制呼叫 `_paint_close()`（或還原 `Art.paint`）。
  - 或者塗裝室 UI 操作暫存陣列 `pt_edit: Array`，只有按「完成」時才寫入 `Art.paint`、存檔並 `_rebuild_sprites()`；左侧預覽區在繪製時暫時套用 `pt_edit`。

#### 2. 【高】存檔清洗與邊界防護缺失：`Art.paint` 與 `_paint_apply()` 未夾限（Clamp），髒存檔會在 `team_color` 觸發越界崩潰
- **位置**：`game_modes.gd` (`_paint_apply`)、`kit.gd` (`team_color`)
- **重現情境**：
  1. 玩家手動修改存檔或舊版/異常存檔中 `Save.data["paint"]` 含有負數或超出範圍的整數（例如 `[99, -1, 5, 5, 9, 9]`）。
  2. `_paint_apply()` 僅檢查 `p is Array and p.size() == 6`，便直接 `Art.paint[i] = int(p[i])`，完全沒有根據 `PAINT_ROWS` 的上限或解鎖狀態做清洗。
  3. 雖然 `ring_base`、`battle_units.gd`、`sprite_cache.gd` 有用 `clampi` 防護，但 **`kit.gd` 的 `team_color` 沒有 `clampi`**：
     ```gdscript
     if not cb and int(paint[team]) > 0:
         return PAINTS[team][int(paint[team])] # 當 paint[0] >= 4 時直接 Array index out of bounds!
     ```
  4. 此外，若存檔裡的選項大於玩家目前的成就解鎖數（`paint_locked`），也會直接繞過成就鎖。
- **建議修法**：
  - `kit.gd` 的 `team_color` 改為 `var idx := clampi(int(paint[team]), 0, PAINTS[team].size() - 1)`。
  - `_paint_apply()` 載入時對每一欄做 `clampi(int(p[i]), 0, int(PAINT_ROWS[i][1]) - 1)`，若 `paint_locked` 為真則重置回 `0`。

#### 3. 【中】啟動載入順序風險：若 `_paint_apply()` 晚於首次 `sprite_cache.build()`，啟動時會白烘一次預設塗裝圖集
- **位置**：`game_modes.gd` (`_paint_apply`)、`sprite_cache.gd` (`build`)
- **重現情境**：
  - `Art.paint` 靜態初始值為 `[0, 0, 1, 1, 0, 0]`。若遊戲啟動時先觸發了 `sprite_cache.build(cb)`，之後才呼叫 `_paint_apply()` 載入玩家的塗裝設定，會導致啟動烘焙出的圖集簽章 `ready_paint` 與實際 `Art.paint_sig()` 不符，進場時發現 `is_ready(cb) == false` 又得重烘一次。
- **建議修法**：確保在 `Save.load_data()` 完成當下（或 `sprite_cache.build` 呼叫前）立即執行 `_paint_apply()`。

#### 4. 【中】字型子集產生器 `fontchars.py` 漏掃 `data/l10n_extra.csv` 的繁中原文與 `OVERRIDE` 字元
- **位置**：`game/tools/gen/fontchars.py` (`base_text` / `lang_text`)
- **重現情境**：
  1. `lang_text(root, col)` 只掃描 `strings.csv`、`l10n_extra.csv` 與 `data/*.json`。但如果某個字串在日文或簡中沒有翻譯（或佔位符不符被 `l10n_build.py` 退回英文/繁中），又或者玩家切到簡中/日文時遇到未翻譯的新增字串 fallback 到繁中，雖然字型設定了 `r2.fallbacks = [reg]`（落回繁中字型 `NTBRounded-R-sub.otf`），但若某個字只出現在動態組合或 `l10n_build.py` 的 `OVERRIDE`（例如 `"・"` 或特定日漢字），需確認子集有收錄。
  2. 更重要的是：`l10n_build.py` 在寫入 `strings.csv` 前若還沒跑過，或有人先跑子集工具再跑 `l10n_build.py`，字型子集就會漏字。
  3. `fontchars.py` 的 `lang_text` 中 `EXTRA + "“”"` 忘了加入單引號 `"‘’"`（而 `ui_base.gd` 的 `NO_LINE_HEAD` 有列 `’`），若譯文含全形單引號會缺字落回 fallback 字型導致字重/風格突兀。
- **建議修法**：`lang_text` 的 `EXTRA` 補齊 `"“”‘’—…"` 等常見標點，並確保建置流程中 `l10n_build.py` 必先於字型子集裁切執行。

#### 5. 【低】標題字型 `ThenKhung-sub.ttf` 在切換語言時重複原地修改資源加上 fallback
- **位置**：`game/scripts/ui/ui_base.gd` (`_load_fonts`)
- **重現情境**：
  - `r2` 和 `b2` 有做 `.duplicate()` 再設 `fallbacks`，但 `tk = load("res://fonts/ThenKhung-sub.ttf")` **沒有** `.duplicate()` 就直接 `tk.fallbacks = [bold]`。在設定頁連切語言時，`tk.fallbacks` 會一直被換成不同語言的 `bold`（SC / JP / TW），雖然當 `alt != ""` 時 `font_title = bold` 不會用到 `tk`，但切回 `zh_TW` 時汙染過快取的 `Resource` 在特殊情況下可能殘留引用。
- **建議修法**：對 `tk` 也做 `tk = tk.duplicate()`，或只在初始化時設定一次。

---

### 二、 邊界條件與邏輯錯誤（#4 軍令連鎖 & #15 塗裝室）

#### 6. 【高】`default_plan` 在多技能關卡可能產生超過 `lim` 或違反冷卻的預設排程，且 `plan_fix` 在調整單一技能時會連坐失敗
- **位置**：`game/scripts/game/puzzles.gd` (`default_plan`, `plan_fix`)
- **重現情境**：
  1. **預設排程未過濾**：`default_plan` 產生時間為 `CMD.START_TICKS + i * r.cmd_cd + k * 40`。若某關 `uses` 較多、`cmd_cd` 較長或有設定 `plan_min`（`default_plan` 完全沒看 `pz.get("plan_min", 0)`！），產生的預設 `puzzle_plan` 一開始就可能小於 `plan_min` 或大於 `goal_ticks - 10`。
  2. **連坐退回（Return original plan）**：當玩家在時間軸把某個技能往右推到接近局末（或點擊尺的右端），`plan_fix` 先用 `clampi` 把第 `i` 筆限制在 `[lo0, lim]`，接著後面的迴圈檢查：`var t := maxi(plan_tick(pz, int(p2[k])), maxi(lo0, last + cd))`。如果這是同技能的第 1 筆被推到太靠右，導致同技能的第 2 筆 `last + cd > lim`，`plan_fix` 會直接 `return plan`（整組退回原狀、完全不動），玩家點尺最右邊或按 `▶` 會覺得按鈕壞掉沒反應，而不是貼齊到「可允許的最大位置」。
- **建議修法**：
  1. `default_plan` 計算初始時間時應以 `maxi(CMD.START_TICKS, int(pz.get("plan_min", 0)))` 為起點，並在最後呼叫一次 `plan_fix(pz, out, -1, 0)` 確保合法。
  2. `plan_fix` 除了由左往右推（確保 `>= last + cd`），若最後一筆超過 `lim`，應改由右往左從 `lim` 倒推回壓（`t = mini(t, next_t - cd)`），只要倒推後第一筆仍 `>= lo0` 就成功，這樣玩家往右拉到底時才能平滑停在極限位置。

#### 7. 【中】切換不同殘局關卡時，`plan_sel` 未重置可能導致索引越界或無選取狀態
- **位置**：`game_place.gd` (`plan_sel`)
- **重現情境**：
  1. 玩家先玩一個多技能關卡（例如 `puzzle_plan.size() == 4`），點選了第 4 顆棋子（`plan_sel = 3`）。
  2. 退出並進入下一關單技能關卡（`puzzle_plan.size() == 1`）。
  3. 若進關卡時沒有將 `plan_sel = 0`，打開軍令時間軸時 `plan_sel` 仍為 `3`（`>= puzzle_plan.size()`）：此時沒有任何一顆木棋子有金框（`i == plan_sel` 皆為 false），下方的說明列與 `◀` `▶` 按鈕也會整個消失（因為 `if plan_sel >= 0 and plan_sel < puzzle_plan.size():` 為 false），點尺也無法移動任何棋子，手把玩家更無法透過 `◀` `▶` 操作！
- **建議修法**：在載入殘局關卡（設定 `puzzle_id` / `puzzle_plan`）或打開 `"puzzle_plan"` overlay 時，強制執行 `plan_sel = clampi(plan_sel, 0, maxi(0, puzzle_plan.size() - 1))`。

#### 8. 【中】軍令時間軸「木棋子」與「點尺移動」按鈕區域重疊，且不支援真正的「拖曳」
- **位置**：`game_place.gd` (`_draw_plan_timeline`)
- **重現情境**：
  1. **點擊衝突**：木棋子的中心在 `ruler.position.y + 26`，按鈕範圍是 `cpos - Vector2(16, 16)` 到 `+ Vector2(16, 16)`，也就是 `y` 從 `ruler.position.y + 10` 到 `ruler.position.y + 42`。尺的點擊區從 `ruler.position.y + 44` 開始，兩者剛好差 2px；但**尺的上半部（`y + 0` 到 `y + 44`）完全不能點尺移動**！玩家直覺會點擊「跟木棋子同一水平線（`y + 26`）」的尺面空白處來移動棋子，結果點在 `y + 26` 空白處毫無反應（因為尺的按鈕只綁在 `y + 44` 以下的冷卻帶區域）。
  2. **多顆棋子重疊時無法點選底下的棋子**：多技能關卡中，兩種不同技能可以設在同一個 `tick`（例如 3.0s 同時放冰凍與戰吼）。此時兩顆木棋子座標 `cpos` 完全重疊，點擊永遠只會選到後畫（或先攔截）的那一顆，另一顆永遠選不到！
  3. **規格不符**：更新說明寫「玩家在木刻度尺時間軸排施放時間（**拖曳**、◀▶ 微調）」，但程式碼裡只有把尺註冊進 `_btns`（單次點擊觸發 `cb`），**並沒有實作滑鼠按住拖曳（drag）**。
- **建議修法**：
  1. 將尺的點擊/拖曳感應區擴大涵蓋整個 `ruler`（只要沒點中其他木棋子就移動當前選取的棋子），並支援滑鼠按住時每幀更新位置。
  2. 當兩顆不同技能的棋子 `tick` 相同或過近（例如 `abs(xa - xb) < 18`）時，在垂直方向（y 軸）上下錯開繪製與碰撞框，或點擊已選取的棋子時循環切換同位置的下一顆棋子。

#### 9. 【低】連鎖提示（`chains_on`）在多次施放同組合時會重複列出相同名稱，且同 tick 雙發順序判定不穩
- **位置**：`game_place.gd` (`_draw_plan_timeline`)
- **重現情境**：
  1. 若關卡可使用 2 次冰凍、2 次隕石，玩家排了兩組「冰凍→隕石」，`chains_on` 陣列會塞入兩次 `"chain_freeze_meteor"`，下方文字會顯示：「連鎖：冰凍＋隕石、冰凍＋隕石」。
  2. 當技能 A 與技能 B 設在**同一個 tick**（`ta == tb`）時，`cmd_log` 的排序是 `a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])`（且 Python/GDScript `sort_custom` 依原本在 `puzzle_plan` 的順序），若在模擬中實際是 B 先放、A 後放（因為 B 在 `plan` 陣列前面），但 `_draw_plan_timeline` 的雙重迴圈 `for a ... for b ... if tb < ta ... continue` 在 `ta == tb` 時，`a` 在後、`b` 在前也會通過 `tb < ta`（因為 `tb == ta` 不小於），誤判為「先 A 後 B」而畫出假連鎖弧線。
- **建議修法**：
  1. `if not chains_on.has(str(ch[2])): chains_on.append(str(ch[2]))` 避免名稱重複。
  2. 當 `ta == tb` 時，應加上 `or (tb == ta and b < a)` 時 `continue`，確保與 `cmd_log` 實際執行順序一致。

---

### 三、 在地化工具與譯文品質問題（#17 簡中、日文）

#### 10. 【高】`l10n_build.py` 重跑時只取 `rows[0][:3]`，若未來 `strings.csv` 直接加新欄位或順序變動會截斷，且 `l10n_extract.py` 正則表達式漏抓含跳脫字元的二元陣列
- **位置**：`tools/gen/l10n_build.py`、`tools/gen/l10n_extract.py`
- **重現情境**：
  1. `l10n_extract.py` 的 `pair = re.compile(r'\[\s*"([^"]*[一-鿿][^"]*)"\s*,\s*"([^"]*)"\s*\]')`：如果陣列裡的英文或中文含有 `\"` 跳脫引號，會匹配失敗。
  2. `l10n_build.py` 的 `PH = re.compile(r"%[-+0-9.]*[sdf]|\{[A-Z0-9_]+\}")`：未處理 `%%`（百分比符號跳脫，如 `"戰力 %d%%"`）。在 `hud_power` 中，`PH.findall("戰力 %d%%")` 只會抓到 `['%d']`，但如果日文譯稿不小心把 `%d%%` 寫成 `%d%`（少一個 `%`），`PH.findall` 算出來還是 `['%d']`，檢查會放行！接著執行期 `strings.gd` 呼叫 `s % args` 時，Godot 的 `%` 格式化遇到孤立的 `%` 就會直接報錯崩潰（`Invalid format string`）！
- **建議修法**：
  - 在 `l10n_build.py` 的 `jp(item)` 檢查中，除了比對 `PH.findall`，還要檢查「移除合法 `%%` 與合法 `%...` 佔位符後，字串中是否還殘留單獨的 `%` 字元」，若有則判定為格式錯誤退回英文。

#### 11. 【高】簡中翻譯錯誤：把量詞「這隻」誤轉為「这只（僅僅）」，且殘留大量台灣慣用詞
- **位置**：`tools/gen/l10n_build.py` (`FIX`) 與簡中譯文抽樣
- **問題明細**：
  1. **`err_locked` 語意走鐘**：
     - 繁中：`這隻是關卡固定的兵`（「這隻」指這個單位，「是」為動詞）
     - 簡中：`这只是关卡固定的兵`
     - **問題**：OpenCC 將「隻」與「只」合併為「只」後，「这只是…」在簡體中文裡 100% 會被讀成「**這僅僅是**關卡固定的兵（This is merely a fixed unit）」，語意改變且不自然。大陸遊戲對士兵/棋子單位不用「只」（「只」用於貓狗蟲鳥），應改為「**这个是关卡固定的兵**」或「**该单位是关卡固定兵种**」。
  2. **`rv_remove` / `err_gold` / `lb_n_units` 量詞問題**：
     - 簡中：`拿掉这只`、`拿掉几只`、`%d 只`。在大陸戰棋/策略遊戲中，稱呼人形士兵或棋子為「几只」非常怪異（像在數動物），通常用「**名**」、「**个**」或直接說「**撤下该单位** / **撤下几个**」。
  3. **台灣用語殘留（OpenCC `tw2sp` 轉換過度或未轉）**：
     - `copy_code` / `code_bad` / `codes_hint`：OpenCC `tw2sp` 把「複製」全部轉成了「**拷贝**」（`拷贝目前阵型代码`、`请重新拷贝一次`、`先拷贝朋友给的代码`）。「拷贝」在大陸是老舊電腦術語（Copy file），日常與遊戲 UI 按鈕現在一律說「**复制**」（复制代码、重新复制）。
     - `copy_code`：「**目前**阵型代码」→ 簡中習慣用「**当前**阵型代码」。
     - `ph_apply`：繁中「擺上去」→ 簡中「摆上去」尚可，但「排军令」（`plan_open`）在簡中較生硬，可維持或作「编排军令」。
- **建議修法**：
  - 在 `l10n_build.py` 的 `FIX` 加入：
    `("拷贝", "复制"), ("这只是关卡", "这个是关卡"), ("拿掉这只", "撤下这个"), ("拿掉几只", "撤下几个")`

#### 12. 【中】日文譯文品質抽樣：機器翻譯痕跡、不自然詞彙與風格不一致
- **位置**：日文譯文抽樣、`tools/gen/l10n_build.py` (`OVERRIDE`)
- **問題明細**：
  1. **`rv_remove`（嚴重語法錯誤）**：
     - 繁中：`拿掉這隻`
     - 日文：`この体除外`
     - **問題**：日文的助數詞「体（たい）」**絕對不能**單獨當名詞配指示詞說「この体」（「この体」在日文是「這具身體 / 這種體態（からだ・てい）」的意思）！這是非常典型的 AI 字對字硬翻。
     - **建議改為**：`この兵を外す` 或 `撤去する`（若限 5 字內：`外す` / `この兵除外`）。
  2. **`pt_call`（語氣不自然）**：
     - 繁中：`我知道誰會贏了`
     - 日文：`勝つ側がわかった`
     - **問題**：「勝つ側（會贏的那一側）」是英文思維（winning side）的直譯，日文母語者在觀戰競猜時會說 `勝者がわかった` 或 `勝ち筋が見えた！` / `勝敗が見えた`。
  3. **`rv_moved`（方向詞不精確）**：
     - 繁中：`%s 往前後移了 %d 格`
     - 日文：`%sを前後に%dマス移動しました`
     - **問題**：日文「前後に移動しました」聽起來像「來回前後晃動了 N 格」。若是單次往前或往後移，應為 `%sを前後へ%dマス移動しました` 或 `%sを%dマス前後移動しました`。
  4. **`rv_you_free`（跨平台操作詞不一致）**：
     - 繁中：`你的陣型（點兵修改）`
     - 日文：`自軍陣形（兵タップで編集）`
     - **問題**：這是 PC (Steam) 為主、支援滑鼠與手把的遊戲，其他地方（如 `pf_ach_hint`「触れると条件表示」、`rv_hint_free`「ユニットを選んで…」）都避免講手機專用的「タップ（Tap）」，這裡卻突然冒出「タップ」。
     - **建議改為**：`自軍陣形（兵を選んで編集）` 或 `自軍陣形（クリックで編集）`。
  5. **`lb_pinfo_fantasy`（文體突兀）**：
     - 繁中：`傭兵公會開張：奇幻軍 10 種全部上場。還在驗收中，屬於娛樂變體。`
     - 日文：`傭兵ギルド開業です！魔物軍10種類が全員参戦します。まだ調整中のお楽しみルールです。`
     - **問題**：沙盤兵書風格的遊戲，突然用輕小說/手遊看板娘語氣「開業です！」，與其他冷靜硬派的說明（如 `codex_note`「古参兵の手記」）風格割裂。
     - **建議改為**：`傭兵ギルド解禁：魔物軍全10種が参戦。調整中のお遊びルールです。`
  6. **`err_locked`（術語不一致）**：
     - 繁中：`這隻是關卡固定的兵`
     - 日文：`詰め戦の固定ユニット`
     - **問題**：一下叫兵「兵（へい）」（`兵タップ`），一下叫「体」（`この体除外`），一下又叫外來語「ユニット（Unit）」。且把殘局翻成「詰め戦」（日文將棋/棋類殘局叫「詰め将棋」或「詰み」，自創詞「詰め戦」略顯生硬，且這是錯誤提示，只寫名詞片語沒寫「無法移動/撤除」）。

---

### 四、 介面易讀性與美術風格一致性

#### 13. 【中】設定頁移除了「（AI 翻譯・未校對）」的直觀標示，玩家在切換語言時容易忽略說明欄
- **位置**：`game/scripts/ui/screens/game_menus.gd` (`_settings_rows`)、`l10n_build.py`
- **重現情境**：
  - 在第一版 diff 中，`game_menus.gd` 原本在語言名稱旁顯示 `L.t("lang_name") + ("（%s）" % L.t("lang_unproofed") if L.lang in L.UNPROOFED else "")`，但在第二段 diff（`c07bb17..62e1a35`）又把它刪掉改回純 `L.t("lang_name")`，改放到 `sd_set_lang`（設定項目的下方小字說明）。
  - 同時 `strings.gd` 裡定義的 `const UNPROOFED := ["zh_CN", "ja"]` 及 `strings.csv` 裡的 `"lang_unproofed"` 瞬間變成**死代碼（Dead Code，全專案無任何地方引用）**！
- **建議修法**：若因按鈕寬度放不下而移到 `sd_set_lang`，應清理 `strings.gd` 的 `UNPROOFED` 與 `lang_unproofed` 避免死代碼；或者在設定頁右側預覽/說明區保留顯眼標記。

#### 14. 【低】塗裝室在开启「色盲模式」時，底漆按鈕仍可點擊切換，但左側預覽棋子顏色完全不會變
- **位置**：`game_modes.gd` (`_draw_paint`)
- **重現情境**：
  - 玩家開啟色盲模式（`cbm() == true`）後進入塗裝室。
  - 左側預覽棋盤呼叫 `Art.ring(..., cbm(), 1.5)` 與 `Art.unit(..., cbm())`，因為 `team_color` 在 `cb == true` 時強制回傳色盲色，所以玩家在右邊猛點「藍軍底漆」、「紅軍底漆」的 4 個色票時，色票上的金圈（`on`）會跟著動、也有音效，但**左邊預覽的棋子顏色完全不會變**（只有下方一行灰色小字 `paint_cb` 提示）。
- **建議修法**：當 `cbm() == true` 時，左側塗裝室預覽可考慮直接展示塗裝色（或同時併排顯示色盲色小圖示），或者將第 0、1 列底漆色票加上半透明遮罩標示「色盲模式停用中」，體驗更直覺。

#### 15. 【低】軍令連鎖組合（`chain_on`）在英文/日文版混用頓號 `"、".join(names)`
- **位置**：`game_place.gd` (`_draw_plan_timeline`)
- **重現情境**：
  - `_text(..., L.t("chain_on", ["、".join(names)]), ...)` 硬編碼使用全形頓號 `"、"` 連接多個連鎖名稱。當語言切為英文（`en`）時，兩個英文連鎖名稱中間會夾一個中式全形頓號 `"、"`，違反英文排版規範。
- **建議修法**：改用 `("、" if L.cjk() else ", ").join(names)`。
