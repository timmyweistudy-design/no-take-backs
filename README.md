# 落子無悔 No Take-Backs

可愛派兵自動對決（Steam 小品）。花 100 金擺好小軍隊，按下開戰就不能再動，只能看著它們打到最後一秒。

- 企劃 v1.0：[docs/2026-11-01-design-and-plan.md](docs/2026-11-01-design-and-plan.md)（§15 原型、§16 全面實作進度）
- 第九輪 V1.0 正式版方案（未實作）：[docs/2026-11-04-v1-release-plan-v9.md](docs/2026-11-04-v1-release-plan-v9.md)
- 第八輪奇幻兵團（再加 10 種兵，已完成）：[方案與進度](docs/history/2026-11-04-fantasy-units-plan-v8.md) §12；現況看 [docs/STATE.md](docs/STATE.md)
- 三方優化方案：[第一輪](docs/history/2026-11-01-optimization-plan.md)、[第二輪 v2](docs/history/2026-11-01-optimization-plan-v2.md)（§11 進度）、[第三輪 v3](docs/history/2026-11-01-optimization-plan-v3.md)（§15 進度：可信、混戰、讀得懂、覆盤、門面）、[第四輪 v4：新增五種兵](docs/history/2026-11-02-new-units-plan-v4.md)（§12 進度）、[第五輪 v5：自訂規則＋版面大整理](docs/history/2026-11-03-custom-rules-and-ui-plan-v5.md)（§11 進度）、[第六輪 v6：捨棄格子、自由排兵](docs/history/2026-11-03-free-placement-plan-v6.md)（§11 進度）、[第七輪 v7：綜合大優化方案](docs/history/2026-11-04-grand-optimization-plan-v7.md)（§20 實作進度）、[第八輪 v8：奇幻兵團（再加 10 種兵）](docs/history/2026-11-04-fantasy-units-plan-v8.md)（定稿、未實作）
- **現在的規則與數值：[docs/STATE.md](docs/STATE.md)**；用語表：[docs/terms.md](docs/terms.md)
- 上架文件：[docs/release/](docs/release/)（商店頁、行銷與定價、法務、Steam 步驟、[手動驗收清單](docs/release/manual-checklist.md)、[預告片腳本](docs/release/trailer-30s.md)）
- 真人試玩流程：[docs/playtest/protocol.md](docs/playtest/protocol.md)
- 第三方授權：[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)

## 怎麼玩
Windows：雙擊 `play.bat`；或用 Godot 4.6 開 `game/project.godot` 按 F5。

| 模式 | 內容 |
|---|---|
| 自由排兵（第六輪） | 大廳預設不用格子：按住拖曳＝畫筆沿路擺兵（放開才落下、Shift 直線、G 對齊）、按住已擺的兵拖動、右鍵／拖出場外移除、Ctrl＋Z 復原；選取工具或 Ctrl＋拖曳框住一群一起搬、M 上下翻轉、Delete 刪除。部署分頁可換回格子、調最小間距 0.6～1.0 格與縱深 6～7.5 格；「全場」娛樂變體：對 AI 明牌全場（AI 先擺好公開，你在全場離敵兵 1.5 格外擺）、雙人輪流全場（沒位置自動跳手） |
| 規則大廳（第五輪） | 對 AI、雙人開戰前選規則：6 個預設（標準、經典 5 種、奇幻兵團、小規模快打、大軍團、單兵種對決）＋最多 5 組「我的預設」；按「自訂細項」可調金幣 30～200、讓子、人數上限 4～40、單種上限、卡池（玩家與 AI 各自）、一局 60～150 秒、局數 1／3／5／7、落子方式與手數、剩錢累積、保留陣型、AI 難度、沙盒（兵種血／攻／速 50～200%、12 個技能開關）。徽章：平衡認證／娛樂變體／沙盒。規則代碼可複製分享 |
| 對 AI 快速對戰 | 簡單／普通／困難。困難 AI 第 2 局起會讀你上一局的陣型（反制庫只在標準規則用） |
| 同機雙人對決 | 輪流落子（公平輪序，預設 5 手）／每手 10 金／同時暗擺／自訂手數；落子要點兩下（可關），擺下不能收回 |
| 教學 3 關 | 騎兵衝弓手、盾在前刀在後、看到騎兵就補盾 |
| 殘局挑戰 10 關＋新兵試玩 5 關＋奇幻軍試玩 10 關 | 固定敵陣＋有限預算；★ 獲勝 ★★ 剩餘戰力門檻 ★★★ 花費上限。經典殘局每關驗證過至少兩類解法；新兵試玩每關都要用到那種新兵（兵種解鎖後才能玩） |
| 連勝遠征 | 7 連勝；開打前選王國軍／奇幻軍／上次名單；贏了可以改最多 3 隻兵；敵人逐戰變強 |
| 重播與覆盤 | 重播可暫停、變速、點時間軸跳到任一秒、點兵跟拍；對 AI 輸了可以「覆盤」改一隻兵看結果（不算戰績）；結果頁可複製對戰代碼，標題可觀看 |
| 兵種圖鑑 | 王國軍、奇幻軍兩頁共 20 種故事、技能說明（數值即時取自規則）、每個技能一段真模擬小劇場；派該兵種贏 5 場解鎖老兵筆記。標題選單、兵種卡 ?、手把 Select、結果頁都能開 |

| 操作 | 滑鼠 | 鍵盤 | 手把 |
|---|---|---|---|
| 選兵種 | 點兵種卡 | 1～9、0 | LB／RB |
| 擺放 | 點或拖到格子（按住可連續擺）；自由排兵＝按住拖曳畫一排 | 方向鍵＋Enter | 十字鍵或左搖桿＋A（自由排兵：按住 A 移搖桿畫、LT＋A 框選、L3 對齊、R3 密集） |
| 移除 | 右鍵／拖出場外 | Backspace | X |
| 開戰／結束這一手 | 按鈕 | Space | Start |
| 返回 | 按鈕 | Esc | B |
| 圖鑑（擺放時） | 兵種卡右下 ? | F1 | Select |

兵種：經典 5 種（劍士、盾兵、弓箭手、騎兵、刺客）＋第四輪 5 種（長槍兵、投彈兵、醫者、鼓手、狂戰士）＋第八輪奇幻軍 10 種（孢子菇、爆爆羊、寶箱怪、史萊姆、幽靈、巫毒娃娃、沙漏精靈、骷髏法師、吸塵貓、小石魔），一局每邊最多選 10 種上場。新兵依累計場數解鎖（3／5／7／9／11 場，標準與自訂局都算）；設定可「全部解鎖」；試玩版開放到投彈兵。

紀錄：平衡認證規則的對局算標準戰績與成就；其他自訂規則記在自訂戰績（另有 3 個自訂成就）；沙盒不記。

設定（四組分頁＋說明欄）：畫面（語言、文字大小 100／125／150%、標題用一般字型、全螢幕）、聲音、操作（觀戰速度、雙人點兩下落子、全部解鎖、試玩紀錄）、輔助（色盲高對比、震動、慢動作、閃白）。

字型：內文思源黑體 TC；標題（≥22px）UoqMunThenKhung；數字等寬。字級只用字級表的值（100% 時 14／15／17／22／32／64／84）。

## 開發者
```bash
cd game
GODOT=<Godot 4.6.2> tools/check_all.sh                              # 統一檢查：引擎版本、匯入、載入、啟動、測試、鏡像、金標準 1000 場（鎖檔）、自由模式金標準 120 場、舊兵相容 1000 場、封存的舊對戰代碼、打轉、字串表、素材、字型涵蓋（CI 也用它）
tools/check_quick.sh                                               # 快速檢查（改動時用，不取代統一檢查）
godot --headless --path . --script res://tools/golden_v8.gd           # 第八輪金標準 60 場（有新兵的戰鬥，check_all 也會跑）
SHARDS=14 tools/fantasy_eval.sh <army|cheese|core|repl> <輸出檔>          # 奇幻兵平衡；repl 要 --bases=24 --opp=14
GODOT=<Godot win exe> tools/export_check.sh <空資料夾>                # 匯出正式版、試玩版（有模板時加 Linux），對成品跑 --self-check
"<Godot win exe>" --path <game> --script res://tools/atlas_check.gd -- --out=<資料夾>  # 角色圖集：超框、隊伍色比例、剪影重疊、接觸表
python3 tools/check_strings.py                                     # 字串表：欄數、重複鍵、空翻譯、參數、用語表、不存在的鍵、Steam 成就清單
python3 tools/playtest_report.py <資料夾>                            # 彙整試玩紀錄（session＋game 去重）
python3 tools/archive_runs.py [--verify-only]                      # 實驗分片封存；還原看各實驗的 archive.manifest
godot --headless --path . --script res://tests/run_tests.gd -- --only=<組>   # 測試組＝tests/suites/ 的檔名：core、content、ui、units（new）、rules、free、save、harness；未知或 0 項都會失敗
SHARDS=17 tools/free_screen.sh ../docs/balance-runs/<名稱>                       # 第六輪間距×縱深全因子篩選；python3 tools/free_screen_report.py 彙整
FREE=800,6000 NTYPES=10 SHARDS=16 tools/unit_eval.sh …                          # 自由陣型版的完整驗收
godot --headless --path . --script res://tools/perf_probe.gd       # 大軍、支援兵密集、困難 AI 的模擬耗時（定人數上限用）
NTYPES=10 SHARDS=19 tools/unit_eval.sh ../docs/balance-runs/<名稱> core repl:0 repl:3 repl:4 repl:5 …  # 新兵種驗收（核心剋制、替換實驗＋經典範圍、盾牆池、覆蓋曲線）
godot --headless --path . --script res://tools/compat.gd -- --n=1000  # 舊 5 種兵逐 tick 相容（加新兵不能改到舊兵）
godot --headless --path . --script res://tests/run_tests.gd        # 規則測試（最後一行總結；FINGERPRINT 給跨平台比對）
godot --headless --path . --script res://tools/golden.gd -- --make # 刻意改規則後重產金標準（要在 commit 說明）
tools/layout_check.sh "<Godot win exe>" <新資料夾>                  # 版面檢查：兩語言 × 三字級；重疊、越界、表外字級、小於 14、點擊框 <36、按鈕互撞、文字段數上限、畫面集合
godot --headless --path . --script res://tools/make_counter_lib.gd # 重產困難 AI 反制庫（改平衡後要跑）
godot --headless --path . --script res://tools/mirror_100.gd       # 100 組左右交換逐 tick 完整鏡像
SHARDS=18 tools/balance.sh ../docs/balance-runs/<名稱>              # 平衡工具 2.0（多行程；紅線不過 exit 1）
godot --headless --path . --script res://tools/validate_puzzles.gd # 18 關殘局／教學／新兵試玩驗證（不過 exit 1）
godot --headless --path . --script res://tools/orbit_detect.gd     # 騎兵打轉偵測（A＝0、B≤8、C≤2，否則 exit 1）
python3 tools/check_assets.py                                      # 素材都要登記在 THIRD_PARTY_LICENSES.md
python3 tools/gen_audio.py                                         # 重新合成音效音樂
python3 tools/build_font.py <字型原檔資料夾>                          # 改了中文字要重跑字型子集（Noto Regular／Bold＋ThenKhung-Regular.ttf）
python3 tools/check_font_coverage.py                               # 子集缺字就失敗
"<Godot win exe>" --path <game> --resolution 1280x800 -- --shot=<輸出資料夾>   # 各畫面截圖（不碰玩家存檔；可加 --shot-lang=en --shot-text=150）
"<Godot win exe>" --path <game> --resolution 1280x800 -- --perf=<輸出 json>  # 48 隻整場效能量測
"<Godot win exe>" --path <game> --resolution 1280x800 -- --mem-check=<輸出 json>  # 記憶體不成長檢查
```

| 位置 | 內容 |
|---|---|
| `game/scripts/core/` | 純邏輯：`battle_sim.gd`（五步 tick、全整數、SHA-256 完整狀態指紋、懸念指標、背水；可選規則：一局長度、讓子判定、沙盒）、`ruleset.gd`（第五輪規則物件、驗證、規則代碼 NTBR1／第六輪 NTBR2：部署、間距、縱深、全場）、`unit_defs.gd`（**所有數值**）、`army.gd`（含陣型代碼 NTB1／第六輪自由座標 NTB5、量化、has_room）、`turn_placement.gd`（cap10／snake5／snake5c）、`ai_turns.gd`、`ai_army.gd`、`formations.gd`、`mirror_check.gd` |
| `game/scripts/game/` | 字串表、存檔設定（原子寫入）、音效、Steam 介面、關卡資料 |
| `game/scripts/ui/` | 繼承鏈 `ui_base`（字級表、三種字型角色、換行）→ `battle_view`（戰場、特效、展示緩衝）→ `codex_view`（圖鑑）→ `replay_view`（重播控制、覆盤、對戰代碼）→ `lobby_view`（規則大廳）→ `free_place`（第六輪自由排兵：畫筆、框選、搬群、手把、禁區）→ `game_screens`（狀態機與各畫面）→ `main`（出貨入口；開發參數換成 `tools/dev_main.gd`：截圖、膠囊、影片、效能）；`charts.gd`（中線對比長條、排名條、戰力走勢、金幣條）、`art.gd`（程式繪製角色、三段式攻擊、表情）、`sprite_cache.gd`（圖集）、`view_buffer.gd`（畫面晚 2 tick） |
| `game/data/` | `strings.csv`、`puzzles.json`（含標準解）、`codex.json`（圖鑑）、`counter_lib.json`、`credits.txt` |
| `game/tools/` | 平衡工具 2.0（含刺客陣指標）、殘局驗證、鏡像 100、打轉偵測、音效合成、字型子集、素材檢查 |
| `.github/workflows/ci.yml` | 建好 GitHub repo 就會跑：測試＋鏡像＋素材檢查＋Windows／Linux 指紋比對 |
| `coordination/` | 三方協作紀錄 |
