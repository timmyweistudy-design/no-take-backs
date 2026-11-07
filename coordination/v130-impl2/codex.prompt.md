你是資深 Godot 4.6 工程師。唯讀：不要改檔、不要跑 Godot。
《落子無悔》（game/）V1.3.0 實作審查第 2 輪。你第 1 輪：coordination/v130-impl1/codex.out.md。目前完整 diff：coordination/v130-impl2/diff.patch（也可讀 game/ 現檔）；裁決 coordination/v130-ledger.md「實作」。
第 1 輪後已改：倒棋移到透明度判斷前、墓旗只插一次、_eyes 還原 _cur_xf、轉身中出手改最窄 0.45、轉身頁補表情疊加、跳字改位移不放大、跳播也記 key_used、頭頂符號滿了丟最舊；另外 TEXT_CAP 撞名改 FX_TEXT_CAP；效能：腳底改預烘合成格（站地上 1 次貼圖，跳起 >0.15 才分三層）、格線不抗鋸齒、倒棋木座用貼圖。新增測試 tests/suites/ui.gd test_feel_v130。
請（繁中、1000 字內）：1. 第 1 輪七條必修逐條確認是否修好（引用 檔案:行）。2. 新改動有沒有新 bug（特別是 ring_tex 10 格烘焙與 draw_ring 合成分支、sprite_cache.draw_base、_draw_turn 的 overlay、key_used 在 replay_view 的重設）。3. 剩下的必修。最後一行「結論：同意／有條件同意（條件）」。
