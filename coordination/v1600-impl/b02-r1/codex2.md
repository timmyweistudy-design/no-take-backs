1. [ui_base.gd:952](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:952)：`paper_face` 未確認貼圖存在便登記淺紙；1013 行 `_tex_box` 缺圖回傳 `false` 時，實際只剩深色底，仍會誤報淺紙白字。應在成功繪製後登記，並補缺圖路徑測試；目前純函式測試抓不到此錯誤。

朱漆主鈕登記為深底，後續 `_mat_box` 不會覆寫成紙，這點正確。本輪為只讀靜態審查。

結論：有條件
