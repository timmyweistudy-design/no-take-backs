建議 V1.4 主打「玩家寫下戰爭故事」：以跨局決策、宿敵與覆盤建立大作感。以下為靜態審查，未改檔、未跑 Godot。

**近年證據與判讀**

- 非同步＋組合構築：[Backpack Battles](https://game.shochiku.co.jp/news/achieved-1-million-units-sales-worldwide/)於2024搶先體驗、2025突破百萬套；證明「不等人也能對抗真人陣型」有市場。
- 賽季＋流派：[Mechabellum 2024公告](https://www.paradoxinteractive.com/media/press-releases/paradox-arc/mechabellum-launches-on-september-26th)列出84%好評、專家與外觀獎勵；值得借鏡的是持續變化的決策。
- 戰術試錯：[Tactical Breach Wizards](https://store.steampowered.com/app/1043810/Tactical_Breach_Wizards/)結合技能連鎖、重試與編輯器；[2026報導](https://www.pcgamer.com/games/strategy/tactical-breach-wizards-sold-twice-as-well-as-suspicious-developments-previous-games-but-more-importantly-it-failed-catastrophically-to-lose-an-igf-award-all-we-can-say-is-were-sorry-and-well-try-to-do-worse/)引述其營收為過往作品兩倍。
- 桌遊數位化：[BGA於2024達千萬註冊帳號](https://corporate.asmodee.com/news/asmodee-and-board-game-arena-celebrate-10-million-users-milestone-cementing-the-online-board-gaming-platform-as-the-industrys-1/)，強調跨裝置易玩。

我的推論：降低對局摩擦、讓組合可探索、讓成果可分享，比單純加兵更值得優先驗證；上述成績不能證明單一功能的因果。

**技術基準**

A：[battle_sim.gd](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:2)全整數確定性；新增戰中機制須新規則欄位／碼，缺欄位走舊路，保住 FINGERPRINT。

B：[hard_ai.gd](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/hard_ai.gd:20)已有候選陣模擬，但大局可能耗秒。

C：[workshop.gd](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/workshop.gd:2)已有作者解驗證，目前限格子殘局。

D：[steam.gd](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd:48)未接排行榜／UGC；[Valve允許榜單附幽靈資料](https://partner.steamgames.com/doc/api/ISteamUserStats#AttachLeaderboardUGC)，仍須實測封裝、版本分池、配對與防作弊。

以下人時含設計、介面、內容與回歸；不含長期營運。

1. **宿敵戰記**：七戰追捕會記住你陣型的將領；如 Mechabellum，反制與復仇有戲。大180–300h；風險B、遠征續存遷移。
2. **雙封蠟戰書**：雙方先鎖三陣，再揭示交鋒；如 Backpack Battles，猜拳升級成讀心。大220–380h；風險D，公開附檔無法保密，需可信承諾機制。
3. **戰利品契約**：每戰選增援或苛刻條件換高報酬；如 Backpack Battles，貪心塑造流派。中60–100h；沿用遠征戰前參數，須驗證可通關。
4. **一子之差**：敗後只准換一兵，再看勝負如何翻轉；如 Wizards，立即產生頓悟。中40–70h；風險B，限制搜尋量。
5. **軍令連鎖**：開戰前排三道定時技能，解連鎖謎題；如 Wizards，享受精準配合。中55–95h；已有技能紀錄，新增觸發條件走A。
6. **不對稱委託**：一方求勝、一方保住指定兵；如桌遊秘密任務，勝負有雙重懸念。中65–110h；現有殘局目標可借用，多人結算須新增。
7. **每週密封棋盒**：固定卡池與預算，全員解同題；如 Mechabellum賽季，持續換環境。中45–80h；沿用daily，線上排名另算D。
8. **接力殘局**：朋友破題後只能改兩兵再傳回；如BGA回合制，低壓互相刁難。中70–120h；風險C，需新碼保存修改鏈。
9. **敗因透鏡**：點傷害來源並排比較替代方案；如 Wizards，看懂就想再試。小20–35h；已有傷害統計，反事實須B。
10. **戰役明信片**：把翻盤瞬間、陣型與重播碼印成戰報卡；如BGA戰績，成就能展示。小16–28h；沿用重播，存圖與文字溢位需驗證。

**seed逐項評分**

順序為可行／好玩／契合；5最高，按原案完整範圍估。

| #／方向 | 分數 |
|---|---|
|1 幽靈軍團|3／5／4|
|2 劇情戰役|3／4／4|
|3 指揮官|4／5／3|
|4 第三軍隊|2／4／3|
|5 合成升階|3／4／2|
|6 編輯器＋工坊|3／5／3|
|7 合作|3／4／3|
|8 季節賽|3／4／4|
|9 AI教練|4／5／5|
|10 外觀收藏|4／3／4|
|11 影片高光|3／4／3|
|12 天氣規則|3／3／2|
|13 本地化|4／3／5|
|14 觸控／Deck／手機|2／3／3|

14分數受手機移植拉低；若只做Deck可行度4。11若縮為戰報卡也更可控。

**推薦組合**

大：宿敵戰記；中：戰利品契約＋一子之差；小：敗因透鏡＋戰役明信片。合計約316–533h，另留25%整合緩衝。先用一名宿敵、三戰小樣真人試玩，驗證玩家是否想復仇再擴寫。

結論：V1.4先讓既有20兵產生值得記住的對局，再把驗證成功的陣型故事帶上線。
