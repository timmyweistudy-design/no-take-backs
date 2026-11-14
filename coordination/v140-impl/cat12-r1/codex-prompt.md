你是《落子無悔》(Godot 4.6.2) 1.4.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 12 大類（§12.1 標題主次）：規劃 coordination/v140-impl/cat12-plan.md；方案 docs/2026-11-13-v1.4.0-plan.md §12；差異 coordination/v140-impl/cat12-r1/diff.patch。
請檢查：①標題左欄木牌改成每塊各自的 y／高度（pys、phs、col_h）後，手把焦點順序、點擊區、probe_align 欄、多寶盒籤槽、新玩家閃框、150% 只放名稱時（show_sub=false）是否都正確；room 計算加了主牌多出的 12px 後在日文 150% 是否會把副標拿掉（改變既有行為）；②建議下一步便箋 _ink_mode 開關是否成對、tint 是否影響 hover／焦點、簡化介面；③底架 TITLE_SHELF 的 draw_set_transform_matrix 還原（第 8 類的 ui_xf 規則：標題不是疊層，但請確認）、色盲、簡化介面；④測試是否足夠。
附行號。最多 5 條必改，500 字內。最後一行「結論：可／有條件／不可」。
