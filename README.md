# 落子無悔 No Take-Backs

可愛派兵自動對決（Steam 小品）。花固定的錢擺好小軍隊，按下開戰就不能再動，只能看著它們打到最後幾秒。

- 完整企劃（三方共同擬定 v1.0）：[docs/2026-11-01-design-and-plan.md](docs/2026-11-01-design-and-plan.md)
- 目前階段：**火柴人原型**（2026-11-01）——沒有美術素材，全部用程式畫。

## 怎麼玩原型

Windows：雙擊 `play.bat`。
或用 Godot 4.6 開 `game/project.godot` 按 F5。

| 操作 | 對 AI 模式 | 輪流落子（兩人） |
|---|---|---|
| 擺兵 | 點下方兵種卡，再點／拖到左邊藍色區（按住拖過格子可以連續擺） | 一樣；藍紅輪流，每一手 1～10 金、至少 1 隻 |
| 移動／移除 | 拖動已擺的兵；拖出場外或右鍵移除 | **不能**（落子無悔） |
| 開戰 | 「開戰！」；AI 的陣型開戰後才揭曉 | 雙方都擺完後「開戰！」 |
| 觀戰 | 速度 1×／2×／4×、直接看結果 | 同左 |
| 結果 | 下一局（保留你的陣型）、重播（同一場一定一模一樣）；三戰兩勝 | 同左 |

## 開發者

```bash
# 核心測試（Linux headless）；最後一行是總結，FINGERPRINT 用來跟 Windows 比對
cd game && godot --headless --path . --script res://tests/run_tests.gd
# 平衡報表（約 4 分鐘）
cd game && godot --headless --path . --script res://tools/balance.gd
# 截圖（要真的渲染，用 Windows exe）
"<Godot win exe>" --path <game 的 Windows 路徑> --resolution 1280x800 -- --shot=<輸出資料夾 Windows 絕對路徑>
```

| 位置 | 內容 |
|---|---|
| `game/scripts/core/` | 純邏輯核心：`battle_sim.gd`（五步 tick、全整數、確定性）、`army.gd`、`unit_defs.gd`、`turn_placement.gd`、`ai_army.gd`、`imath.gd` |
| `game/scripts/ui/main.gd` | 擺放、戰鬥演出、火柴人繪製、結果畫面（只演出，不影響勝負） |
| `game/tests/run_tests.gd` | 27 項核心測試 |
| `game/tools/balance.gd` | 兵種矩陣＋AI 陣型聯賽 |
| `docs/prototype-shots/` | 原型截圖 |
| `docs/prototype-balance.txt` | 最新平衡報表 |
| `coordination/` | 三方協作紀錄（plan-r1、plan-r2 企劃輪；proto-r1 原型程式輪） |
