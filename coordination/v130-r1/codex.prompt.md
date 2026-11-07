你是資深 Godot 4.6 遊戲工程師兼 2D 動畫技術美術、遊戲設計顧問，可上網查資料。唯讀：不要改檔、不要跑 Godot。
專案《落子無悔》（game/，Godot 4.6.2 Compatibility、立即模式 _draw UI；現況 docs/STATE.md、模組索引 docs/MODULES.md、V1.2.1 方案 docs/2026-11-07-v1.2.1-plan.md、裁決 coordination/v121-ledger.md）。Claude 底稿：coordination/v130-r1/seed.md。
任務：V1.3.0 第 1 輪獨立提案。使用者要：去除角色紙片感（如轉身）、畫面不要機器感／電腦感、簡潔清晰好懂、好玩的新想法（不限）。硬限制：模擬與 FINGERPRINT 不能變（新玩法只能走新規則碼）；繪圖 p95 預算緊（已 9.61 ms，上限約 9.8）。
請：
1. 讀程式確認紙片感與機器感的技術成因（引用 檔案:行）：scripts/ui/art.gd、sprite_cache.gd（烘焙影格、face 翻面）、battle/battle_units.gd（face、死亡、受擊）、units/gait.gd、map_art.gd、ui_base.gd。
2. 每條做法的實作方式與成本：連續轉身（烘焙多少中間影格、快取頁大小與記憶體）、相位錯開、次級動作、假厚度、接觸陰影、手繪抖動線（不能每幀重算的做法）、擺陣拿起放下。估人時與 p95 影響，提出省效能的配套。
3. 上網查並引用：2D 轉身與 paper-flip 的業界做法、squash & stretch、程式化 2D 次級動作、手繪感渲染（wobble line、boiling）、自走棋可讀性做法。
4. 對 seed.md 每節 A～E：同意／修改／反對；新玩法 D7 是否可以不碰 FINGERPRINT（規則碼怎麼加）。
5. 你自己的新想法（至少 5 條）。
回答（繁中、1800 字內）：分「P0／P1／P2／不做」，每條含做法、風險、驗收方法、人時。最後一行「結論：…」。
