已讀取 `git diff HEAD -- game`。曾執行自由部署測試，但 Godot 4.6 在測試開始前以 signal 11 崩潰；以下依程式路徑及座標案例判定。行號皆為工作目錄版本。

**Codex 第一輪**

| 編號 | 判定 | 複查結果與位置 |
|---|---|---|
| 1 | 已修好 | 復原紀錄帶隊伍，拒用另一隊快照，還原前重新驗證。`game/scripts/ui/free_place.gd:211、225、233` |
| 2 | 沒修好 | 新操作入口已加鎖，但既有拖曳的放開入口沒有檢查鎖定。紅方按住兵、按 Space 確認雙方完成，再放開滑鼠，仍可搬移或拖出界刪除。`game/scripts/ui/free_place.gd:334、344`；`game/scripts/ui/game_screens.gd:247` |
| 3 | 已修好 | 解碼後檢查跨隊敵距，並驗證明牌 AI 的半場部署限制。`game/scripts/game/battle_code.gd:63、72` |
| 4 | 已修好 | 大廳開局前依對局種類阻擋錯誤全場模式。`game/scripts/ui/lobby_view.gd:84` |
| 5 | 沒修好 | 改為允許無戰鬥兵的一方上場打，違反規格的直接判勝／判和；藍方完全沒兵時，仍被空軍隊檢查擋住。`game/scripts/ui/game_screens.gd:206、250、253`；規格 `docs/2026-11-03-free-placement-plan-v6.md:147` |
| 6 | 已修好 | 畫筆記錄隊伍、手次與暗擺階段；延伸及提交都核對。`game/scripts/ui/free_place.gd:66、143、187` |
| 7 | 已修好 | 改為完整搜尋 50 單位點陣，遮蔽判定保留距離恰好等於間距的合法點。`game/scripts/core/army.gd:294、317、321` |
| 8 | 沒修好 | 越界索引已過濾，但載入後仍保留範圍內的舊索引。例如舊選取 `[0,1]`，載入另一個兩兵陣型後按 Delete，會刪掉新陣型兩兵。`game/scripts/ui/free_place.gd:77、256`；`game/scripts/ui/game_screens.gd:1603` |
| 9 | 修了但引入新問題 | Enter 已攔截，不再進入格子查找；但畫筆途中按 Enter 會覆寫整筆預覽並立即提交一隻，詳見下方新增問題。`game/scripts/ui/free_place.gd:401` |
| 10 | 沒修好 | 現在一律拒絕含 `cmds` 的代碼，沒有重播驗證，也沒有輸出輪序紀錄。規格仍要求支援。`game/scripts/game/battle_code.gd:18、77`；`docs/2026-11-03-free-placement-plan-v6.md:143` |
| 11 | 已修好 | 自由放置與覆盤均先轉己方視角再量化。`game/scripts/ui/free_place.gd:60`；`game/scripts/ui/replay_view.gd:263` |
| 12 | 已修好 | 改規格後自洽：欄位固定存半場縱深；全場實際範圍由 `fullfield` 決定；AI 轉換使用半場縱深，匯入亦驗證同一限制。`docs/2026-11-03-free-placement-plan-v6.md:135`；`game/scripts/core/ruleset.gd:174、292`；`game/scripts/core/formations.gd:177`；`game/scripts/game/battle_code.gd:74` |

**Antigravity 第一輪**

| 編號 | 判定 | 複查結果與位置 |
|---|---|---|
| 1 | 沒修好 | 越界防護補了，但載入後舊選取仍會誤刪／誤翻新兵，同 Codex 8。`game/scripts/ui/free_place.gd:77、256、269`；`game/scripts/ui/game_screens.gd:1603` |
| 2 | 沒修好 | 群組拖出界取消已修；滑鼠放開也會清理。但手把 A／X 在覆蓋層開啟後放開，事件不會送進自由模式，既有狀態仍殘留。`game/scripts/ui/free_place.gd:348、375、447`；`game/scripts/ui/game_screens.gd:705、709` |
| 3 | 修了但引入新問題 | 紅方朝向與整群預覽已補，但群組預覽未使用實際夾限位移，顯示位置與落點不同。`game/scripts/ui/free_place.gd:623、626、630` |
| 4 | 已修好 | LT＋A 共用框選入口；十字鍵補畫筆／擦除並統一邊界；LB／RB 經原映射切兵。`game/scripts/ui/free_place.gd:455、488、490`；`game/scripts/ui/game_screens.gd:713、852` |
| 5 | 已修好 | 已補金幣預扣斜線、首尾射程、腳底亮點及手勢動畫。`game/scripts/ui/free_place.gd:551、612、655、698`；`game/scripts/ui/game_screens.gd:1662` |
| 6 | 沒修好 | 部署禁區已融合並限制於戰場；Toast 的正式繪製位置未改，只在截圖流程設 `toast_t = 0`，實際解鎖仍遮擋原位置。`game/scripts/ui/free_place.gd:520、529`；`game/scripts/ui/game_screens.gd:1039`；`game/scripts/ui/main.gd:516、555、566` |
| 7 | 已修好 | 明牌全場改標「AI 的部署縱深」，符合新欄位契約；雙人全場隱藏縱深列；覆盤補敵兵禁區。`game/scripts/ui/lobby_view.gd:510`；`game/scripts/ui/replay_view.gd:464` |
| 8 | 沒修好 | 泡泡原因與邊界已修；細步搜尋卻每次滑鼠事件都重設成完整間距，慢速移動仍跳空位。同一路徑單次事件得到 `[200,2000,2800]`，每 100 單位一事件則得到 `[200,2600,3400]`。`game/scripts/ui/free_place.gd:164、169、644、662` |

新增大廳預設確認為自由排兵、間距 800、縱深 7500。`deploy_certified()` 會排除全場，只接受格子或該自由部署組合；未發現這兩項本身另有確定錯誤。位置：`game/scripts/game/presets.gd:15、24、67`。

**修正新引入的錯誤（依嚴重度）**

1. **[P2] Enter 會丟失尚未提交的畫筆並提前落子。**  
   按住滑鼠畫出多隻預覽時按 Enter，會再次呼叫 `_fs_begin()` 清掉原筆，再 `_fs_commit()` 提交游標位置的一隻；放開滑鼠已無原筆可提交。應先處理正在進行的筆畫。  
   位置：`game/scripts/ui/free_place.gd:401、404、405`。

2. **[P2] 整群預覽與實際落點不一致。**  
   `move_group()` 會夾限位移，但預覽只取成功與否，仍用原始 `dv` 畫兵。例如縱深 7500、兩兵 x＝1000／2000，拖第一兵到 7000：預覽為 7000／8000，實際落點為 6500／7500。應使用回傳位移或試算軍隊的位置繪製。  
   位置：`game/scripts/ui/free_place.gd:626、628、630`；`game/scripts/core/army.gd:239`。

結論：需修正