唯讀，不改檔、不跑 Godot。可用 --search 查資料（附來源網址）。
《落子無悔》Godot 4.6.2 2D 自動對決要做 V1.2.0「質感升級」（不改玩法、不改模擬）。先讀 coordination/v120-r1/research.md（現況盤點與研究筆記）、docs/history/2026-11-07-v1.2.0-plan.md（Claude 初稿），再 grep：game/scripts/ui/ui_base.gd（_btn、_text、_box、_panel、字型載入 _load_fonts）、game/scripts/ui/units/kit.gd、art.gd、game/scripts/ui/sprite_cache.gd、game/scripts/ui/battle/battle_fx.gd、game/scripts/game/sfx.gd、tools/gen/build_font.py、game/fonts/、docs/MODULES.md。
你負責「技術可行性、效能、管線、授權、工時與風險」。請回答（繁中、1800 字內，附 檔案:行號與來源網址）：
1. 字體：換成 jf open 粉圓／源泉圓體／芫荽等 OFL 字型的管線（現在 build_font.py 子集化、字級表、描邊），MSDF vs 一般點陣、描邊與陰影的實作，對版面檢查的影響。
2. 介面材質：現在全部 _draw 即時繪製，改成九宮格貼圖（StyleBoxTexture 或 draw_texture_rect_region 九宮格）的做法與工作量；轉場與微互動（Tween）在即時繪製架構下怎麼加，會不會影響手把焦點與版面檢查。
3. 角色：程式向量兵升級（外框粗細、明暗、紙紋、線條微抖、剪影閃白）在精靈圖快取下的做法與效能；改用外包逐格精靈圖的管線成本。
4. 特效與後製：粒子、泛光、調色／LUT、暈影在 Compatibility 渲染器的可行性與效能。
5. 聲音：換真人音樂與素材庫音效的管線（格式、分軌、ducking、變體隨機）、授權記錄。
6. 工時估計與 V1.2.0 必做／延後切線。
最多 14 條，各標 P0／P1／P2、工時 S／M／L。最後一行「結論：V1.2.0 技術範圍＝…」。
