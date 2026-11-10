你是資深 Godot 4.6 工程師兼 2D 技術美術、角色動畫顧問，可上網查資料。唯讀：不要改檔、不要跑 Godot。
專案《落子無悔》（game/；docs/STATE.md「活起來、像手作（V1.3.0）」、docs/MODULES.md）；V1.3.0 方案與進度 docs/history/2026-11-08-v1.3.0-plan.md §10、裁決 coordination/v130-ledger.md。Claude 底稿：coordination/v131-r1/seed.md。
任務：V1.3.1 第 1 輪獨立提案，主角是角色。請：
1. 讀程式（scripts/ui/units/kit.gd、kingdom.gd、fantasy.gd、art.gd、sprite_cache.gd、battle/battle_units.gd、battle/battle_state.gd）確認：其餘 16 種加 _part 標註的工作量與風險（逐種：哪些部件要分 z／fwd、有沒有直接 ci.draw_* 繞過 _part 的地方、哪些用 _eyes 以外的臉）；轉身頁全 22 種的記憶體與烘焙時間、頁面上限（4096）、要不要分頁；走路中轉身與出手中轉身的做法與成本；表情疊加跟著轉身的做法；待機小動作是加影格還是貼圖時部件變換；雙朝向光源的可行做法（例如只烘亮邊遮罩、或轉身頁用世界光）。
2. 上網查並引用：2D 角色 idle 變化、secondary motion、turnaround 的業界做法；程式化角色動畫（procedural animation）。
3. 對 seed.md 每節同意／修改／反對；你自己的新想法（至少 5 條）。
4. 每條 P0／P1／P2／不做：做法、風險、驗收、人時、記憶體／p95 估計。
回答繁中、1800 字內。最後一行「結論：…」。
