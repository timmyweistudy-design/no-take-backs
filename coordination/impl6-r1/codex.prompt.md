你是《落子無悔》（Godot 4.6 GDScript 自動戰棋）第六輪實作的程式審查者。repo 在目前目錄，遊戲在 game/。
方案（規格）：docs/2026-11-03-free-placement-plan-v6.md（重點 §3.1～§3.10、§5、§6）。
本輪實作＝ git diff 2fcff40..HEAD -- game（請自己跑 git diff / git show 讀）。核心：
- scripts/core/ruleset.gd（deploy/spacing/depth/fullfield、NTBR2）、army.gd（自由座標、NTB5、check_place_xy、move_group、has_room）、battle_sim.gd（自由部署排序編號）、
  mirror_check.gd（check_free）、formations.gd（to_free）、ai_army.gd／ai_turns.gd／hard_ai.gd、turn_placement.gd（place_batch、跳手）
- 介面：scripts/ui/free_place.gd（新）、game_screens.gd、replay_view.gd（覆盤自由模式）、lobby_view.gd、presets.gd（徽章 deploy_certified）
- 測試：tests/run_tests.gd 的 test_free_v6、test_free_skip_v6、test_review_free_v6、test_to_free_keeps_units_v6

只找「真的會出錯」的問題：規則不合法卻被接受、合法卻被拒、確定性／鏡像不對稱、代碼往返不一致、雙人輪流可作弊（例如一筆跨手、跳手錯判）、
介面狀態沒重設、覆盤／存檔載入用錯座標、舊格子模式被改壞（相容）。每條附 檔案:行號、觸發情境、建議修法。
不要提風格或命名。最多 12 條，依嚴重度排序，用繁體中文。最後一行寫「結論：可合併／需修正」。
