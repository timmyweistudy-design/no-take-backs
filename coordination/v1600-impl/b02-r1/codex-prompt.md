你是《落子無悔》(Godot 4.6.2) 1.6.0 實作的程式審查（第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
B02：規劃 coordination/v1600-impl/b02-plan.md；方案 docs/2026-11-15-v1.6.0-plan.md §4 B02；差異 coordination/v1600-impl/b02-r1/diff.patch。
重點：①偵測器（game/tools/dev_main.gd `_contrast_issues` 的淺紙白字段）會不會漏：例如紙面不是走 `_btn` 畫的（`_tex_box(...,"paper")`、`btn_paper`、羊皮紙面板 `_panel` 上的白字）、`gr` 缺時用 `r` 的中心；會不會誤報；②`probe_unpaper` 是否只在真的蓋深色底的地方用；③各修正的 `last_btn_paper` 讀取時機對不對（_btn 之後中間有沒有別的 _btn 改掉它）、`_ink_mode` 有沒有漏重設；④停用、簡化介面（plain_ui）、色盲組合下顏色是否正確；⑤測試是否只是字串比對、能不能補成真的畫一幀檢查。
附行號。最多 6 條必改、500 字內。最後一行「結論：可／有條件／不可」。
