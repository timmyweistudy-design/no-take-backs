唯讀審查，不要改任何檔案。《落子無悔》Godot 4.6 確定性自動對決。讀方案初稿 docs/2026-11-04-v1-release-plan-v9.md，對照 game/scripts/core/battle_sim.gd、army.gd、formations.gd、ruleset.gd、mirror_check.gd、game/scripts/ui/battle_view.gd、art.gd、sprite_cache.gd、view_buffer.gd、free_place.gd、game/scripts/game/battle_code.gd、game/tools/check_all.sh、game/tests/run_tests.gd。可上網查資料（整數確定性尋路、Godot 2D 分層貼圖效能）。

請（繁體中文、1400 字內、附 檔案:行號，沒證據別列）：
1. §1 哪些事實錯或漏。
2. §3 步態：相位由位移算，在重播跳轉、變速、view_buffer 內插、精靈圖快取下怎麼落地？加格 vs 身體／腿分層貼圖哪個好（記憶體、繪製次數、Compatibility）？給結論。
3. §4.5 可變地圖：W/H 改欄位會不會動到舊路徑位元組與效能？鏡像、騎兵繞翼、刺客背刺、吸塵貓、擊退碰牆、孢子圈、召喚物落點、全場部署有什麼坑？尋路方案對不對、有更簡單的嗎？草叢、高地、噴口哪個最危險、該砍嗎？
4. §5、§6 新功能哪些和既有代碼格式、存檔、ruleset 打架；哪些成本遠高於價值該砍。
5. §8、§9：拆檔順序與風險；測試分片（run_tests 依賴共用狀態嗎？）；依變更挑檢查會漏什麼；45 分降 8 分的可行性。
6. §10 順序與各階段工期估計。
最多 15 條「定稿前必須改」。最後一行「結論：可定稿／有條件／不可」。
