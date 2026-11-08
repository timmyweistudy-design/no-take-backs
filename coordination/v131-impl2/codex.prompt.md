你是資深 Godot 4.6 工程師。唯讀：不要改檔、不要跑 Godot。
《落子無悔》（game/）V1.3.1 實作審查第 2 輪。你第 1 輪：coordination/v131-impl1/codex.out.md。目前 diff：coordination/v131-impl2/diff.patch（或讀 game/ 現檔）；裁決 coordination/v131-ledger.md「實作」I1～I10（含不修的理由）。
請（繁中、900 字內）：1. 第 1 輪必修逐條確認（引用 檔案:行）；2. 新改動的新 bug（_draw_cell 表情疊加與隊伍參數、受擊／小動作路由順序、atk_face 改成 [擊序, 朝向] 後所有讀取處、grim 用 s.units 與 summon 欄位、idle_since 重設、FEATURE_EYES 新增對既有表情的影響、_part 武器最小 0.5、小石魔手臂畫序）；3. 剩下必修。另：效能三組交替量測 p95 新 9.64／9.67／10.06、舊 10.21／10.49／10.37，開機中位數 2.74／2.73 秒。最後一行「結論：同意／有條件同意（條件）」。
