你是《落子無悔》(Godot 4.6.2) 1.3.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 11～13 大類：規劃 coordination/v130-impl/cat11-plan.md；方案 docs/2026-11-13-v1.3.0-plan.md §11～§13；差異 coordination/v130-impl/cat11-r1/diff.patch（也含已審過的第 8～10 大類，這次只看 11～13）。
內容：game_v16.gd seat_visible／seat_mood／_draw_seat（對手坐桌邊）；battle_fx.gd _draw_owner_hand；scripts/game/owner_daily.gd＋game_v16 od_today／_od_after／_draw_owner_daily＋game_core 呼叫＋save.gd 新鍵＋殘局卡片入口；battle_view.gd 掌燈開門（intro_*、_draw_intro）＋game_screens _input 跳過、_ready／_process 呼叫＋save intro_seen；dev_main 新截圖；測試 test_parlor_people_v130、test_owner_daily_v130、test_intro_v130。
請檢查：①對手木偶會不會蓋到盤面（大地圖、小地圖縮放、桌邊視角、跟拍放大）、HUD、茶杯、聚光；②每日出題：換日（午夜跨日時面板開著）、試玩版、題庫變動（某題被移除）、_od_after 在重算三星／教學／工坊殘局是否誤觸、印數溢位、存檔清除（CLEAR_KEYS 要不要加 od）；③開場：第一次啟動同時有 first_run 疊層（語言選擇）時的順序、跳過那一下會不會漏到下面、`Save.save_data()` 在第一次啟動前是否安全、全螢幕切換、影片模式；④老闆的手和「開戰」字、棋鐘重疊；⑤其他。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
