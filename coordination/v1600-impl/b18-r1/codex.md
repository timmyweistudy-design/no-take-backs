行號均指 B18 快照；本輪唯讀靜態審查。

- P1｜[game_core.gd:348](build/cg/b18/game/scripts/ui/screens/game_core.gd:348)：DUEL 任一方勝都算玩家勝；輸給 AI 仍解勝利成就，玩家勝場卻不增加。
- P1｜[game_place.gd:202](build/cg/b18/game/scripts/ui/screens/game_place.gd:202)：第 2 局將 AI 藍陣寫入 `last_form`；下一組按 L 可載入並看見該陣，污染玩家陣型紀錄。
- P1｜[game_playroom.gd:413](build/cg/b18/game/scripts/ui/screens/game_playroom.gd:413)：雙局狀態、敵陣與種子僅留記憶體，無承諾寫檔及結算去重；不符 §3.1 中斷／重啟契約。
- P2｜[game_result.gd:433](build/cg/b18/game/scripts/ui/screens/game_result.gd:433)：覆盤入口限定 VS_AI；換邊對 AI 使用 DUEL，兩局皆無法覆盤。
- P2｜[game_v16.gd:831](build/cg/b18/game/scripts/ui/screens/game_v16.gd:831)：名局只驗代碼，未驗 `w/rem/sec` 型別與範圍；壞值仍進快取，顯示時可能報錯或冒充有效事實。

結論：不可
