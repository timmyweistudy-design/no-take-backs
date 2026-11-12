你是《落子無悔》(Godot 4.6.2，GDScript，確定性整數模擬) 的程式審查。只讀檔。專案根目錄是目前資料夾；遊戲在 game/。
這一批是 1.2.0 第 7 大類「擴充規則 v1」：規劃 coordination/v120-impl/cat07-plan.md、契約 docs/rules-ext-v1.md（第 6 節是實作狀態）、差異 coordination/v120-impl/cat07-r1/diff.patch（battle_sim.gd 的 _ext_*、ruleset.gd 的 NTBR7 編解碼與 sim_is_legacy／equals、測試 share_codes.gd 的 test_ext_*、金標準 tests/golden/ext_v1.json）。

請特別檢查：①預設規則（ext 0、synergy false）下是否有任何路徑改變（標準場次位元組不能變）；②左右鏡像：所有新增迴圈與平手是否和陣列索引順序無關；③階段順序是否符合契約；④火矢、急救的整數邊界（血量 ≤0、同 tick 多個醫者、兩個鼓手堆疊、被救後同 tick 又被打）；⑤NTBR7 的唯一寫法與舊版讀取；⑥狀態欄位沒進 _hash_state 是否會讓重播／跳轉（seek）出錯；⑦對戰碼、遠征、殘局等其他吃規則的地方是否會遺失擴充欄位。
附檔案與行號。最多 8 條必改（位置、問題、會怎樣、改法）。900 字內。最後一行「結論：可／有條件／不可」。
