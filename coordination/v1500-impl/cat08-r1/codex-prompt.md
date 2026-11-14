你是《落子無悔》(Godot 4.6.2) 1.5.0 實作的程式審查（第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 8 批（精修）：規劃 coordination/v1500-impl/cat08-plan.md；差異 coordination/v1500-impl/cat08-r1/diff.patch。
重點：`_draw_unit_info` 用 `_cam * _upos(u)` 判斷所選兵是否在浮籤下面（這時的 draw transform 是否已是 IDENTITY、桌邊視角）；`_ink_mode` 開關沒有漏關；老闆出題列移除 primary 後手把焦點、第一顆是否仍是預設焦點。附行號。最多 4 條必改、300 字內。最後一行「結論：可／有條件／不可」。
