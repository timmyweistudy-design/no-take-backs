僅唯讀分析，未改檔、未跑 Godot。工時：S≤1、M＝2～3、L＝4～7 人日；以下數字是驗收目標，非本次實測。路徑簡寫：U＝`game/scripts/ui`、C＝`game/scripts/core`、T＝`game/tools`。

1. **P1／M｜動畫，高 CP**：延伸現有程式部件變形＋關鍵影格表，再烘圖集；已有走路8格、攻擊8格，先改善前搖、命中、收招與技能辨識。完整骨架成本高；shader 留給閃白、輪廓。先試3兵再擴20兵。〔U/units/kit.gd:105、U/units/kingdom.gd:1、U/units/fantasy.gd:6、U/sprite_cache.gd:21〕

2. **P0／M｜畫面預算，防退化**：維持標準48兵、自訂80兵，壓測另含召喚物；不能把80當總上限。歷史48兵繪圖p95＝4.62ms，建議目標≤6ms、整幀≤16.7ms；80兵先以≤33.3ms驗證。避免缺圖時大量回退即時畫圖。〔docs/STATE.md:15、C/battle_sim.gd:937、U/sprite_cache.gd:64、docs/perf/s1-baseline.json:74〕

3. **P1／S｜動畫驗收，減少人工成本**：固定時間、步態相位、左右朝向，產待機／移動／攻擊／受擊／技能接觸表；比剪影、腳底漂移、裁切及隊伍辨識，像素差容許抗鋸齒誤差。另驗回放跳轉後姿勢。〔U/units/gait.gd:51、U/battle/battle_state.gd:280、T/atlas_check.gd:54〕

4. **P0／M｜版本隔離，最高優先**：升級、詞綴、新兵、傷害天氣與戰中事件均可能改digest；新目標若只讀戰後狀態風險較低。新增明確規則欄位與新碼分流，缺欄位走原路徑；保留 `b8fe741bcbfcf800`，不可重烘舊金標掩蓋改動。先修正文獻衝突。〔CLAUDE.md:15、docs/STATE.md:58、C/battle_sim.gd:1821〕

5. **P1／M；P2／L｜玩法可行性**：V1.1先用既有護送、死守、斬首、地形與時序重組少量關卡，加入真人難度校準。遠征已有三選一，先加戰間事件；戰中天氣、永久詞綴另開規則版本，避免一次擴張測試矩陣。〔docs/STATE.md:26、docs/STATE.md:36、docs/STATE.md:79〕

6. **P1／M｜拆檔與資料化，降低修改風險**：先拆1154行大廳的操作、排版、兵種簡介；共用簡介資料與列元件。625行畫面入口只抽路由。1983行模擬最後才拆技能／地形助手，保持執行與排序順序；風險依序上升。〔U/lobby_view.gd:252、U/lobby_view.gd:907、U/game_screens.gd:421、C/battle_sim.gd:1078〕

7. **P1／M｜模擬效能，目標快20%**：先量快照配置、支援尋敵與碰撞，嘗試重用陣列；不可任意改遍歷、平手裁決。相同硬體同批種子比較中位數／p95，舊digest逐場相同才接受；不同日期紀錄不能直接比較。〔C/battle_sim.gd:299、C/battle_sim.gd:1537、T/perf_probe.gd:26、docs/perf/v8-final.json:175〕

8. **P1／M｜AI與求解器，減少重算**：候選先去重，評分快取納入規則、雙方陣型、技能腳本；保留種子、候選順序與平手結果。求解器已有快取，優先分關卡工作；目標AI／產關耗時降20～30%，不要只增加執行緒。〔C/hard_ai.gd:24、game/tools/balance/puzzle_forge.gd:12〕

9. **P1／M｜啟動與記憶體**：評估建置時預烘atlas，鍵含畫法版本與色盲配色；先試少數兵種。歷史啟動2244ms，目標≤2秒；20場及20次換色後，暖機記憶體增量≤5MB、貼圖不持續增長。〔U/sprite_cache.gd:49、docs/perf/s1-baseline.json:30、docs/perf/s8-memory.json:4〕

10. **P0／M｜測試分層，縮短等待**：已有12工作平行與分片；瓶頸是測試快取納入全部suite、資料及字型。改精確相依表，補動態載入漏判防線；日常目標≤60秒、無快取先降至≤750秒。存檔測試隔離前維持串行。〔T/check.py:19、T/check.py:70、T/check.py:197、docs/STATE.md:90〕

11. **P1／M｜合併重算、縮小截圖**：標準解與三星解若輸入完全相同，共用模擬結果，各自保留斷言；不刪鏡像、相容與金標。版面日常兩組約182張，再支援受影響畫面；里程碑保留546張及手把流程。〔game/tests/suites/content.gd:4、game/tests/suites/modes.gd:997、T/layout_check.sh:21〕

12. **P1／S｜檔案與token，高 CP**：未證實死碼不刪；先查引用、匯出依賴及UID，只清有歸屬的暫存。測試雙清單改單一登錄。CLAUDE僅31行、skills僅5～9行，無須硬縮；STATE移出歷史驗收，新增模組索引，AI每次只讀相關函式與摘要。〔T/layout_check.sh:7、game/tests/run_tests.gd:5、CLAUDE.md:28、docs/STATE.md:89〕

結論：建議 V1.1.0 範圍＝動畫試點、介面模組化、既有機制關卡精修、測試相依優化與效能防退化；新規則型大玩法延後。
