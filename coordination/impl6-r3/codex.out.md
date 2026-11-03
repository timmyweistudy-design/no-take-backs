已依 `git diff HEAD~1 -- game/scripts game/tests` 核對第二輪未修項目。判定如下：

| 第二輪項目 | 判定 | 核對結果 |
|---|---|---|
| Codex #2 | 已修好 | 放開入口重新檢查鎖定，準備／開戰前清除拖曳。`free_place.gd:351`、`game_screens.gd:234` |
| Codex #5 | 已修好 | 雙人全場允許空軍隊進入結算，模擬第 0 tick 依戰鬥兵有無判勝／和。`game_screens.gd:250`、`battle_sim.gd:180` |
| Codex #8 | 已修好 | 成功載入與清空均清除 `fp_sel`。`game_screens.gd:1608、1624、1831` |
| Codex #9／新增問題 1 | 已修好 | 畫筆、搬移及框選途中按 Enter 均直接返回。`free_place.gd:408` |
| Codex #10 | 已依調整規格處理 | 仍拒絕 `cmds`，規格已明示功能延後；不再列為缺陷。`battle_code.gd:77`、規格第 143 行 |
| Antigravity #1 | 已修好 | 同 Codex #8，載入後不再沿用舊選取索引。 |
| Antigravity #2 | **部分修好** | 覆蓋層已開啟時放開手把會清理，但同幀開啟覆蓋層仍有漏接，詳見下方。 |
| Antigravity #3／新增問題 2 | 已修好 | 群組預覽使用 `move_group()` 回傳的夾限後位移。`free_place.gd:636–641` |
| Antigravity #6 | **未完全修好** | 禁區融合與裁界已完成；正式 Toast 位置仍未修改。 |
| Antigravity #8 | 已修好 | `fp_fine` 跨事件保留，開始新筆畫才重設。`free_place.gd:103、167–174` |

最後仍有兩項問題：

1. **[P2] 同幀開啟覆蓋層並放開手把，仍會殘留拖曳／擦除狀態。**  
   按住 A／X，於同一幀先按 F1、再放開 A／X：輸入收集時覆蓋層尚未開啟，放開事件會排入佇列；執行 F1 後世代改變，舊事件分支只替滑鼠放開做清理，手把事件直接被丟棄。關閉覆蓋層後，可能繼續預覽，或在已放開 X 的情況下移動搖桿仍擦除兵。應在丟棄過期 A／X 放開事件時一併清理。  
   位置：[game_screens.gd:2088](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:2088)、[game_screens.gd:706](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:706)。

2. **[P2] Toast 仍遮住自由部署戰場下緣。**  
   無覆蓋層時仍固定畫在 `y=600`、高 44；戰場範圍為 `y=100–676`，解鎖與操作提示出現時會蓋住下方兵與落點。截圖流程清除 `toast_t` 沒有修正實際操作時的遮擋。  
   位置：[game_screens.gd:1042](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1042)。

驗證限制：已嘗試執行 `--only=free`；Godot 4.6 在測試開始前以 signal 11 崩潰，以上依靜態程式路徑判定。

結論：需修正