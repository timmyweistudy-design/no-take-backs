只讀審查；第 10 類有 8 項必改：

1. [game_result.gd:309](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:309)：換邊結算仍按顏色勝場宣告系列勝負，可能與 A／B 總分相反。換邊模式應統一用 `SwapDuel.verdict()` 顯示結果。

2. [campaign.gd:42](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/campaign.gd:42)：只驗前一關；殘局星直接取既有 `puzzle_stars`，老玩家可未打第一章便進第二章。應驗所有前置關皆通關。

3. [campaign.gd:74](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/campaign.gd:74)：保兵目標只數存活隻數，指定兵死了仍能過；星級門檻也寫死。應在關卡資料定義保護對象、星級條件並據此評分。

4. [save.gd:5](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:5)：仍是版本 3，未依方案升版及補遷移測試；無法辨識新增戰役格式。新增遷移並測舊檔補值；目前驗型只做到數值轉整數、夾限。

5. [game_playroom.gd:384](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_playroom.gd:384)、[game_place.gd:117](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:117)：換邊／合作在試玩版開放，卻用全兵池；`_allowed()` 信任規則兵池，可用正式版兵。建立規則時套 `RS.mask(_demo())`。

6. [game_v16.gd:1237](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:1237)：天梯沿用 `Rift.week()` 的 UTC 週四切換，與方案週一不同。統一週界並升榜版本，避免新舊規則混榜。

7. [game_v16.gd:1233](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:1233)：補送只在進裂隙／刷新最佳時觸發，恢復連線不會自動送；過期刪除也未落盤。接連線恢復事件，刪除後存檔。

8. [game_v16.gd:1923](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:1923)：切三考只禁地形按鈕，舊 `ed_map/ed_block` 殘留；畫面仍擋牆格，輸出卻是無地形 NTP4。進三考時清回平原。

其餘：換邊計分／倒下／和局、兩局結束、再來歸零及重播防重記接線成立。合作格子模式撤兵、清空、工具、拖曳及手把有守門，續局重置；自由部署未開放。戰役敵陣固定種子，換模式清 `camp_id`。NTP5 牆格、拒三考、舊前綴與 `code_kind` 已處理；此 patch 未改核心模擬及舊碼編碼分支。未執行測試。

結論：不可