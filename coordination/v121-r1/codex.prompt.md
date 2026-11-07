你是資深 Godot 4.6 遊戲工程師兼 UX 顧問，可上網查資料。唯讀：不要改檔、不要跑 Godot。
專案《落子無悔》（game/，Godot 4.6.2 Compatibility、立即模式 _draw UI；現況 docs/STATE.md、模組索引 docs/MODULES.md、V1.2.0 方案與進度 docs/2026-11-07-v1.2.0-plan.md §11、裁決 coordination/v120-ledger.md）。Claude 底稿：coordination/v121-r1/seed.md。
任務：V1.2.1 第 1 輪獨立提案——基於 V1.2.0 已實作內容的「細節優化」（不改模擬、數值、玩法；FINGERPRINT 不能變）。
請：
1. 讀程式找細節問題（引用 檔案:行）：效能熱點（每幀繪製次數、快取鍵、配置）、版面探針漏洞、狀態洩漏、可近用性（字級、對比、手把字形、減少動態）、音訊設定（匯流排已有但設定只有兩條）、本地化擴充成本（簡中、日文：字型子集、字串、版面）、Steam Deck Verified 條件、存檔與設定遷移。
2. 上網查並引用來源（Steamworks 資產與 Deck 規範、Game Accessibility Guidelines、自走棋／戰棋作品的 UI 細節做法等）。
3. 對 seed.md 18 條逐條：同意／不同意／修正做法＋估工（人時）。
4. 補充你認為漏掉的項目。
回答（繁中、1500 字內）：分「必修／建議／不做」，每條含做法、風險、驗收方法。最後一行「結論：…」。
