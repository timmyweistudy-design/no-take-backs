你是《落子無悔》(Godot 4.6.2) 1.3.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 2 大類：規劃與路線 A 切片結論 coordination/v130-impl/cat02-plan.md；方案 docs/2026-11-13-v1.3.0-plan.md §1、§3、§4、§19.2；差異 coordination/v130-impl/cat02-r1/diff.patch（battle_units.gd 的 tilt_on／_draw_relief／棋盤端面、save.gd 的 table_view、game_menus.gd 設定列、ui_base.gd 茶杯熱氣、測試 battle_visual.gd test_table_view_v130）。
請檢查：①路線 A No-Go 的理由是否成立（看 battle_units.gd、game_screens.gd 的繪製流程），有沒有被忽略的低成本 A 做法；②_draw_relief 的格座標（terrain 的 Q＝500、n、m、鏡像的 _col 是依隊伍算的——畫面用的 grid 索引是否和模擬一致）、小地圖／大地圖、地圖事件（崩塌）造成的動態牆格沒反映、簡化介面與正上方；③凸起頂面上移會不會蓋到北側格的單位、選取圈、射程圈、跳字（它們畫在之後？）；④效能（每幀逐格 draw_texture_rect_region＋多條線；1.1.0 教訓：每幀逐隻向量畫 p95 多 20%，要烘）；⑤設定列：舊存檔沒有 table_view 時的值、sanitize、設定碼 NTS1 匯入匯出有沒有漏；⑥其他錯誤。
附行號。最多 8 條必改，900 字內。最後一行「結論：可／有條件／不可」。
