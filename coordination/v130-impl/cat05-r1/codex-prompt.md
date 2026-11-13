你是《落子無悔》(Godot 4.6.2) 1.3.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 5 大類：規劃 coordination/v130-impl/cat05-plan.md；方案 docs/2026-11-13-v1.3.0-plan.md §5.4、§6、§19.3；差異 coordination/v130-impl/cat05-r1/diff.patch。
內容：sprite_cache 背面走路頁（ExtraPainter mode 4、bw_tex＋LRU、draw_back_walk、跟轉身出手頁一起烘）、battle_units heading_of（走向平滑、南＝3/4 正面走路格、北＝3/4 背面走路格）、_gait_reset 清走向、battle_view 招牌特效（騎兵衝鋒身後塵、盾兵架盾塵圈、狂戰士木屑）、tools/anim_sheet.gd 背面走路總表、測試 test_heading_view_v130。
請檢查：①方向判斷在重播、跳轉、倍速、暫停（位置不變→平滑殘留？）、擊退（被推的位移算不算走路）、繞翼、鏡頭縮放時是否穩定、會不會一直抖動；②背面頁：team 與後處理 per＝4 的對應、LRU 清掉正在用的兵、色盲／塗裝換色重烘時 bw_tex 有沒有一起作廢、headless；③往南時傳 face±0.55 走既有走路轉身頁——那條路徑有沒有假設 |face|<0.9 只在轉身過程中（轉身完成判定、表情、xray、hover、掉漆）；④方案門檻「22 種全部有才開」是否滿足（召喚物、巨獸、小史萊姆）；⑤特效欄位與 4 倍速、減少特效規則；⑥其他。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
