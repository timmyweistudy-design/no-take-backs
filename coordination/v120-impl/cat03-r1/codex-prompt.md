你是《落子無悔》(Godot 4.6.2，GDScript) 的程式審查。只讀檔，不要改檔、不要跑指令以外的寫入。
專案根目錄就是目前資料夾；遊戲在 game/。這一批是 1.2.0 第 3 大類「垂直切片」（另含第 2 大類審查後修正），差異在 coordination/v120-impl/cat03-r1/diff.patch，規劃在 coordination/v120-impl/cat03-plan.md，HUD 對照 coordination/v120-impl/hud-checklist.md。

內容：桌面底 _draw_desk、棋盤框 _board_ring、HUD 棋鐘與黃銅滑尺、AI 名稱情境顯示（hud_info_until）、開場三段落子 _open_drop、宣紙戰報 _ink_active/_ink_k/_draw_ink_report_*、結果頁紙卡（_ink_mode）、老闆便條疊層 _boss_note/_draw_boss_note/_close_boss_note、河的藍染絹與木片橋（map_art.gd）、大廳線裝、標題多寶盒、unit_bake.gdshader 高光磨損、測試 test_present_v120。

鐵則：模擬只用整數、畫面狀態不能進模擬（FINGERPRINT 不能變）；截圖流程要可重現；字級只能用字級表；手把、鍵盤、滑鼠都要能操作；簡化介面（plain_ui）、減少特效（reduce_fx）要有退路。

請找：真的會出錯的 bug（狀態沒重置、疊層卡住、輸入被吃掉、手把無法關閉便條、重播/覆盤/截圖流程誤觸演出、存檔寫入時機、測試污染真存檔、效能熱點如每幀重算）。附檔案與行號（以目前工作樹為準）。
最多 8 條必改，每條：位置、問題、會怎樣、建議改法。回覆 900 字內。最後一行寫「結論：可／有條件／不可」。
