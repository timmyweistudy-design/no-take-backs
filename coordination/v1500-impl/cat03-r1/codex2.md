- **P2** [lobby_view.gd:908](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd:908)：換步僅設旗標，焦點到繪製時才更新，舊按鈕仍可執行。第三步焦點在「開戰」時，若 LB、A 同幀入列，會先退到第二步，再呼叫舊的 `_lobby_start` 直接開戰。須在換步時使舊按鈕失效，並補同幀輸入驗證；目前 PADWALK 每次按鍵都等待數幀，抓不到此錯誤。

其餘指定修改已逐條確認。僅靜態審查，未執行遊戲。

結論：有條件
