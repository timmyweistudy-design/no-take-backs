只讀審查，4 條必改：

- **P1** [game_result.gd:314](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:314)：AI 敗局的分頁 1 多一顆「試著覆盤」，加分頁鈕、底列最多四鈕＝6，必觸發結果 R14 失敗；事實收合鈕還會再加一顆。須合併入口或登記具體豁免。
- **P1** [game_menus.gd:329](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:329)：疊層清掉 `_btns` 卻沒清 `probe_screen`，設定、圖鑑等會繼承底層 title/result 的類別、主動作及豁免，導致誤判失敗或錯誤放行。須同步清登記，再由疊層登記。
- **P2** [game_result.gd:900](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:900)：三枚可點印章冒用 `grid` 排除計數，系列結束摘要實際可點元件超過 5 仍通過。應正常計數並正式豁免，不能以內容名義隱藏。
- **P2** [lobby_view.gd:63](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd:63)：快速重賽只驗規則字串非空；缺少陣型仍跳過大廳，損壞規則則被 `_open_lobby` 換成標準後直接開始。須驗證上次規則及陣型可用，否則留在大廳，避免悄悄更換規則。

結論：有條件
