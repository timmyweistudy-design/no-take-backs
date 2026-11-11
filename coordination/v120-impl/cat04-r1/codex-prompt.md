你是《落子無悔》(Godot 4.6.2，GDScript) 的程式審查。只讀檔。專案根目錄是目前資料夾；遊戲在 game/。
這一批是 1.2.0 第 4 大類（全畫面實物化＋色光），差異在 coordination/v120-impl/cat04-r1/diff.patch，規劃 coordination/v120-impl/cat04-plan.md，裁決 coordination/v120-impl/ledger.md 最後一節。

重點：`_obj_deco`／`OBJ_OF`／`panel_obj`（疊層在 _draw_overlay 設、結尾清；巢狀疊層與便條宿主疊層的情況）、`_btn` 的木牌條件改動（TH_WOOD／TH_ACTIVE、label 空字串、`last_btn_paper`、`_ink_mode` 的保存與還原）、大廳布標分頁、跳字紙條（`_ink_mode` 在戰場層）、走勢圖水彩、`_art_checks` 新量法（效能：每隻單位排序、整張截圖取樣）、教練面板高度、明信片遮罩。

鐵則：畫面狀態不進模擬；字級只用字級表；簡化介面要有退路；版面探針要和實際畫的一致；`_ink_mode` 等全域繪圖狀態不能漏還原。
找真的會出錯的 bug，附檔案與行號（目前工作樹）。最多 8 條必改，每條：位置、問題、會怎樣、改法。900 字內。最後一行「結論：可／有條件／不可」。
