你是資深 Godot 4.6 工程審查者。唯讀，不要改檔、不要跑 Godot。
審查 coordination/v120-final/diff.patch（《落子無悔》V1.2.0 質感升級全部程式改動；遊戲在 game/）。上一輪你的 11 條（coordination/v120-impl2/codex.out.md）已處理，Minor 兩條延後。重點看本輪新加的：
- ui_base.gd 的 `_ink_mode`／`_ink()`：狀態有沒有漏還原（早退、例外路徑、巢狀呼叫、_btn 內部），會不會讓別的畫面字變墨色；浮雕判斷。
- lobby_view.gd、codex_view.gd 的羊皮紙頁；codex 小劇場內陰影。
- game_result.gd 的緞帶尺寸（_result_line1、fit、text_h、寬 504）與 drop 動畫。
- game_menus.gd 殘局標題改 _h1。
- 也再看一次整體：效能（每幀新配置）、快取鍵、plain_ui 分支、版面探針一致性。
回答（繁中、800 字內）：每條「檔案:行｜Critical/Important/Minor｜問題與修法」，只列真的問題。最後一行「結論：可出貨／修完再出」。
