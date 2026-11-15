你是《落子無悔》(Godot 4.6.2) 1.6.0 實作的程式審查（第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
B03：規劃 coordination/v1600-impl/b03-plan.md；規格 docs/art-spec-v160.md；方案 docs/2026-11-15-v1.6.0-plan.md §1、§4 B03；差異 coordination/v1600-impl/b03-r1/diff.patch。
重點：①桌位表 `game/scripts/ui/table_seats.gd` 是否真的成為單一來源（還有哪些桌上物件、右緣物件仍寫死座標；放大鏡 `_draw_bmag`、棋鐘是否該接槽）；②敵情翻牌改肖像鈕：輸入（點擊、手把焦點、`foe_card_r` 點穿保護、RT＋View 開合）、停用、簡化介面、展開卡會不會超出螢幕或蓋到卡列／HUD；③盤外壓暗只用 `state != TITLE` 判，大廳等疊層在 PLACE／RESULT 狀態時會不會也被壓暗；④結果頁 HUD 收合有沒有拿掉玩家在結果頁仍需要的東西（輸入、焦點、測試）；⑤tone_check.py 的量法（區域、門檻、雜訊門檻 3/255、遮罩）是否可信、會不會漏判；⑥測試是否只是字串比對。
附行號。最多 6 條必改、500 字內。最後一行「結論：可／有條件／不可」。
