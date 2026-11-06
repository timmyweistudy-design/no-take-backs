唯讀，不要改檔、不要開遊戲視窗、不要跑 --steam-test。第十三輪第二次程式審查（第一次是 coordination/v13-r1/codex.out.md，6 條已修，修法見 coordination/v13-ledger.md）。
範圍：`git diff a4c842f` 的程式（game/scripts、game/tests、game/tools/balance/puzzle_forge.gd、trial_forge.gd、根目錄 tools/gen/*.py）。資料 game/data/puzzles.json 的 "extra"、"chapters"；game/data/trials.json 還在產（可能還不存在），不算缺陷。
方案：docs/2026-11-06-puzzle-expansion-plan-v13.md。
請查（繁中、900 字內，附 檔案:行號）：
1. 上一輪 6 條是否真的修好（特別是固定試煉敵陣的卡池驗證、時間設定冷卻、手把 L3/R3）。
2. 新判定 PZ.outcome／play 和遊戲結果頁、星數存檔、成就是否一致；有沒有同一關遊戲內和測試判定不同的路徑。
3. 舊 25 關與舊 10 試煉、舊重播、FINGERPRINT 是否可能被影響（legacy 路徑 rules null）。
4. 試玩版（force_demo）下新章節、新試煉是否正確鎖住。
5. 其他會讓玩家卡住或存檔壞掉的。
最多 8 條，標 P0／P1／P2。最後一行「結論：可／有條件／不可」。
