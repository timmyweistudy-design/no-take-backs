必改（行號均指快照）：

1. [ui_base.gd:1271](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b04/game/scripts/ui/ui_base.gd:1271)：首次便條關閉後未恢復主鈕焦點；開廳時的旗標已被消耗，焦點回到首個玩法頁籤，連按 A 無法三步開戰。截圖模式略過便條，走查漏驗此路徑。

2. [lobby_view.gd:629](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b04/game/scripts/ui/lobby_view.gd:629)：空標籤使 `_btn` 的 `plaque` 判斷為假（ui_base.gd:960）；清空布材質後實際畫圓角色塊，沒有木牌材質。須明確支援外繪文字的木撥片。

3. [dev_main.gd:2578](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b04/game/tools/dev_main.gd:2578)：走查僅 AI、逐幀 A，且截圖模式停用轉場；新測試亦未送同幀雙輸入。須補雙人、撥片切換、翻頁返回與正常轉場的 IN-160-01 驗證，現有 OK 不足以驗收。

結論：有條件
