《落子無悔》V1.6.0 實作審查第 1 輪。只讀檔、不改檔、不執行會改東西的指令。
方案：docs/history/2026-11-10-v1.6.0-plan.md（§2 各項範圍）、裁決 coordination/v160-impl/ledger.md。
變更：`git diff fa4707e HEAD -- game`（主要在 game/scripts/ui/screens/game_v16.gd、game/scripts/game/v16_*.gd、game/scripts/core/adj_defs.gd、ruleset.gd、battle_sim.gd、puzzles.gd、workshop.gd、steam.gd、sfx.gd、game_menus.gd、game_result.gd、game_place.gd、game_core.gd；測試 game/tests/suites/v16.gd）。
請找真正的錯（最多 10 條，依嚴重度排序），每條附 檔案:行號、怎麼觸發、建議修法。重點：
1. 鐵則：舊場次位元組不能變（FINGERPRINT b8fe741bcbfcf800）；#22 相鄰陣法（rules.adj、NTBR6）關掉時是否完全走舊路徑；代碼「一組規則只有一種寫法」。
2. 狀態旗標（rush、rift_on、trio_on、fog_on、ga_coop、tv_marks）在換模式、返回標題、續局、重播時會不會殘留或互相干擾。
3. 存檔新欄位（funnel、seen、mastery、notebook、daily_streak、daily_pend、rush_best、rift_best、trio_clear、gauntlet_run.coop）的驗證與相容；網路來的排行榜資料（unpack_free）驗證。
4. 背景執行緒（教練 co_thread）與離開畫面；結果頁按鈕收合（分享面板）有沒有讓某些模式少了必要按鈕。
5. 是否有方案寫了但沒做到、或做錯的。
最後一行：「可收尾」「有條件」或「不可」。繁體中文，1500 字以內。
