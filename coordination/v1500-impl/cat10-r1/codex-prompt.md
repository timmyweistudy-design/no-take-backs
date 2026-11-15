你是《落子無悔》(Godot 4.6.2) 1.5.0 實作的程式審查（第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 10 批：規劃 coordination/v1500-impl/cat10-plan.md；差異 coordination/v1500-impl/cat10-r1/diff.patch。
重點：`pool_summary` 類別判定是否和 `_filter_hit` 一致（奇襲優先、支援、近戰、遠程）、奇幻兵與未解鎖兵；新增 btn_group 對手把焦點、點擊、停用狀態有沒有影響（btn_group 只影響 R14 計數嗎？）；`btn_group` 每處都有還原成空字串。附行號。最多 3 條必改、300 字內。最後一行「結論：可／有條件／不可」。
