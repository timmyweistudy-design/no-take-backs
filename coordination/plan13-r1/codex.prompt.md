唯讀，不要改任何檔案、不要開遊戲視窗、不要跑 --steam-test。可用 --search 查資料（附來源網址）。
《落子無悔》Godot 4.6.2 確定性自動對決，v1.0.4。使用者要：**大幅增加殘局關卡與主題試煉的數量，可以 20 種兵混搭，做出好玩的棋局；想加什麼都可以；先列完整方案，不實作。**
先讀 docs/STATE.md、game/data/puzzles.json（_說明）、game/scripts/game/puzzles.gd、game/scripts/ui/screens/game_menus.gd:259-310（殘局清單，一頁 2×5）、game/scripts/ui/screens/game_modes.gd:1-110（試煉 TRIALS、星數）、game/tools/balance/star_check.gd、trial_check.gd、design_new_puzzles.gd、game/tools/validate_puzzles.gd、game/tests/suites/content.gd test_puzzle_solutions、modes.gd test_star_solutions、game/scripts/game/presets.gd（DEMO_*）、game/scripts/core/cmd_defs.gd。
現況：殘局 25 關（經典 10、新兵 5、奇幻 10）都在格子部署、平原、沒有技能；試煉 10 關＝固定地圖＋AI 性格＋難度，敵陣是 AI 用固定種子生成。

請以「程式可行性、驗證管線、風險」為主回答（繁中、1500 字內），每條附 檔案:行號：
1. 數量目標：你建議殘局、試煉各做到多少？依據（查同類遊戲：TABS 戰役、Hearthstone Puzzle Lab、其他自動戰鬥／戰棋殘局）。
2. 資料格式要擴充什麼：地形或地圖、敵方技能腳本、我方開局技能、不同勝利條件（撐住 N 秒、保護某隻、指定兵種擊殺、限隻數、鏡像）、事前提示。哪些會碰到舊場次指紋或位元組不能變的鐵則？怎麼分流？
3. 量產管線：生成→求解（現有爬山）→篩選（什麼都不放會輸、主角兵種必要、解法多樣、不太簡單、難度分數）→人工挑。哪些指標可自動算？求解器怎麼避免「找不到＝不可能」的誤判？算力估計（一場模擬多久、一關要搜多少場）。
4. 試煉：要不要改成手工配置敵陣而不是 AI 生成？規則變形（只用奇幻、低預算、開技能、強制地形）？
5. 介面與存檔：清單分頁或章節、星數總計、成就、試玩版範圍、字型重建、版面檢查的極端資料。
6. 測試與驗收成本：star_solutions 的檢查時間會不會爆？
最多 12 條建議，各標 P0／P1／P2、工時 S／M／L。最後一行「結論：可／有條件／不可」。
