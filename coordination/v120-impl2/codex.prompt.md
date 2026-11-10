唯讀，不改檔、不跑 Godot。《落子無悔》V1.2.0 質感升級（零預算）實作中，請做程式審查＋英文文案校對。
讀 coordination/v120-impl2/diff.patch（相對方案提交 3294b4b 的程式改動，含未提交），方案 docs/history/2026-11-07-v1.2.0-plan.md、裁決 coordination/v120-ledger.md；新檔 game/shaders/unit_bake.gdshader、tools/gen/gen_ui_tex.py、tools/gen/import_audio.py 直接讀。
鐵則：FINGERPRINT 不變（畫面不能進模擬）、版面探針要正確、手把焦點與命中框一致、效能（繪圖 p95 增幅 ≤10%）、授權登記完整。
A. 程式審查（繁中、900 字內，每條 檔案:行號、Critical／Important／Minor、觸發情境）：特別看 ui_base.gd 的 _text（淺色浮雕判斷、探針外擴）、_box／_tex_box／StyleBox 快取鍵爆量、_btn 厚度與懸停位移是否和命中框、探針不一致、sprite_cache.gd _post（烘焙後處理的時機、色盲重烘、取消）、sfx.gd（變體、單軌音樂、duck、frenzy 換曲、play_music 重入）、charts.gd（ui.Save 存取）、battle_units.gd（_draw_ambient、場地底紋效能）、game_screens.gd（覆蓋層縮放動畫與探針、游標）。
B. 英文文案：讀 game/data/strings.csv 的 en 欄，挑出最不自然、太直譯或不一致的 25 條，給修正版（保持 %s／%d 佔位與長度不明顯變長）。格式：key｜原文｜建議。
最後一行「結論：可繼續／修完再繼續」。
