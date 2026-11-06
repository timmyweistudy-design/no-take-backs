唯讀，不要改任何檔案、不要開遊戲視窗、不要跑 --steam-test、不要跑 Godot。可用 --search 查資料（附來源網址）。
《落子無悔》Godot 4.6.2 確定性自動對決，現在 v1.0.5（殘局 100、試煉 30、20 種兵、手動技能、6 地圖）。使用者要規劃 **V1.1.0 更新與優化方案（先不實作）**，範圍：角色（動畫、動作、細節、技能）、排版清晰簡潔、美化、關卡好玩多樣、不枯燥的機制與玩法、後端效能、程式碼、檔案、token、測試、時間與 CP 值；可以補充額外項目。
你負責「程式、效能、測試、檔案結構、token 與時間成本、可行性與風險」。先讀 CLAUDE.md、docs/STATE.md，再自行 grep：game/scripts/ui/units/*.gd（兵是程式畫的，kit.gd/kingdom.gd/fantasy.gd/gait）、game/scripts/ui/battle/*.gd、game/scripts/core/battle_sim.gd（1983 行）、game/scripts/ui/lobby_view.gd（1154 行）、game/scripts/ui/game_screens.gd、game/tests/run_tests.gd、tools/check.py、tools/check_all.sh、tools/layout_check.sh、build/tmp/check/summary.json、docs/perf/*.json。
已知：check_all 無快取 Windows 版約 984 秒（37 步、2709 測試）、有快取 35 秒；版面 546 張截圖；鐵則：舊場次 FINGERPRINT b8fe741bcbfcf800 不能變、模擬只用整數且左右鏡像、畫面狀態不進模擬。
請回答（繁中、1800 字內），每條附 檔案:行號：
1. 角色動畫升級在現有「程式繪製」架構下怎麼做最划算（骨架／關鍵影格表／預烘焙 sprite atlas／shader）？效能預算（最多幾隻兵同場、畫圖成本）、怎麼測（姿勢截圖比對？）。
2. 新機制（例如兵種升級／詞綴、新兵、新目標、天氣或事件、Roguelite 遠征）哪些會碰指紋鐵則，怎麼版本分流。
3. 程式碼健康：哪些大檔該拆、重複程式、死碼、可刪檔、資料驅動化；風險排序。
4. 效能：模擬、AI 候選、求解器、啟動時間、記憶體；量測方法與目標數字。
5. 測試與驗收時間：怎麼把 984 秒與版面 546 張縮短（分層、只跑受影響、平行、抽樣），以及哪些測試是低價值可合併。
6. token／開發 CP 值：AI 協作時怎麼少讀大檔、哪些文件要瘦身、skills 怎麼調。
最多 14 條建議，各標 P0／P1／P2、工時 S／M／L、預期效益。最後一行「結論：建議 V1.1.0 範圍＝…」。
