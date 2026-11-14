# 落子無悔 No Take-Backs

Godot 4.6.2 確定性自動對決。**目前是 1.4.0「掌中劇場」（已實作並驗收）**：方案 `docs/2026-11-13-v1.4.0-plan.md`（文末 §21.2 實作進度表）、方案討論 `coordination/v140p/`、實作裁決 `coordination/v140-impl/ledger.md`（14 個方向分 12 批，各有 `catNN-plan.md` 與三方審查 `catNN-r1/`）；現況看 `docs/STATE.md`「1.4.0 掌中劇場」一節。測試函式尾碼 1.4.0 是 `_v140`（放進既有功能組）。1.4.0 的新單一來源：內距規則 R12／R13（`layout_rules.gd`，違規等級）、介面底層矩陣 `ui_xf`＋轉場輸入閘門 `_trans_gate`（`game_screens.gd`）、噪音預算 `FX_CLASS`（`battle_state.gd`）、即時配件 `SPRING`（`battle_units.gd`）、無盡塔 `scripts/game/tower.gd`、嘟囔語 `tools/gen/mumble_voice.py`。無盡塔 stash 已併進 1.4.0（stash 還留著，確認後可刪）。前一版 1.3.0「棋館活起來」：方案 `docs/2026-11-13-v1.3.0-plan.md`（文末 §21.1 實作進度表）、方案討論 `coordination/v130p/`、實作裁決 `coordination/v130-impl/ledger.md`（15 個方向分 13 批，各有 `catNN-plan.md` 與三方審查 `catNN-r1/`）；現況總覽看 `docs/STATE.md`「1.3.0 棋館活起來」一節。測試函式尾碼 1.3.0 是 `_v130`。新的單一來源：色票 `scripts/ui/palette.gd`（行內色碼有上限測試）、格內置中 R11（`layout_rules.gd`＋`optical_offsets.gd`）、器物 `OBJ_OF`＋`obj_extent`、導播純邏輯 `scripts/game/director_rules.gd`、每日老闆出題 `scripts/game/owner_daily.gd`、棋館環境音 `tools/gen/room_ambience.py`。前一版 1.2.0「一張桌上的戰爭」：方案 `docs/2026-11-11-v1.2.0-plan.md`（文末 §21 實作進度表）、方案討論 `coordination/v120p/`、實作裁決 `coordination/v120-impl/ledger.md`（11 大類，各有 `catNN-plan.md` 與三方審查 `catNN-r1/`）、擴充規則契約 `docs/rules-ext-v1.md`（新技能只在大廳「新技能」分頁＝沙盒；數值是 `battle_sim.gd` 的 `EXT_*`，改了升 `EXT_VERSION`）。測試函式尾碼 1.2.0 是 `_v120`（放進既有功能組）。姿勢資料 `data/poses/`（`tools/gen/pose_gen.py`）、材質 `art/mat/`（`tools/gen/materials.py`）、戰役 `data/campaign.json`（`tools/gen/campaign_gen.py`）。前一版 1.1.0：`docs/2026-11-11-v1.1.0-plan.md`、`coordination/v110-impl/ledger.md`；測試組 1.1.0 起依功能分（`coach_lab`、`share_codes`、`reports_platform`、`modes_live`、`battle_visual`）；純邏輯在 `scripts/game/playroom_rules.gd`、`screen_rules.gd`；背景工作共用 `scripts/game/bg_pool.gd`。前一版 V1.0.0（第一個公開正式版；內部 1.0.x～1.6.1 都併進來了）：`docs/2026-11-10-v1.0.0-plan.md`、`coordination/v100-impl/ledger.md`。現況只看 `docs/STATE.md`（V1.0.0 起按功能分節）；玩家看的更新說明 `CHANGELOG.md`；上架清單 `docs/release/steam-setup.md` F 節；代碼相容表 `docs/codes.md`；無障礙對照 `docs/accessibility.md`。各版方案（V1.1.0～V1.6.1、第七～十三輪）都在 `docs/history/`，裁決在 `coordination/*ledger*`，舊輪次不用讀。新字串用 `tools/gen/addstr.py`（寫 strings.csv 與 `build/tmp/v140/l10n/batch_v100.json`、`ja_v100.json`，並拿掉舊譯稿裡同鍵），否則 `l10n_build.py` 會蓋回英文。要使用者做的：Steam AppID 與後台（成就 37、排行榜（含 1.2.0 天梯 `rift_<週>_v3`）、雲端、商店頁、價格）、Deck 實機、母語校對（簡中優先）、盲聽、真人試玩（至少 5 人走完第一小時）、1.2.0 的錄音來源（真錄音、老闆語音）與美術原稿（關鍵美術、8 方向姿勢、新兵種、立繪）。1.3.0 還要：真錄音（木棋子、紙、蠟、布、黃銅、茶杯、棋館環境，換掉程序合成的 `audio/amb_room_*.wav`）、老闆與常客嘟囔語、分軌配樂授權、老闆立繪與常客的臉、5 方向原畫、商店素材與預告；真人看「桌邊視角」與器物介面。1.4.0 還要：嘟囔語真錄音（同名換 `audio/voice_*.wav`）、真人試轉場手感（滑入、跳過）、無盡塔難度曲線、標題主次與謝幕反應的觀感。

## 指令（在 game/ 下，GODOT 指向 Windows 版 4.6.2）
- 改動時：`python3 tools/check.py`（有快取，只跑受影響的）；更快：`--quick`。
- 驗收：`tools/check_all.sh`（全部重跑）。只取最後一行結論，細節在 `build/tmp/check/summary.json`。
- 版面：`tools/layout_check.sh <exe> <新資料夾>`（24 組：繁中、英文、簡中、日文 × 三字級＋簡化／色盲／手把／停用（150%，1.1.0 起 100／125% 也各有一組）＋日文狀態組；也查 R1～R10 排版規則）；`LAYOUT_QUICK=1` 跑 5 組；`LAYOUT_COMBOS="ja:150 …"` 只重跑指定組。會檢查文字對比（截圖取樣）、九宮格內距、缺圖，也走一次手把流程（`PADWALK`）。
- 1.2.0 驗收工具：`tools/audit_selection.sh <out>`（同 commit 有快取 vs 無快取逐步比對）；`tools/perf_ab.sh <A> <B> <輪數> <out>`（ABBA 交錯效能，輸出絕對路徑）；`PYTHONPATH=../build/pylibnp python3 tools/visual_diff.py <舊> <新> <out>`（像素差＋SSIM 接觸表；截圖模式固定幀時間與亂數，同一份程式重拍應該一致）；版面 `LAYOUT_JOBS=2`（預設）平行、`LAYOUT_SHOTS=a.png,b.png` 只拍指定畫面（開發用，驗收要全量）；新截圖要登記 `tools/screens.json`。完整檢查會核對測試 ID 聯集；重算作者解的測試有模擬快取（`tests/sim_cache.gd`，`--no-cache` 停用）。
- 試玩版流程用 `g.force_demo = true` 測，背景計算用 `g.force_async = true`，不必匯出。
- 匯出：`tools/export_check.sh <空資料夾>`。圖集：`tools/atlas_check.gd`（不能 headless）。
- 殘局量產（`tools/gen/*.py` 在專案根目錄、`.gd` 在 game/ 下）：草稿 `tools/gen/puzzle_drafts.py` → `tools/balance/puzzle_forge.gd`（爬山求解、訂星）→ `tools/gen/puzzle_tune.py`（自動調預算）→ `tools/gen/puzzle_merge.py`（併進 `data/puzzles.json`）。試煉：`tools/gen/trial_specs.py` → `tools/balance/trial_forge.gd` → `tools/gen/trial_merge.py`（寫 `data/trials.json`）。量產在 `build/cg/game` 快照跑。
- 其他流程用 skills：`ntb-check`、`ntb-review`、`ntb-balance`、`ntb-shots`、`ntb-unit`。

## 鐵則
- 舊場次位元組不能變：`FINGERPRINT b8fe741bcbfcf800`、舊 `digest` 不變；新東西走版本分流。
- 模擬只用整數，全部要左右鏡像；畫面狀態不能進模擬。
- 改中文字串要重建字型（`python3 tools/gen/build_font.py ../build/fontsrc`，來源字型在 `build/fontsrc`）；用語看 `docs/terms.md`。新增或改字串後跑 `PYTHONPATH=build/pylib17 python3 tools/gen/l10n_build.py build/tmp/v140/l10n`（在專案根目錄）補簡中、日文欄，退回英文的要送 Codex 翻（見 STATE）。
- 改數值（預設不改；要改先升 `RULES_VERSION`，見 STATE 版本契約）：跑平衡、新增新版金標準基準（舊基準不覆蓋，commit 說明）、重驗三星（`tools/balance/star_check.gd`、`trial_check.gd`，測試 `star_solutions` 會擋）。
- 手寫文字不寫死數值；技能說明用常數換值。
- 新測試登記在 `tests/run_tests.gd` 的 `FILES`（V1.1 起單一登錄；漏登記會直接失敗）。
- 字級只用字級表，不縮字。排版規則看 `docs/ui-layout-rules.md`（V1.5.2）：模態面板用 `modal_rect` 置中、標題下內容用 `_h1`／`_h1_help` 的回傳值起排（下緣＋16）、依附裝飾用 `btn_deco`＋`probe_deco`、多欄畫面 `probe_columns`、刻意例外 `probe_skip(規則, 理由)` 並寫進 `docs/ui-layout-exceptions.md`。版面檢查現在會查置中／貼齊／間距（R1～R10），但不看美感、不管 R5 卡片基準線；收尾仍要看接觸表（`tools/layout_sheet.py` 畫中線、用找錯的眼光），回報寫清楚檢查器管什麼、不管什麼。
- 暫存放 `build/tmp/`；東西不放專案外。
- 不跑 `--steam-test`；長時間可見視窗先問。
- commit 用 `git -c user.name=timmy -c user.email=pweihome@gmail.com`，做完推 `origin main`。
- 背景跑長工作時不要改 `game/`；要改先 `cp -r game build/cg/` 跑快照。
- WSL 的 timeout 砍不到 Windows Godot；`--script` 有解析錯誤會卡住，一律 `</dev/null` 加 timeout。

## 省 token
- 工具結果只讀最後一行；長日誌進檔，不進對話。
- 看圖先拼接觸表，不一張張讀。
- 找程式先看 `docs/MODULES.md`（模組索引，`python3 tools/gen/module_index.py` 重產），再 grep 加行號範圍，不整檔讀（`game_screens.gd` 很大）。
