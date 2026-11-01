上一輪 **1、3、4、5 已修好**：循環設定與測試已補；報表以記憶體假資料驗證，冒名模式、錯誤等級、零決勝及秒數／逾時超標都會擋下，多等級摘要不再覆蓋。第 2 點已修正播放歷史依賴，但仍有演出問題。

- **P2｜[battle_view.gd:27](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:27)**：仍保留每幀 `_check_clutch()`。開場就符合條件的小兵力對戰，首幀不足一個 tick 時記為 tick 0，首幀已前進時記為 tick 1；seek 重算從 tick 1 開始，仍可能不一致。應統一開場判定。
- **P2｜[battle_view.gd:94](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:94)**：`_sim_step(false)` 也會播 clutch 音效並設定慢動作。跳過戰鬥會多播音效；seek 的最後兩個補播 tick 若跨過觸發點會啟動八秒慢動作，快轉主迴圈跨過則不會。應分開標記重建與演出副作用。
- **P2｜[battle_view.gd:23](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:23)**：同幀觸發慢動作後，迴圈仍消耗原速累積量。若後續 tick 同幀結束戰鬥，慢動作尚未呈現，`slow_used` 又會阻止最後一擊頓格。應在觸發時處理剩餘時間，補多 tick 幀測試。
- **P2｜[main.gd:484](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/main.gd:484)**：mem-check 有記錄物件數，通過條件卻未比較；戰鬥段也未比較貼圖記憶體，這兩種成長仍可綠燈。

S8 的 `main._ready()` 先呼叫父層、膠囊 `_draw_inner()` 提前返回，未見搬移錯誤。正式場景回呼有設定；測試直接 `GS.new()` 則維持空操作，尚未覆蓋自動結算回呼。

本輪唯讀；Godot 檢查程序啟動即崩潰，未取得引擎測試結果。

可否收尾：暫不可，建議先修正上述演出時序與驗證缺口。