唯讀審查完成；未改檔、未跑 Godot。以下檔名均位於 `game/scripts/`。

**必修**

- **輪抽 AI 用錯卡池**：`ui/screens/game_modes.gd:1275` 只設定 `pool`，未將 `ai_pool_same` 設為 false；`core/ruleset.gd:188` 因此讓 AI 使用玩家抽到的牌。應關閉共用卡池。
- **競猜結算文字必定消失**：`ui/screens/game_result.gd:42` 先結算並寫入 `report.wager_line`，第 60 行隨即呼叫 `_build_report()`；`ui/screens/game_core.gd:255` 整份覆寫報告。分數有存，結果頁卻看不到押注結果。
- **棄看競猜會污染下一場**：`ui/screens/game_place.gd:28` 返回標題未清除 `wg_active`；下一場任何戰鬥結束，`ui/screens/game_modes.gd:1213` 都可能拿該場結果結算舊押注。應綁定對局，離開即取消。
- **指揮官預算會累加、破壞讓子**：`ui/lobby_view.gd:216` 以對方「加成後」預算當基準。雙方交替選老兵，100／100 會變成 110／100、110／120、130／120；也會覆蓋既有讓子，甚至超過預算上限。須保存基礎預算，分別計算加成。
- **GIF 執行緒未收尾**：`ui/replay_view.gd:790` 啟動編碼，但 `ui/battle_view.gd:45` 的退出清理未等待 `gif_thread`。編碼中關閉遊戲可能中斷寫檔；應加入退出等待。
- **明信片重播碼不能使用**：`ui/screens/game_result.gd:612` 把長碼截斷加省略號，卻標示可貼入觀看。需完整呈現或提供可解碼 QR。

**建議**

- `ui/replay_view.gd:770` 只檢查戰鬥狀態與播放種類；錄影中開設定／離開確認等覆蓋畫面，仍會把它錄進 GIF。應取消錄製或獨立擷取戰場。
- `ui/screens/game_result.gd:636` 忽略 `save_png()` 回傳值，失敗仍顯示成功；檔名只精確到秒，同秒重存會覆寫。
- `game/puzzles.gd:11` 仍只有 11 章；第 12 章軍令目前尚未接入正式關卡清單，不能視為 #4 完成。

**不用改**

- `game/puzzles.gd:155、163、166` 依 `skills` 區分編碼，舊單技能 tick 與三星解保持相容；`174` 的修正按技能分別守冷卻、開場及局長，越界回原方案，未見確定錯誤。
- `game/workshop.gd:70、77、81、106` 有驗前綴／版本、棒次、陣型及重跑作者解；NTP1 保留。`ui/screens/game_modes.gd:372、404` 按格數計算，搬移算兩格，作者解取剛才正式開戰的 `last_armies[0]`。
- `ui/screens/game_core.gd:343、352`：重新挑戰及套用提示解後過關會寫最佳紀錄；重播不寫，工坊不寫。`game/save.gd:199` 有清理紀錄格式。
- GIF LZW 等價移植後以 Pillow 抽樣解碼比對通過，未見確定編碼錯誤。
- 正常播完時已有 1.4 秒戰場停留，明信片在切結果前擷取（`ui/battle_view.gd:107`）；不是結果頁截圖。`user://postcards` 路徑合理。
- 競猜完成後先清 `wg_active`，再看重播不會重複加分；輪抽 `has_combat` 檢查存在。指揮官技能與預算可由既有規則碼保存，技能開啟即為娛樂徽章（`game/presets.gd:83`）。
- 第二批未改模擬核心、數值或 golden；未執行測試，不能宣稱實測 FINGERPRINT 相同。

結論：先修輪抽卡池、競猜生命週期、指揮官預算及輸出檔案問題，再進入驗收。
