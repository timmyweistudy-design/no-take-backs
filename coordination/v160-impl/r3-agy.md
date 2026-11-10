### 一、第 2 輪意見修復確認

經查驗 `HEAD=aef87ac` 源碼，逐條核對如下：

1. **Codex C1（實驗簿越界崩潰）**：【已修好】[save.gd:360-361](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L360-L361) 要求成績陣列長度嚴格等於 3 否則退回 `[]`；[game_v16.gd:788](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L788) 讀取顯示前檢查 `r.size() == 3`。
2. **Codex C3（教練執行緒舊解污染新場）**：【已修好】[game_v16.gd:560-563](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L560-L563) 換場時更新 `co_key` 並清空舊結果；[game_v16.gd:589-595](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L589-L595) 以 `co_thread_key == co_key` 丟棄過期算解，並在面板開啟時自動重算。
3. **Codex C5（教練快取鍵缺題目內容）**：【已修好】[game_v16.gd:558](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L558) 快取鍵納入 `_coach_pz().hash()`。
4. **Codex A7（高手陣驗證失敗仍竄改狀態）**：【已修好】[game_v16.gd:860-867](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L860-L867) 移至驗證完成後才賦值 `rules` 與 `challenge_army`，不合法陣型提前中斷退出。
5. **Codex 新 1（裂隙跨週錯記）**：【已修好】[game_v16.gd:680-681](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L680-L681) 結算時若 `rift_wk != Rift.week()` 則直接返回不記錄。
6. **Codex 新 2 / AGY #5（護送目標單兵解生成失敗）**：【已修好】[workshop.gd:167-174](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/workshop.gd#L167-L174) 允許作者額外部署為空，配合 [puzzles.gd:282-311](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/puzzles.gd#L282-L311) 支援空 `extra` 陣列驗證與出碼。
7. **Codex 新 3（完美目標可避開指定兵種）**：【已修好】[workshop.gd:101](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/workshop.gd#L101) 注入 `need_type = true`；[puzzles.gd:270-271](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/puzzles.gd#L270-L271) 強制要求 `count_of_type(...) > 0`。
8. **AGY #1（存檔容器超額整批洗白）**：【已修好】[save.gd:328, 342, 383](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L328) 超額全改為 `break` 截斷（`seen` 200、`notebook` 400、`rift_best/trio_clear` 50），不再清空字典。
9. **AGY #2（裂隙標記外洩自訂對局）**：【已修好】[game_v16.gd:708](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L708) `keep_rift` 嚴格限定同一組規則碼 `rules.to_code() == rift_code`。
10. **AGY #3（標記跨局污染）**：【已修好】[game_v16.gd:709-712](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L709-L712) 換題或換模式重置 `tv_marks = []`；[game_place.gd:36](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L36) 回標題亦安全清空。
11. **AGY #4（一陣三考通關漏斗早發）**：【已修好】[game_v16.gd:77-78](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L77-L78) 加上 `puzzle_id != "ws"` 排除工坊與三考。
12. **駁回項（`equals` 不比地圖）**：**【同意駁回】**。`equals()` 歷史用途為大廳預設（preset）比對，地圖不屬於預設欄位；模擬快取已由 `sim_digest()`（[ruleset.gd:394](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L394)）處理地圖參數。收尾階段改動 `equals()` 易波及既有預設比對邏輯，維持現狀並列已知限制為適當決策。

---

### 二、新錯誤審查

沒有。

可收尾
