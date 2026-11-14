你是《落子無悔》(Godot 4.6.2) 1.4.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 8 大類（轉場切片 A）：規劃 coordination/v140-impl/cat08-plan.md；方案 docs/2026-11-13-v1.4.0-plan.md §2（特別是 §2.2、§2.5、§2.7）；差異 coordination/v140-impl/cat08-r1/diff.patch。
請檢查：①ov_trans_k／ov_slide_offset 與既有 _ov_t（1.3.0 器物開合 0.3 秒、ok_anim）的互動：同一個 _ov_t 被兩種動畫共用有沒有問題、哪些地方會重設 _ov_t；②ui_xf／Art.base 在疊層繪圖中途被其他程式碼重設成單位矩陣（漏改的 draw_set_transform 呼叫）——請 grep 疊層 lobby、codex、settings、keys、profile、puzzles、trials、codes 實際會走到的繪圖函式；③跳過吃輸入：_do_click、_key 之外，滑鼠拖曳、滾輪、觸控、手把類比（_pad_*）、按住確認是否會在轉場中落到新頁的按鈕上；_trans_hold 0.25 秒會不會吃掉正常操作；④截圖、版面探針（layout_probe）、PADWALK 走訪的終態是否完全一致（可重現）；⑤hover／焦點高亮、按鈕命中區在滑入時是否和畫面錯位（命中區沒位移）；⑥測試 test_transition_v140 有沒有漏測的狀態（簡化、色盲、手把、停用四態）。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
