你是《落子無悔》(Godot 4.6.2，GDScript) 的程式審查。只讀檔。專案根目錄是目前資料夾；遊戲在 game/。
這一批是 1.2.0 第 5 大類「角色 2.0」，規劃 coordination/v120-impl/cat05-plan.md，差異 coordination/v120-impl/cat05-r1/diff.patch（裡面也含第 4 大類的 game_menus 改動，請聚焦第 5 類）：
落子壓扁 `_open_squash`、不倒翁搖 `_tumbler`、倒下離地、定格 `_pose_t`（設定 smooth_pose）、王國上發條／奇幻呼吸的個性動作、圖鑑大圖表情輪播 `cx_mood`（經 codex_bake 傳 mood）、姿勢資料化試點 `pose_data.gd`＋`data/poses/sword.json`（Art.pose 對劍士先讀資料）、測試 test_char2_v120、匯出過濾器。

鐵則：畫面狀態不進模擬（FINGERPRINT 不變）；命中事件不能延後；精靈圖快取烘焙的內層姿勢要和直接畫一致（sprite_cache 也用 Art.pose）；截圖可重現；效能（每幀每隻單位）；匯出版要讀得到資料檔。
找真的會出錯的 bug，附檔案與行號（目前工作樹）。最多 8 條必改，每條：位置、問題、會怎樣、改法。900 字內。最後一行「結論：可／有條件／不可」。
