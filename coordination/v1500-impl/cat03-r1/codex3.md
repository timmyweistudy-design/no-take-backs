- **P2** `game/scripts/ui/game_screens.gd:487–489`：Y／Tab 開合進階折頁仍保留舊 `_btns`，且不改變畫面世代。第三步焦點在「開戰」時，同幀先 Y 再 A，會直接執行舊的 `_lobby_start`，意外進入擺陣。須在開合時使舊按鈕失效，並補 Y＋A 同幀測試。

結論：有條件
