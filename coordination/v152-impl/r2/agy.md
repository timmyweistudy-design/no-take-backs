### 1. 畫面排版問題

1. **大廳未選中分頁文字偏左不置中**（不置中）
   - **圖名**：[`en_150 22_lobby.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152-impl/r2/sheet_lobby_tabs.png)、[`ja_125 22_lobby.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152-impl/r2/sheet_lobby_tabs.png)、[`ja_150 22_lobby.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152-impl/r2/sheet_lobby_tabs.png)
   - **位置**：頂部預設分頁 2～6（如 Classic 5、Skirmish、大軍団、単一兵種対決等）。
   - **問題**：因統一預留右側 38px 書籤槽，未選中分頁（無紅書籤）文字中心落在 x=61（按鈕中心為 77），導致文字整體明顯向左偏，且與下方置中於 77 的色條不對齊。

2. **日文 150% 分頁「単一兵種対決」第二行字壓色條**（字壓色條）
   - **圖名**：[`ja_150 22_lobby.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152-impl/r2/sheet_lobby_tabs.png)（含 `23_lobby_pool`、`32_lobby_fantasy`）
   - **位置**：頂部第 6 個分頁「単一兵種対決」。
   - **問題**：在 150% 字級與 110px 槽寬下被迫折為「単一兵種対」與「決」，第二行單字「決」直接壓在底部深藍色條上。

3. **英文 150% 分頁「Monster Crew」文字擠到紅書籤**（擠到紅書籤）
   - **圖名**：[`en_150 32_lobby_fantasy.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152-impl/r2/sheet_lobby_tabs.png)
   - **位置**：選中的第 3 個分頁「Monster Crew」。
   - **問題**：第一行「Monster」字串較長，字尾右緣緊貼垂下的紅書籤左緣，左右留白明顯不均。

4. **日文 150% 分頁「クラシック5種」換行緊貼色條**（字壓色條）
   - **圖名**：[`ja_150 22_lobby.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152-impl/r2/sheet_lobby_tabs.png)
   - **位置**：頂部第 2 個分頁「クラシック5種」。
   - **問題**：槽寬不足折為兩行，第二行「5種」下緣極度貼近綠色底條。

### 2. 對 ledger 第 1 輪「不採納」意見的看法

同意，ledger 所提數據（提示面板中心確為 640、緞帶下緣到說明文字間距 16.5px 符合 R2 ≥16 門檻、模態面板高度依內容動態計算且 R6 未違規）客觀且符合規範，裁決合理。

結論：有條件
