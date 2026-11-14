你是《落子無悔》(Godot 4.6.2) 1.5.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 2 批（P1 之一）：規劃 coordination/v1500-impl/cat02-plan.md；方案 docs/2026-11-14-v1.5.0-plan.md §1.1、§1.5；差異 coordination/v1500-impl/cat02-r1/diff.patch。
重點：①R14：screen_register／click_count（_btns 裡宣告 grid 的不算）／layout_rules._r14——計數會不會漏算或多算（疊層蓋在畫面上時兩層按鈕一起算、手把焦點順序靠 _btns 的索引：加 grid 標記有沒有影響焦點與點擊）、已改造類別 R14_ENFORCE 的失敗與豁免語意；②標題：代碼移到收藏第 8 張（手把走訪改了、鍵盤捷徑還在不在）、系統鈕兩顆平分寬度、最近玩的只留 1 項；③兩步開戰 _quick_rematch：沿用上次規則直接 _lobby_start，再自動帶上次陣型——試玩版、未解鎖、禁牌、雙人、車輪戰、每日、無盡塔狀態殘留（_start_mode 是否清乾淨）、last_form 不合法時；④結果頁：result_tab 0/1/2 拆分後各分頁的內容（敗因、MVP、系列比數、星級、試煉三星條件、近敗覆盤主推）有沒有漏、重播快照 replay_snap 的 tab 還原、res_more_items 的每個 callback（overlay 設定順序、重播、複製）；主動作超過 2 顆移到「更多」最前面是否會藏掉重要動作（例：試煉、車輪戰、無盡塔）。
附行號。最多 6 條必改，600 字內。最後一行「結論：可／有條件／不可」。
