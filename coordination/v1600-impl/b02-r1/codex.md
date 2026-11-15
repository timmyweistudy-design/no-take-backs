必改 4 項（只讀靜態審查）：

1. [ui_base.gd:953](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:953)：只登記 `_btn`，漏掉直接紙面。實例：[game_playroom.gd:163](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_playroom.gd:163) 抽走卡片覆紙，177 行仍畫白字，偵測不到；須納入紙面繪製入口並修字色。

2. 同處登記 `hit`，包含擴大的點擊區、下緣及按下時未繪紙的部分，會誤報鄰字；應登記實際紙面 `rd`。

3. [game_place.gd:1268](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:1268)、[game_v16.gd:274](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:274)：深底豁免未確認材質繪製成功；缺圖時仍可能保留淺底卻豁免白字。須成功覆底後才登記。

4. [ui.gd:2678](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:2678)：除 `_ink` 外主要是字串比對。須補實際畫一幀、呼叫偵測器的正反例，涵蓋直接紙面、缺 `gr`、深底、停用、plain_ui×色盲，以及舊版異變實驗室。

所改 `last_btn_paper` 讀取間未見其他 `_btn`；`_ink_mode` 重設與 `gr` 缺省取 `r` 中心無明顯問題。

結論：有條件
