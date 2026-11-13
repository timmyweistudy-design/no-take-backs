只讀靜態審查；未啟動 Godot，以免產生寫入。

必改：

1. **P1 獎盃架上下越界**：[ui_base.gd:1665](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1665) 搭配 `game_modes.gd:977` 的面板，金盃頂到 **y=-6**、托架底到 **y=814**。須收進 1280×800。
2. **P2 書籤撞手把提示列**：[ui_base.gd:1705](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1705)、1720：覆盤書籤到 y=792，大廳到 y=798；`game_screens.gd:899` 的提示列覆蓋 y=770～800。須保留裝飾與提示列間距。
3. **P2 驗收漏掉裝飾**：[ui_base.gd:1729](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1729) 只登記面板本體；`tests/suites/ui.gd:1595` 只查字串／映射，以上越界仍會通過。須納入裝飾邊界，補 24 組、手把、簡化及遮敵驗證。

其餘檢查：

- 設定提環約 x=78.5～1201.5，未見撞內容；標題、按鈕、捲動條未見新增靜態交疊。
- 簡化模式排除新器物、竹簾與摺痕（`ui_base:1749`、`game_place:324`、`game_result:119`）。
- 竹簾不透明本體沿用原 `mr`，自由／格子共用；簾頭額外外伸，故視覺範圍並非完全相同。隱藏兵直接跳過，迷霧只補畫已揭露兵（`game_v16:2200`）；白字底色已壓暗。
- 摺痕先畫、最大暗度 11%，未改文字座標／R11（`game_result:126`）。
- kind 借用完整；lobby／review 確實經 `game_menus:300、496、513` 設定。
- 色碼 483≤486；數值 RGB 新色未受棘輪約束。標準竹簾每幀約 **484 矩形＋96 圓**，效能仍須量測。

§8 尚缺：試煉仍是 tube；印泥開戰、郵戳互動、帳簿／標籤／木活字細節、各器物操作契約與風險矩陣證據。已裁決延後的幾何重排不列必改。

結論：有條件
