你是資深 Godot 4.6 工程師兼 2D 技術美術。唯讀：不要改檔、不要跑 Godot。
專案《落子無悔》（game/；docs/STATE.md、docs/MODULES.md）。V1.3.0 方案 docs/2026-11-08-v1.3.0-plan.md、裁決 coordination/v130-ledger.md。
未提交的實作 diff：coordination/v130-impl1/diff.patch（也可直接讀 game/ 現檔）。
請做實作審查第 1 輪（繁中、1500 字內），找真的 bug（引用 檔案:行），重點：
1. 轉身影格：kit.gd 的 turn_c／_part／_part_end／_eyes 狀態會不會漏重設而污染一般影格烘焙或直接繪製（Art.unit 遞迴、圖鑑大圖、MVP）；_TurnPainter 與 _post(per) 的隊伍墨色索引；draw_unit 分支（atk、mood、hurt、lean、潛行 alpha）；_face_of 對 has_turn 的回傳；世代檢查。
2. 呼吸改 idle_bob(t, p) 與 bake_no_bob：烘焙抵銷是否正確、overlay 是否對齊。
3. 擁擠度分桶與 pc 位置快取是否與舊雙迴圈等價；_hand_ring／_chalk_line／_wob_line 每幀成本與配置。
4. 腳底三層（ring_tex 6 格、air 參數）、倒棋 death_life 與 dying 清理、箭 fly/dur、_fx_text 上限、OVERHEAD_CAP、inkring、關鍵時刻 key_*（重播、跳播 with_fx、reduce_fx）。
5. 停步慣性 stop_t／walking、擺陣 settle_t（鍵型別、拖曳中斷）、gold_bar 木珠、走勢圖 zoom 與 chart_zoom 字串、ui_quill 音效登錄。
6. 任何會改到模擬或 FINGERPRINT 的地方（不該有）。
分「必修／建議／不用改」，每條含修法。最後一行「結論：…」。
