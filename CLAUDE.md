# 落子無悔 No Take-Backs

Godot 4.6.2 確定性自動對決。現況只看 `docs/STATE.md`；最新一輪（殘局 100、試煉 30）方案與進度看 `docs/2026-11-06-puzzle-expansion-plan-v13.md`（§16 進度）、裁決看 `coordination/v13-ledger.md`；更早的看 `docs/2026-11-05-v1-polish-plan-v10.md`、`coordination/v10-ledger.md`。舊輪次不用讀。下一版 V1.1.0 方案（未實作）：`docs/2026-11-06-v1.1.0-plan.md`、裁決 `coordination/v110-ledger.md`。

## 指令（在 game/ 下，GODOT 指向 Windows 版 4.6.2）
- 改動時：`python3 tools/check.py`（有快取，只跑受影響的）；更快：`--quick`。
- 驗收：`tools/check_all.sh`（全部重跑）。只取最後一行結論，細節在 `build/tmp/check/summary.json`。
- 版面：`tools/layout_check.sh <exe> <新資料夾>`；`LAYOUT_QUICK=1` 只跑 2 組。也會走一次手把流程（`PADWALK`）。
- 試玩版流程用 `g.force_demo = true` 測，背景計算用 `g.force_async = true`，不必匯出。
- 匯出：`tools/export_check.sh <空資料夾>`。圖集：`tools/atlas_check.gd`（不能 headless）。
- 殘局量產（`tools/gen/*.py` 在專案根目錄、`.gd` 在 game/ 下）：草稿 `tools/gen/puzzle_drafts.py` → `tools/balance/puzzle_forge.gd`（爬山求解、訂星）→ `tools/gen/puzzle_tune.py`（自動調預算）→ `tools/gen/puzzle_merge.py`（併進 `data/puzzles.json`）。試煉：`tools/gen/trial_specs.py` → `tools/balance/trial_forge.gd` → `tools/gen/trial_merge.py`（寫 `data/trials.json`）。量產在 `build/cg/game` 快照跑。
- 其他流程用 skills：`ntb-check`、`ntb-review`、`ntb-balance`、`ntb-shots`、`ntb-unit`。

## 鐵則
- 舊場次位元組不能變：`FINGERPRINT b8fe741bcbfcf800`、舊 `digest` 不變；新東西走版本分流。
- 模擬只用整數，全部要左右鏡像；畫面狀態不能進模擬。
- 改中文字串要重建字型（`python3 tools/gen/build_font.py ../build/fontsrc`，來源字型在 `build/fontsrc`）；用語看 `docs/terms.md`。
- 改數值（預設不改；要改先升 `RULES_VERSION`，見 STATE 版本契約）：跑平衡、新增新版金標準基準（舊基準不覆蓋，commit 說明）、重驗三星（`tools/balance/star_check.gd`、`trial_check.gd`，測試 `star_solutions` 會擋）。
- 手寫文字不寫死數值；技能說明用常數換值。
- 新測試登記在 `tests/run_tests.gd` 的 `FILES`（V1.1 起單一登錄；漏登記會直接失敗）。
- 字級只用字級表，不縮字；版面檢查不看圖，收尾要看截圖。
- 暫存放 `build/tmp/`；東西不放專案外。
- 不跑 `--steam-test`；長時間可見視窗先問。
- commit 用 `git -c user.name=timmy -c user.email=pweihome@gmail.com`，做完推 `origin main`。
- 背景跑長工作時不要改 `game/`；要改先 `cp -r game build/cg/` 跑快照。
- WSL 的 timeout 砍不到 Windows Godot；`--script` 有解析錯誤會卡住，一律 `</dev/null` 加 timeout。

## 省 token
- 工具結果只讀最後一行；長日誌進檔，不進對話。
- 看圖先拼接觸表，不一張張讀。
- 找程式先看 `docs/MODULES.md`（模組索引，`python3 tools/gen/module_index.py` 重產），再 grep 加行號範圍，不整檔讀（`game_screens.gd` 很大）。
