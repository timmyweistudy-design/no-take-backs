已唯讀檢查，未改檔、未跑 Godot。以下工時為一人日＝8 小時的估算，非實測。

1. **字體建議甲，先只用 R／B。**  
現有 `game/fonts/`：Noto R＝376,608 B、B＝384,896 B，合計 **744 KiB**；ThenKhung＝655 KiB，三檔共 **1.37 MiB**。依現行約 1,260 字語料、源泉四個靜態字重、拉丁字子集估計：

| 方案 | 子集總量 |
|---|---:|
| 甲 | 2～3.5 MiB |
| 乙 | 2.5～4.5 MiB |
| 丙 | 3～5.5 MiB |

這是預算區間，須取得原檔才可實測；各套皆保留完整遊戲字集。現行流程保留 OpenType 特性（`game/tools/gen/build_font.py:12、24`）。丙實為**六套**，草案漏算 Lilita（`coordination/v120-r2/draft.md:9`）。

載入包括字型解析與首次字形光柵化；RAM／VRAM 不能照檔案大小推算，字重、字級與描邊會增加快取，宜只預熱常用字。見 [Godot 字型文件](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html)。

真正成本是版面：目前基線固定 `size×0.85`，探針未算墨跡、描邊、陰影外擴，圖鑑另有換行器；須統一量測、繪製與混排間距（`game/scripts/ui/ui_base.gd:477`、`codex_view.gd:124`）。中文主字型有英數時，fallback 不會強制改用 Fredoka，須拆文字段或限制字元覆蓋。現已有 `tnum` 包裝（`ui_base.gd:315`）；新字須驗特性及 0～9 寬度，不支援便逐位固定格寬。[FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html)

2. **隊色先不改。**  
硬碼有角色一般／色盲兩組（`game/scripts/ui/units/kit.gd:23`），圖表另有四色（`charts.gd:8`）；勝負標題、HUD、部署區與血條多經 `Art.team_color` 取得（`screens/game_result.gd:92`、`battle_view.gd:617`、`lobby_view.gd:511`）。不能只換兩個 hex。新藍／紅相對亮度約 **0.180／0.175**，原為 0.380／0.182，灰階區辨大幅下降。

色盲模式須保留斜線、圓／菱形標記（`charts.gd:24`、`battle/battle_units.gd:600`）。改色要重烘角色頁與底圈，並檢查烘焙完成前直接繪製的外觀（`sprite_cache.gd:49、63、118`）。重審一般／色盲截圖及地形對比，另加 **1～2 日**；先只換介面色票。

3. **三頁重排：9～13 日。**  
大廳 4～5、圖鑑 3～4、結果 2～4，含命中框與焦點更新。現為固定座標即時繪製，焦點依按鈕登記索引；重排會改導航，不能保證「不改焦點順序」（`ui_base.gd:497`）。圖鑑需同步捲動區、觀景窗映射；結果頁須保留時間軸點擊重播（`screens/game_result.gd:146`）。驗收要兩語×三字級及手把流程（`game/tools/layout_check.sh:21、30`）。

4. **去工具化另估：**走勢圖 1～2 日；能力格條 0.5～1 日；對話泡 1.5～2.5 日；圖示戰報條 2～3 日。後兩者須處理混戰遮擋、事件合併與重播一致性（`game/scripts/ui/battle_view.gd:589`）。圖鑑目前是自繪條，並非可操作滑桿（`codex_view.gd:397`）。

5. **M1 建議編列 32～46 人日。**  
字體／樣式／色票3～5、九宮格3～4、三頁9～13、角色質感4～6、聲音4～6、整合驗收3～4，共26～38，加約20%緩衝；走勢圖與格條已含三頁，勿重複計價。不含外包繪製、原創作曲及等待期。

草案低估材質對比與快取成本：「每幀成本不變」只在圖集尺寸、通道不增加時成立；滿頁 RGBA8 約47 MiB，另烘遮罩會增記憶體（`sprite_cache.gd:17、27、97`）。M1 又先重排、M2 才交立繪，須先鎖素材尺寸與裁切規格（`coordination/v120-r2/draft.md:24`）。

結論：有條件同意（採甲先用兩字重、保留隊色、統一文字量測並預留完整回歸與素材規格）
