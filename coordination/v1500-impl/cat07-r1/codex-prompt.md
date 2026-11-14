你是《落子無悔》(Godot 4.6.2) 1.5.0 實作的程式審查（第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 7 批（戰場辨讀）：規劃 coordination/v1500-impl/cat07-plan.md；方案 docs/2026-11-14-v1.5.0-plan.md §7；差異 coordination/v1500-impl/cat07-r1/diff.patch。
重點：①`pick_focus` 決定性（同時刻排序、重播倒帶時 hurt_t／atk_t 的時間基準、跟拍兵死亡或隱身）；②`_draw_focus_halo` 用 `RenderingServer.canvas_item_add_triangle_array` 直接送，和 draw_* 的繪製順序、目前的 draw transform（鏡頭 _cam、桌邊視角 table_view 的斜投影）是否一致——位置會不會跟兵錯開；③血條透明度 `hp_bar_alpha` 在非 live（截圖、重播暫停）時的行為；④`is_num_text` 對實際跳字字串（合併跳字「×3」、帶單位、全形數字、負號種類）的判斷；⑤固定時鐘截圖決定性；⑥測試夠不夠。
附行號。最多 6 條必改、600 字內。最後一行「結論：可／有條件／不可」。
