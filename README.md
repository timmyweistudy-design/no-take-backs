# 落子無悔 No Take-Backs

可愛派兵自動對決（Steam 小品）。花 100 金擺好小軍隊，按下開戰就不能再動，只能看著它們打到最後一秒。

- 企劃 v1.0：[docs/2026-11-01-design-and-plan.md](docs/2026-11-01-design-and-plan.md)（§15 原型、§16 全面實作進度）
- 三方優化方案：[第一輪](docs/2026-11-01-optimization-plan.md)、[第二輪 v2](docs/2026-11-01-optimization-plan-v2.md)（§11 進度）、[第三輪 v3（方案，未實作）](docs/2026-11-01-optimization-plan-v3.md)
- 上架文件：[docs/release/](docs/release/)（商店頁、行銷與定價、法務、Steam 步驟）
- 真人試玩流程：[docs/playtest/protocol.md](docs/playtest/protocol.md)
- 第三方授權：[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)

## 怎麼玩
Windows：雙擊 `play.bat`；或用 Godot 4.6 開 `game/project.godot` 按 F5。

| 模式 | 內容 |
|---|---|
| 對 AI 快速對戰 | 簡單／普通／困難，三戰兩勝。困難 AI 第 2 局起會讀你上一局的陣型，用離線反制庫反制 |
| 同機雙人對決 | 輪流落子（5 手蛇行，預設）／輪流落子（每手 10 金）／約定盲擺 |
| 教學 3 關 | 騎兵衝弓手、盾在前刀在後、看到騎兵就補盾 |
| 殘局挑戰 10 關 | 固定敵陣＋有限預算；★ 獲勝 ★★ 剩餘戰力門檻 ★★★ 花費上限。每關都驗證過至少兩類解法 |
| 連勝遠征 | 7 連勝；贏了可以改最多 3 隻兵；敵人逐戰變強 |
| 兵種圖鑑 | 五兵種故事、技能說明（數值即時取自規則）、每個技能一段真模擬小劇場；派該兵種贏 5 場解鎖老兵筆記。標題選單、兵種卡 ?、手把 Select、結果頁都能開 |

| 操作 | 滑鼠 | 鍵盤 | 手把 |
|---|---|---|---|
| 選兵種 | 點兵種卡 | 1～5 | LB／RB |
| 擺放 | 點或拖到格子（按住可連續擺） | 方向鍵＋Enter | 十字鍵或左搖桿＋A |
| 移除 | 右鍵／拖出場外 | Backspace | X |
| 開戰／結束這一手 | 按鈕 | Space | Start |
| 返回 | 按鈕 | Esc | B |
| 圖鑑（擺放時） | 兵種卡右下 ? | F1 | Select |

設定：語言（繁中／English）、文字大小 100～150%、震動／慢動作／閃白開關、色盲高對比配色、預設觀戰速度、音量、雙人預設規則、全螢幕、試玩紀錄。

## 開發者
```bash
cd game
godot --headless --path . --script res://tests/run_tests.gd        # 規則測試（最後一行總結；FINGERPRINT 給跨平台比對）
godot --headless --path . --script res://tools/mirror_100.gd       # 100 組左右交換逐 tick 完整鏡像
SHARDS=18 tools/balance.sh ../docs/balance-runs/<名稱>              # 平衡工具 2.0（多行程；紅線不過 exit 1）
godot --headless --path . --script res://tools/validate_puzzles.gd # 13 關殘局／教學驗證（不過 exit 1）
godot --headless --path . --script res://tools/orbit_detect.gd     # 騎兵打轉偵測（A＝0、B≤8、C≤2，否則 exit 1）
python3 tools/check_assets.py                                      # 素材都要登記在 THIRD_PARTY_LICENSES.md
python3 tools/gen_audio.py                                         # 重新合成音效音樂
python3 tools/build_font.py <Noto 原檔資料夾>                        # 改了中文字要重跑字型子集
"<Godot win exe>" --path <game> --resolution 1280x800 -- --shot=<輸出資料夾>   # 各畫面截圖（不碰玩家存檔；可加 --shot-lang=en --shot-text=150）
"<Godot win exe>" --path <game> --resolution 1280x800 -- --perf=<輸出 json>  # 48 隻繪圖效能量測
```

| 位置 | 內容 |
|---|---|
| `game/scripts/core/` | 純邏輯：`battle_sim.gd`（五步 tick、全整數、SHA-256 完整狀態指紋、懸念指標、背水）、`unit_defs.gd`（**所有數值**）、`army.gd`（含陣型代碼）、`turn_placement.gd`（cap10／snake5／snake5c）、`ai_turns.gd`、`ai_army.gd`、`formations.gd`、`mirror_check.gd` |
| `game/scripts/game/` | 字串表、存檔設定（原子寫入）、音效、Steam 介面、關卡資料 |
| `game/scripts/ui/` | 繼承鏈 `ui_base` → `battle_view`（戰場、特效、展示緩衝）→ `codex_view`（圖鑑）→ `game_screens`（狀態機與各畫面）→ `main`（截圖、膠囊、影片、效能）；`art.gd`（程式繪製角色、三段式攻擊、表情）、`sprite_cache.gd`（圖集）、`view_buffer.gd`（畫面晚 2 tick） |
| `game/data/` | `strings.csv`、`puzzles.json`（含標準解）、`codex.json`（圖鑑）、`counter_lib.json`、`credits.txt` |
| `game/tools/` | 平衡工具 2.0（含刺客陣指標）、殘局驗證、鏡像 100、打轉偵測、音效合成、字型子集、素材檢查 |
| `.github/workflows/ci.yml` | 建好 GitHub repo 就會跑：測試＋鏡像＋素材檢查＋Windows／Linux 指紋比對 |
| `coordination/` | 三方協作紀錄 |
