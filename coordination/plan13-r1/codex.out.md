已唯讀完成指定檔案核對；未改檔、未開遊戲、未跑測試。工時：S＝1–2、M＝3–5、L＝6–10 人日；內容量產另計。

1. **P1／L｜規模**：建議殘局 **100**、試煉 **30**，先交付50／20。[TABS](https://landfall.se/tabs-switch-info)借鏡多戰役分章；[Puzzle Lab](https://news.blizzard.com/en-us/article/21964710/update-12-0-august-2-the-boomsday-project)逾100題、四類目標；[Into the Breach](https://store.steampowered.com/oldnews/?appids=590380&enddate=1793516400&feed=steam_community_announcements)增12任務與3種附加目標。數量是本案建議，非競品等量要求。〔docs/STATE.md:89〕

2. **P1／L｜內容配額**：保留25關，新增混兵35、地形20、特殊目標20；20兵跨關混搭，每方維持最多10種。題材含貓羊連鎖、幽靈穿牆、護送醫者、限兵鏡像。〔docs/STATE.md:17、22〕

3. **P0／M｜格式**：新增版本、章節、部署、地圖／尺寸、雙方卡池、技能設定／時間表、目標、星級、難度；提示沿用雙語欄位。地形關走自由部署，舊格子座標不轉換。〔game/data/puzzles.json:2、8；game/scripts/core/ruleset.gd:283〕

4. **P0／L｜相容**：舊關預設值、ID、排序與舊模擬分支保留；新目標先由場景層判定，另存關卡版本／摘要。若改提前結束、傷害歸屬或雜湊，新增明確版本分流；分享新增內容須新格式，舊碼位元組不變。〔game/scripts/core/battle_sim.gd:148、233；docs/STATE.md:52〕

5. **P1／L｜技能與目標**：撐N秒用整數tick；保護用穩定單位標記；指定兵擊殺須定義召喚、反傷、同tick歸屬；限隻數在部署驗證，鏡像由資料生成。技能開局最早第60tick；真正tick0效果另開版本。現有重播腳本接管雙方，敵方腳本＋玩家操作須拆流。〔game/scripts/core/cmd_defs.gd:22；game/scripts/core/battle_sim.gd:1395〕

6. **P0／M｜統一驗證**：遊戲、生成器、求解器、測試共用建場與判星；先修驗證器截斷百分比、抽樣未完整驗合法、三星證明直接追加兵的漏洞，再做量產。〔game/tools/validate_puzzles.gd:55、80；game/tests/suites/modes.gd:1007〕

7. **P1／L｜量產**：模板生成→合法性→爬山→篩選→人工挑。自動算空部署敗、隨機勝率、三星裕度、兵種組合／陣位距離、單兵種破解率、移除主角後表現；難度以成功率、搜尋場數、解法密度分級，真人校準。〔game/tools/balance/design_new_puzzles.gd:113；game/tools/validate_puzzles.gd:109〕

8. **P0／M｜搜尋可信度**：多種子、多起點、快取去重，保存合法解與技能紀錄；未找到標「未知」，不得判無解或主角必要。小空間可窮舉證明。試煉現有240迭代實際最多366次候選評估。〔game/tools/balance/star_check.gd:67；game/tools/balance/trial_check.gd:88〕

9. **P1／S｜算力**：本次未實測。先量代表關每場耗時t；每候選預留2,000–5,000場，成本＝場數×t。若t＝0.1–1秒，約3–83分鐘；既有最壞7.5秒則4–10小時，淘汰率另乘。〔docs/STATE.md:65〕

10. **P1／L｜試煉**：舊10關保留；新增20關採手工敵陣，涵蓋奇幻限定、低預算、技能、強制地形。固定種子仍會受AI改版影響，手工配置較能保住題意與三星證明。〔game/scripts/ui/screens/game_modes.gd:20、48〕

11. **P0／M｜介面存檔**：章節＋每頁10關，總星數300／90；舊成就門檻保留，新增章節成就。試煉改穩定ID並遷移舊索引；試玩保留殘局5、試煉1／3。重建字型，驗中英150%、長名、滿星、空章、末頁與手把焦點。〔game/scripts/ui/screens/game_menus.gd:278；game/scripts/ui/screens/game_modes.gd:78；game/scripts/game/presets.gd:3；docs/STATE.md:57〕

12. **P0／M｜驗收成本**：三星回歸只重播證明，不搜尋；35→130場約3.7倍，另有標準解回歸。補合法性、目標／技能重播、ID完整覆蓋，取代寫死25／10；依關卡分片，完整驗收仍全跑，量產搜尋獨立離線。〔game/tests/suites/content.gd:4；game/tests/suites/modes.gd:996、1016〕

結論：有條件
