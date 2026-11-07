你是資深 Godot 4.6 工程審查者。唯讀，不要改檔、不要跑 Godot。審查 coordination/v120-final2/diff.patch（《落子無悔》V1.2.0 補完：sfx.gd 匯流排與交叉淡入、battle_fx.gd 戰報小章與光暈、ui_base.gd 圖示厚塗（Icons.force 靜態色）、icons.gd _k()、game_screens.gd 戰場調色子節點 _update_grade（讀 hint_screen_texture）、shaders/world_grade.gdshader、map_art.gd 烘焙筆觸與邊緣裝飾＋紙紋、battle_units.gd 跳過執行時紙紋、lobby_view.gd 雙頁與書籤與 _ink_mode）。遊戲在 game/。
重點：狀態洩漏（Icons.force、_ink_mode 早退）、淡入淡出與 duck／狂熱同曲的互動、匯流排在 headless／測試重複建立、調色節點的座標（鏡頭縮放、震動）、visible 與覆蓋層、每幀配置與效能、plain_ui／reduce_fx 分支、確定性（不能碰模擬）。
回答（繁中、700 字內）：每條「檔案:行｜Critical/Important/Minor｜問題與修法」，只列真的問題。最後一行「結論：可出貨／修完再出」。
