# 模組索引（自動產生，勿手改：`python3 tools/gen/module_index.py`）

找程式先看這裡，再用 grep 加行號範圍讀；大檔不要整檔讀。

## game/scripts/core

| 檔案 | 行數 | 說明 |
|---|---|---|
| `ai_army.gd` | 183 | AI 陣型（原型＝企劃 §7 的「普通」：從原型陣型挑一套再隨機微調）。 |
| `ai_turns.gd` | 192 | 會「讀對方」的落子 AI（優化方案 A2、C）。用在：輪流落子模式、平衡工具的先後手測試、AI 難度。 |
| `army.gd` | 596 | 一方的陣型：預算、人數上限、部署區、格子佔用。純資料，不碰畫面。 |
| `battle_sim.gd` | 2217 | 戰鬥核心（純邏輯、全整數、確定性）。企劃 §2.3、§2.4、§3.3；優化方案 B1、L1。 |
| `boss_defs.gd` | 16 | V1.4 #12 多格巨型頭目「巨獸」：只在遠征終點出現。用石魔（F8.GOLEM）當底子，陣型資料 u["boss"]＝1 就變巨獸 |
| `cmd_defs.gd` | 64 | 手動技能（第十二輪）：玩家戰鬥中按下的全隊技能。純資料、全整數。 |
| `events.gd` | 56 | 事件名稱表（第三輪 A4）：模擬送出的事件種類（kind）與效果標籤（tags）只能用這裡的常數。 |
| `fantasy_defs.gd` | 91 | 第八輪奇幻兵團的數值與常數。獨立成一個檔案：unit_defs.gd 的常數決定舊場次的數值摘要，一個都不能動。 |
| `formations.gd` | 246 | 陣型產生器（平衡工具 2.0 的訓練池／保留池，優化方案 B2）。全部由種子決定。 |
| `hard_ai.gd` | 97 | 困難 AI（第四輪）：真的「讀你上一局」。 |
| `imath.gd` | 25 | 確定性整數數學。GDScript 的 int/int 是「往 0 截斷」，左右鏡像時結果對稱，所以全部沿用。 |
| `map_defs.gd` | 110 | V9 地圖資料（純資料＋整數）：左半邊的矩形清單，右半邊自動鏡像，所以公平性由建構保證。 |
| `mirror_check.gd` | 155 | 左右交換逐 tick 比對（優化方案 B1／L1）：原本 (隊,列,欄) ↔ 鏡像 (1-隊,列,15-欄)，每 tick 比位置、血、面向、存活。 |
| `ruleset.gd` | 573 | 自訂規則（第五輪 §3）。純資料，不碰畫面。三層： |
| `sticker_defs.gd` | 24 | V1.4 #9 木座貼紙：貼在單隻兵木座底下的小能力。存在陣型資料 u["st"]（1～6），陣型代碼走 NTB6 每隻的第 4 個位元組。 |
| `terrain.gd` | 299 | V9 地形格（0.5 格一點）。所有查詢都用「隊伍視角」換算，左右鏡像才會逐位元一致： |
| `turn_placement.gd` | 209 | 輪流落子（企劃 §4.1、優化方案 A2）。公開輪流擺，擺下不能移動或收回；買得起就不能跳過。 |
| `unit_defs.gd` | 237 | ════════════════════════════════════════════════════════════════════ |

## game/scripts/game

| 檔案 | 行數 | 說明 |
|---|---|---|
| `battle_code.gd` | 115 | 對戰代碼（第三輪 F3）：把雙方陣型、規則版本、數值摘要編成一串，貼給朋友就能看同一場。 |
| `codex.gd` | 185 | 兵種圖鑑（第二輪方案 R3）：讀 data/codex.json，驗證 ID 與示範，技能說明裡的 {常數名} 換成 unit_defs 的數值。 |
| `daily.gd` | 116 | V1.1 D2：每日挑戰＋每週突變。純函式，不碰畫面（遊戲、測試共用）。 |
| `ghost_data.gd` | 12 | V1.4 #7 幽靈陣資料（data/ghosts.json）的快取。放在獨立檔：UI 繼承鏈上的 static var 會讓結束時資源洩漏（記憶：Godot 匯出陷阱）。 |
| `gif.gd` | 146 | V1.4 #14：極簡 GIF89a 編碼器（零依賴）。固定 252 色調色盤（紅 6 × 綠 7 × 藍 6），每格不抖色，LZW 壓縮，無限循環。 |
| `keymap.gd` | 106 | 按鍵重設（第七輪 K1、F9）。程式裡的按鍵判斷都用預設按鍵常數，這裡在入口把實際按下的鍵換回預設， |
| `presets.gd` | 130 | 第十輪 R1：試玩版開放的地圖（平原、雙橋河谷、冰湖雪原）與試煉（第 1、3 關）、殘局前 5 關。 |
| `puzzles.gd` | 347 | 教學與殘局關卡資料（data/puzzles.json）。 |
| `roster.gd` | 23 | 兵種開放（第十一輪）：不靠場數解鎖，正式版一開始 20 種全部能用。 |
| `save.gd` | 508 | 設定與進度存檔（優化方案 L1、N）：JSON、原子寫入（先寫暫存檔再改名）＋保留上一版備份。 |
| `sfx.gd` | 286 | 音效與音樂（優化方案 H）：同類音效 80ms 內最多 2 個、音高 ±10% 隨機；音樂與音效分軌。 |
| `steam.gd` | 239 | Steam 介面封裝（優化方案 N）：有 GodotSteam（Engine 單例 "Steam"）就用，沒有就只記在本機存檔。 |
| `strings.gd` | 105 | 字串表（優化方案 I）：data/strings.csv，欄位 key,zh_TW,en。所有畫面文字都從這裡來，不寫死在程式裡。 |
| `trial_data.gd` | 10 | 第十三輪：新增試煉（索引 ≥10）的資料快取，讀 data/trials.json。 |
| `workshop.gd` | 111 | V1.1 D3：殘局工坊碼 NTP1。打贏一場格子對戰 → 把敵陣＋自己的解做成殘局碼傳給朋友解。 |

## game/scripts/ui

| 檔案 | 行數 | 說明 |
|---|---|---|
| `art.gd` | 260 | 其他層在同資料夾（V9 P1 拆檔） |
| `battle_view.gd` | 816 | 其他層在同資料夾（V9 P1 拆檔） |
| `charts.gd` | 251 | 第五輪 §4.3 圖表元件。只用常見、一眼看得懂的圖；數字直接標在圖上，不用圖例。 |
| `codex_bake.gd` | 85 | V1.5.1 A6：圖鑑大圖也套戰場圖集的烘焙後處理（外框、漬洗、乾掃），轉身、背面、出手時畫風不突變。 |
| `codex_view.gd` | 808 | 兵種圖鑑（第二輪方案 R3）：五個兵種的故事、擅長／怕什麼、技能說明（數值取自 unit_defs）， |
| `free_place.gd` | 905 | 第六輪：自由排兵的操作與畫面（docs/2026-11-03-free-placement-plan-v6.md §4）。格子模式完全不經過這裡。 |
| `game_screens.gd` | 778 | 其他層在同資料夾（V9 P1 拆檔） |
| `icons.gd` | 172 | V9 P5 圖示：全部向量自繪，不靠字型（思源黑體沒有這些符號）。一律 24×24 概念，c＝中心、s＝邊長。 |
| `lobby_view.gd` | 1174 | 規則大廳（第五輪 §3.5、§3.6）。兩段式： |
| `main.gd` | 23 | 主場景腳本。出貨版只有遊戲本身；帶開發參數且專案裡有 tools/ 時，換成 tools/dev_main.gd（第七輪 H3）。 |
| `map_art.gd` | 386 | V9 地圖美術：每種 地圖＋大小 烘一張地面貼圖（全程式繪製，一張圖只畫一次，不佔每幀繪製）。 |
| `replay_view.gd` | 816 | 回味（第三輪 S5）：重播控制、對戰代碼、覆盤。 |
| `sprite_cache.gd` | 620 | 角色精靈圖快取（第二輪方案 R2、H；第八輪改分頁）：實測 48 隻時每幀直接程式繪製要 34ms（約 15fps）， |
| `ui_base.gd` | 1129 | 《落子無悔》UI 基底：共用常數、狀態、按鈕、文字、焦點、提示（第二輪方案 R2 從 main.gd 拆出）。 |
| `unit_brief.gd` | 116 | V1.1 E3：由 lobby_view.gd 拆出（行為不變）。選卡時的兵種簡介卡：大廳卡池、雙人禁牌共用。 |
| `view_buffer.gd` | 146 | 展示緩衝（第二輪方案 R5、§3）：戰鬥畫面固定比模擬晚 DELAY 個 tick。 |

## game/scripts/ui/battle

| 檔案 | 行數 | 說明 |
|---|---|---|
| `battle_fx.gd` | 749 | 由 battle_view.gd 拆出（V9 P1，行為不變） |
| `battle_state.gd` | 519 | 由 battle_view.gd 拆出（V9 P1，行為不變） |
| `battle_units.gd` | 1059 | 由 battle_view.gd 拆出（V9 P1，行為不變） |

## game/scripts/ui/screens

| 檔案 | 行數 | 說明 |
|---|---|---|
| `game_core.gd` | 862 | 由 game_screens.gd 拆出（V9 P1，行為不變） |
| `game_menus.gd` | 1268 | 由 game_screens.gd 拆出（V9 P1，行為不變） |
| `game_modes.gd` | 1960 | V9 P6 模式：主題試煉、挑戰碼、遠征獎勵、雙人禁選、戰績頁、牌組。 |
| `game_place.gd` | 938 | 由 game_screens.gd 拆出（V9 P1，行為不變） |
| `game_result.gd` | 724 | 由 game_screens.gd 拆出（V9 P1，行為不變） |

## game/scripts/ui/units

| 檔案 | 行數 | 說明 |
|---|---|---|
| `fantasy.gd` | 427 | 由 art.gd 拆出（V9 P1，行為不變） |
| `gait.gd` | 114 | 步態（V9 P2）：Q 版微跳步。相位由真實位移決定（battle_state._gait_tick），腳踩地時不滑。 |
| `kingdom.gd` | 419 | 由 art.gd 拆出（V9 P1，行為不變） |
| `kit.gd` | 268 | 由 art.gd 拆出（V9 P1，行為不變） |

## game/tests

| 檔案 | 行數 | 說明 |
|---|---|---|
| `run_tests.gd` | 96 | 測試入口（第七輪 I1 拆檔）：`godot --headless --path . --script res://tests/run_tests.gd [-- --only=<測 |
| `test_base.gd` | 243 | 測試共用（第七輪 I1）：斷言、常數、輔助函式。各主題的測試在 tests/suites/。 |

## game/tests/suites

| 檔案 | 行數 | 說明 |
|---|---|---|
| `anim.gd` | 117 | 角色動畫（V9 P2）：腳踩地不滑、被推與被吸的姿勢正確。 |
| `content.gd` | 116 | 殘局標準解回歸（第二輪方案 §1.4）：每關存的標準解都必須打贏；改戰鬥規則後有任何一關變不能過就會紅。 |
| `core.gd` | 552 |  |
| `fantasy.gd` | 498 | 擺一隊：spec＝[[type, x（自己視角）, y]]，team 0／1。座標單位 1000＝1 格。 |
| `free.gd` | 347 |  |
| `harness.gd` | 25 | 第七輪 R2：測試框架自己的契約。 |
| `maps.gd` | 149 | 地圖（V9 P3）：鏡像、可達、舊路徑不變、代碼、尋路不卡死。 |
| `modes.gd` | 1600 | V9 P6：試煉、挑戰碼、AI 性格、遠征獎勵、禁牌、戰績、牌組的核心邏輯。 |
| `rules.gd` | 584 |  |
| `save.gd` | 298 | 存檔遷移（第二輪方案 R8）：v1 進度不掉、補上 unit_wins、改用 schema_version；不認得的欄位保留；新版存檔不降版。 |
| `ui.gd` | 1389 | 戰鬥畫面的事件分流（Codex R3 審查 #1）：真實戰鬥出現的每一種事件都要分到合法的路線，攻擊一定帶 src／tgt／dmg， |
| `units.gd` | 394 |  |

## game/tools

| 檔案 | 行數 | 說明 |
|---|---|---|
| `anim_sheet.gd` | 112 | 角色全影格拼圖（V9 P2）：要真的繪圖，不能 headless。 |
| `atlas_check.gd` | 130 | 角色圖集檢查（第七輪 C0）：要真的繪圖，不能 headless。 |
| `codex_audit.gd` | 53 | V1.5 規劃用的角色檢查表（不改遊戲）：每種兵放大 2 倍（圖鑑同倍率），一列 8 格： |
| `compat.gd` | 143 | 舊兵種相容檢查（第四輪方案 §3.1～3.2）。 |
| `dev_main.gd` | 1639 | 開發工具入口（第七輪 H3，原 scripts/ui/main.gd）：自動截圖、版面報告、商店膠囊圖、實機影片、效能與記憶體量測。 |
| `golden.gd` | 113 | 確定性金標準（第三輪 T2）。 |
| `golden_free.gd` | 158 | 自由模式跨版本金標準（第七輪 S1）。舊金標準 golden.gd 只鎖格子舊路徑，自由模式原本只有同版自比。 |
| `golden_map.gd` | 130 | V9 金標準：鎖住有地圖或非標準大小的戰鬥。舊金標準不會走這些分支。 |
| `golden_v140.gd` | 34 | V1.4 審查（Codex v140-i5）：舊版本就有的幾種對局（自由排兵＋規則、地形圖、手動技能、奇幻軍）在新版指紋要一樣。 |
| `golden_v8.gd` | 163 | 第八輪金標準：鎖住有奇幻兵的戰鬥（舊金標準不會碰到 v8 分支）。案例存成對戰代碼 NTB4，所以同時鎖住代碼格式。 |
| `load_all.gd` | 26 | 載入檢查（第三輪 T1）：res://scripts、res://tools、res://tests 底下每一個 .gd 都要能載入、能編譯。 |
| `mirror_100.gd` | 21 | 100 組隨機陣型的左右交換逐 tick 比對（N1 驗收）。godot --headless --path game --script res://tools/mirror_10 |
| `orbit_detect.gd` | 84 | 騎兵打轉偵測（第二輪方案 §1.4）：訓練池 120 場，40 tick 內走了 >3 格但淨位移 <0.8 格就算一次。 |
| `perf_probe.gd` | 137 | 第五輪 P0：效能探測。人數上限、一局時間要依這裡的數字定，不憑感覺。 |
| `seal_codes.gd` | 63 | 第五輪 P0：封存舊格式對戰代碼（NTB2）＋預期結果。 |
| `unit_review.gd` | 95 | V1.5 角色驗收包：每種兵一個 GIF（和圖鑑一樣 2 倍）：正側面→轉向鏡頭→朝左→轉回來（16 格）＋ 一次完整攻擊（14 格：前搖、出手、後搖）＋ 待機小動作（6 格）。 |
| `validate_puzzles.gd` | 112 | 殘局／教學驗證（優化方案 D、附錄 A）：每關隨機抽樣擺法，檢查 |

## game/tools/balance

| 檔案 | 行數 | 說明 |
|---|---|---|
| `balance.gd` | 111 | 平衡報表（原型版）：godot --headless --path game --script res://tools/balance/balance.gd |
| `balance2.gd` | 253 | 平衡工具 2.0（優化方案 B2、A2、L2）。由 tools/balance/balance.sh 多行程分片呼叫，每場一行 JSON（前綴 "R "）。 |
| `boss_probe.gd` | 55 | V1.4 #12：巨獸平衡試算。godot --headless --path game --script res://tools/balance/boss_probe.gd -- |
| `cmd_eval.gd` | 52 | 手動技能強度（第十二輪）：同一對陣型左右各打一次，只有一邊會放這招（AI 判斷時機），看勝率。 |
| `design_new_puzzles.gd` | 131 | 新兵試玩殘局的設計輔助（第四輪 §4.8）。每關： |
| `fantasy_eval.gd` | 241 | 第八輪奇幻軍平衡驗收。godot --headless --path game --script res://tools/balance/fantasy_eval.gd -- -- |
| `ghost_forge.gd` | 52 | V1.4 #7：鍛造 30 個「名人幽靈陣」。每個 AI 模板 × 多個種子各組一支紅軍（100 金、標準規則）， |
| `make_counter_lib.gd` | 95 | 困難 AI 的離線反制庫（第三輪 A3）。 |
| `puzzle_forge.gd` | 279 | 第十三輪：殘局量產。讀草稿（敵陣、固定兵、預算、可用兵種、目標），自動： |
| `solve_fantasy.gd` | 102 | 奇幻軍試玩關的標準解搜尋（第八輪）。每關爬山找含主角兵種的解，印成 JSON；python 把解、星級寫回 puzzles.json。 |
| `star_check.gd` | 102 | 每一關的三星到底拿不拿得到（第十二輪）：先看標準解，沒有就爬山搜尋。印出最好的解。 |
| `trial_check.gd` | 113 | 主題試煉 10 關的星數拿不拿得到（第十二輪）：走遊戲同一條路開關（同一支對手），爬山找陣型。 |
| `trial_forge.gd` | 169 | 第十三輪：主題試煉第 11～30 關量產。依規格（tools/gen/trial_specs.py）： |
| `unit_eval.gd` | 281 | 新兵種驗收工具（第四輪方案 §2.6、§3.4）。由 tools/balance/unit_eval.sh 分片執行，tools/balance/unit_eval_report. |
