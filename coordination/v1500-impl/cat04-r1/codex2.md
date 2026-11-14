未發現本輪修正有必改問題（只讀靜態審查，未執行測試）。

- RT＋View 在圖鑑映射前攔截並返回，無雙重觸發：[game_screens.gd:256](game/scripts/ui/game_screens.gd#L256)。
- 拖曳中移到紙卡上放開，會取消操作並清除拖曳、塗兵及擦除狀態：[game_screens.gd:361](game/scripts/ui/game_screens.gd#L361)。
- `ps_fav`、螢幕座標轉換與 `_btn` 契約修正均合理；新增滑鼠測試涵蓋所述基本路徑。

結論：可
