# 落子無悔 No Take-Backs

Godot 4.6.2 確定性自動對決。**下一版 V1.0.0（第一個公開正式版，把 1.0.x～1.6.1 併入）只有方案、還沒實作**：`docs/2026-11-10-v1.0.0-plan.md`（P0／P1／P2、22 兵表現表、五牌入口、回歸清單），討論與裁決 `coordination/v100d/`（五輪、`ledger.md`）。**V1.6.1（把 V1.6.0 做完整：正確性 F1～F8、補完 A1～A13、新手 N1～N6、D1／D2／D4／D7）已實作**：方案與進度 `docs/2026-11-10-v1.6.1-plan.md`（文末進度表）、裁決 `coordination/v161-impl/ledger.md`；測試組 `v161`。新字串的日文要放 `build/tmp/v140/l10n/ja_v161.json`（否則 `l10n_build.py` 會蓋回英文）。**V1.6.0（22 個方向全做：新手、回報、分享、教練、極速賽、裂隙、人設、熟練度、每日榜、擬音、地形 AI、出題台、一陣三考、迷霧、接力遠征、相鄰陣法）已實作**：方案與進度 `docs/2026-11-10-v1.6.0-plan.md` §3、裁決 `coordination/v160-impl/ledger.md`；V1.6 介面在 `game_v16.gd`、邏輯 `scripts/game/v16_*.gd`、測試組 `v16`。要使用者做的：Steam 後台（`docs/release/steam-setup.md` B2）、實機、母語校對。**V1.5.2（排版品質：偵測器 R1～R10＋守衛、L1～L11 全修、紅書籤 A 案）已實作**：規則 `docs/ui-layout-rules.md`、例外 `docs/ui-layout-exceptions.md`、方案與進度 `docs/2026-11-09-v1.5.2-plan.md` §7、裁決 `coordination/v152-impl/ledger.md`。下一步只剩外部驗收（見 STATE）。V1.5.1（返回目的地、戰績同口徑、22 種背面、轉身出手、圖鑑近看與小劇場遠程、設定收尾）已實作：方案與進度 `docs/2026-11-09-v1.5.1-plan.md` §I、紀錄與裁決 `coordination/v151-impl/ledger.md`。V1.5.0（客製化七頁、主畫面五塊木牌、角色握持與背面、遠程時間同步）已實作：方案與進度 `docs/2026-11-09-v1.5.0-plan.md` §8、裁決 `coordination/v150-impl/ledger.md`；角色驗收圖 `tools/unit_review.gd`（不能 headless）。V1.4.0（18 個新方向全做）已實作：方案與進度 `docs/2026-11-08-v1.4.0-plan.md` §3、裁決 `coordination/v140-ledger.md`；翻譯流程與新模組見 STATE。V1.3.1（角色做完整）已實作：方案與進度 `docs/2026-11-08-v1.3.1-plan.md` §8、裁決 `coordination/v131-ledger.md`。V1.3.0（去紙片感、手作感、好懂）已實作：方案與進度 `docs/2026-11-08-v1.3.0-plan.md` §10、裁決 `coordination/v130-ledger.md`。V1.2.1（細節優化）已實作：方案與進度 `docs/2026-11-07-v1.2.1-plan.md` §10、裁決 `coordination/v121-ledger.md`。V1.2.0（質感升級，零預算）已實作：方案與進度 `docs/2026-11-07-v1.2.0-plan.md` §11、裁決 `coordination/v120-ledger.md`。現況只看 `docs/STATE.md`；最新一輪 V1.1.0（動作、遠征路線、每日挑戰）方案與進度看 `docs/2026-11-06-v1.1.0-plan.md`（§11 進度）、裁決看 `coordination/v110-ledger.md`；上一輪（殘局 100、試煉 30）看 `docs/2026-11-06-puzzle-expansion-plan-v13.md`、`coordination/v13-ledger.md`。舊輪次不用讀。

## 指令（在 game/ 下，GODOT 指向 Windows 版 4.6.2）
- 改動時：`python3 tools/check.py`（有快取，只跑受影響的）；更快：`--quick`。
- 驗收：`tools/check_all.sh`（全部重跑）。只取最後一行結論，細節在 `build/tmp/check/summary.json`。
- 版面：`tools/layout_check.sh <exe> <新資料夾>`（21 組：繁中、英文、簡中、日文 × 三字級＋簡化／色盲／手把／停用＋日文狀態組；也查 R1～R10 排版規則）；`LAYOUT_QUICK=1` 跑 5 組；`LAYOUT_COMBOS="ja:150 …"` 只重跑指定組。會檢查文字對比（截圖取樣）、九宮格內距、缺圖，也走一次手把流程（`PADWALK`）。
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
