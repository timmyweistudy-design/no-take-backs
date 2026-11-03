初稿涵蓋面廣，但**把多項既有功能列成新工作，也把清理與大重構排得過早**。建議先補資料正確性、存檔防護、測試可信度與匯出驗收，再投入美術與內容。

本次依 HEAD `31c4241` 靜態查核，另執行 CSV／音訊盤點、素材登記與字型涵蓋檢查；後兩項通過。未執行完整 Godot 測試或重新驗收畫面，沒有修改檔案。以下路徑皆相對 repo 根目錄；成本沿用初稿 S／M／L 定義。

**1. 初稿需要更正的地方**

| 初稿項目 | 查核結果與修正 |
|---|---|
| E6「設定頁是長清單」 | 已有顯示、聲音、操作、輔助四組。刪除「新增分組」，改為驗收焦點與說明欄。[game_screens.gd:1393](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1393) |
| L1「試玩版沒有結尾畫面」 | 已有系列結束後的願望清單區；真正缺的是商店網址與成品驗收。不要直接改成打三局強制結束。[game_screens.gd:1916](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1916)、[steam.gd:32](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd:32) |
| L3「沒有遙測」 | 本機試玩紀錄、戰後評分、開啟紀錄資料夾都已存在。應補紀錄內容與分析工具。[save.gd:111](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:111)、[game_screens.gd:357](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:357) |
| K2／C2「只靠配色分隊」 | 已有藍圓／紅菱形腳底圈，圖表已有紅方斜線。可以改善混戰中的可見度，不能宣稱完全沒有形狀提示。[art.gd:426](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/art.gd:426)、[charts.gd:142](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/charts.gd:142) |
| D1 要新增區域跳字合併 | 已依區域、事件種類，在 **0.35 秒**內合併。應調參與測量遮擋率。[battle_view.gd:434](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:434) |
| I3 要新增文字相交、英文 150% | 已有文字相交、文字壓按鈕檢查；版面腳本已跑雙語×三字級。尚可補的是按鈕框互撞、特殊狀態與探針涵蓋。[main.gd:138](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/main.gd:138)、[layout_check.sh:8](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/layout_check.sh:8) |
| 音訊 72 WAV、未壓縮；需要單聲道 | 實際為 **36 WAV＋36 `.import`**，原始 WAV 全是單聲道；匯入已有 `compress/mode=2`。不能以原檔約 5 MB 推論出貨體積或承諾減少 70%。[gen_audio.py:2](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/gen_audio.py:2)、[music_title.wav.import:24](/mnt/c/Users/timmy/projects/no-take-backs/game/audio/music_title.wav.import:24) |
| B3「自由模式困難 AI 只用啟發式」 | 雖不使用舊反制庫，仍會對候選陣型實際模擬並選最好結果。重產自由反制庫是額外候選來源，不是補上搜尋能力。[hard_ai.gd:25](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/hard_ai.gd:25)、[hard_ai.gd:49](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/hard_ai.gd:49) |
| A7「走勢只看得出輸贏」 | 結果圖已有最多三個關鍵時刻；缺的是破陣／背水／死亡等種類，以及點擊跳轉。[game_screens.gd:1872](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1872)、[game_screens.gd:1986](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1986) |
| A6「沒有暫停檢視」 | 暫停已有；當下單位資訊面板沒有。應改寫為「暫停後可選兵檢視」。[replay_view.gd:30](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd:30) |
| C1／C6「同一身體、表情只有幾種」 | 騎兵有獨立馬體；醫者白袍、鼓手胸鼓、狂戰士赤膊雙斧已存在，狂熱表情與光圈也已實作。剪影辨識仍值得測，但提案部分重複現況。[art.gd:169](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/art.gd:169)、[art.gd:328](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/art.gd:328)、[battle_view.gd:920](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:920) |
| F1 七組重複鍵列 P0 | 七組確實重複，但目前內容完全相同，尚未造成翻譯衝突；可降 P1。真正的 CSV 四欄錯誤更應優先，見下表。[strings.csv:258](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:258) |
| M1「最壞 6.5～7.5 秒」 | 現有報告支援密集案例平均 7.401 秒、最壞 **7.935 秒**；且是特定探測案例，不能當所有合法配置的上限。[v5-probe.json:1](/mnt/c/Users/timmy/projects/no-take-backs/docs/perf/v5-probe.json:1) |
| §1.4 行銷數據 | 「結尾提升 5～10 個百分點」未附可核查的對照實驗；引用的 [StraySpark 原文](https://www.strayspark.studio/blog/steam-next-fest-demo-optimization-wishlists)反而建議約 15～20 分鐘，不能直接歸納為 20～40 分鐘。[另一引用文章](https://howtomarketagame.com/2024/06/24/do-demos-help-earn-wishlists-steam-next-fest-june-2024/)也沒有支持「新品節前 6～12 個月推出」的結論。刪除硬數字，保留為待試玩的假設。[初稿:43](/mnt/c/Users/timmy/projects/no-take-backs/docs/2026-11-04-grand-optimization-plan-v7.md:43) |

另外，A8 三十個新成就、C5 十兵種勝利動作、H3 工具抽離列 S 都偏樂觀；須算入條件驗證、翻譯、圖集與匯出回歸，至少 M。

**2. 漏掉的優化：22 項**

以下包含對原提案必要的實質補強，不重列純美術偏好。

| # | 問題＋證據 | 可執行提案 | 成本／優先 |
|---|---|---|---|
| 1 | **狂戰士英文被截斷**：逗號未用 CSV 引號包住，實際四欄；載入器只按表頭讀三欄。[strings.csv:160](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:160)、[strings.gd:18](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/strings.gd:18) | 修正引號；新增嚴格欄數、重複鍵、空翻譯、格式參數檢查並接入統一檢查。 | S／**P0** |
| 2 | 英文把派兵「手」譯成 `hand`、玩法譯成 `Turn Draft`，容易誤認為卡牌選秀。[strings.csv:17](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:17)、[strings.csv:384](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:384) | 統一 `turn`、`Alternating deployment`、`End turn`；同步所有提示與規則代碼錯誤說明。 | S／P1 |
| 3 | **技能英文語意不準**：`aura_val` 把攻速寫成 `speed`；背水與最後時刻都叫 `Last stand`；卡池說明稱支援兵不攻擊，但核心允許只剩支援兵時攻擊。[strings.csv:274](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:274)、[strings.csv:177](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:177)、[strings.csv:218](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:218)、[unit_defs.gd:171](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/unit_defs.gd:171) | 改 `attack speed`；區分 Rally／Clutch；雙語補上「戰鬥兵仍存活時不攻擊」。 | S／P1 |
| 4 | 操作提示與實際不一致：提示稱 Enter 開戰，但格子模式 Enter 擺兵、Space／Tab 開戰；另有舊 `1–5` 提示。[strings.csv:453](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:453)、[strings.csv:130](/mnt/c/Users/timmy/projects/no-take-backs/game/data/strings.csv:130)、[game_screens.gd:860](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:860) | 按模式、輸入裝置產生提示；提示與按鍵共用 action 定義，再做 K1 重設。 | M／P1 |
| 5 | **合法 JSON 不代表合法存檔**：讀取接受任何 Dictionary，多個欄位未驗型；例如 `stats` 後續直接指定 Dictionary。[save.gd:40](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:40)、[game_screens.gd:423](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:423) | 對進度、slots、成就、數值與設定逐欄驗型／限值；加入「語法有效但型別錯誤」案例。 | M／**P0** |
| 6 | 未來版存檔直接原樣返回，卻繼續交給舊版消費與寫回；目前測試只驗證「沒有降版」。[save.gd:48](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:48)、[run_tests.gd:792](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/run_tests.gd:792) | 未來版進入明確保護流程：保留原檔，阻止舊版覆寫，提供可理解的提示。 | M／**P0** |
| 7 | **備份恢復後可能毀掉唯一好備份**：主檔壞時讀 `.bak`；下次寫入卻先把壞主檔複製覆蓋 `.bak`，且未檢查 copy 結果。[save.gd:35](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:35)、[save.gd:93](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:93) | 記錄恢復來源，隔離壞檔，僅輪替驗證過的主檔；補主檔損壞＋後續寫入失敗測試。 | M／**P0** |
| 8 | 設定與成就部分寫入忽略失敗，可能顯示成功卻未落盤。[save.gd:106](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:106)、[steam.gd:60](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd:60) | 統一回傳寫入結果、保留 dirty 狀態與重試；只有持久化成功才宣稱已儲存。 | M／P1 |
| 9 | 金標準仍用 `Sim.new(a0,a1)` 舊路徑；自由模式測試多是本版互相比較，**不能鎖住跨提交行為**。[golden.gd:27](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/golden.gd:27)、[run_tests.gd:2454](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/run_tests.gd:2454) | 封存 NTB3＋NTBR2＋NTB5 案例：標準自由、全場、讓子、沙盒、支援兵；跨平台比對並保留舊基準。 | M／**P0** |
| 10 | 「完整鏡像狀態」實際只比 14 欄，事件只比種類／來源／目標；未比傷害、補量、tags，以及多個騎兵／支援狀態。[mirror_check.gd:83](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/mirror_check.gd:83) | 建立測試用完整狀態投影，明定向量、索引如何鏡射；事件比較 payload。保留目前生產指紋格式。 | M／**P0** |
| 11 | 模擬規則版本仍是 1.3.0，新行為由規則物件另行區分；缺少清楚的「格式版本／模擬相容版本」契約。[unit_defs.gd:14](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/unit_defs.gd:14)、[ruleset.gd:11](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd:11) | 列版本矩陣與升版規則；定義哪些改動只影響部署、哪些改變重播結果；避免整理時順手重產全部金標準。 | S／P1 |
| 12 | **UI 測試失敗仍 exit 0**。[run_tests.gd:31](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/run_tests.gd:31) | 修正退出碼；所有 `--only=` 統一要求非零測試數與零失敗，未知名稱直接失敗。 | S／**P0** |
| 13 | CI 沒有 PR 觸發，也未安裝字型檢查所需 `fontTools`；失敗時未保存完整日誌。[ci.yml:4](/mnt/c/Users/timmy/projects/no-take-backs/.github/workflows/ci.yml:4)、[check_font_coverage.py:6](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/check_font_coverage.py:6) | 固定 Python 依賴、加入 PR 檢查與 always-upload 日誌。I2 快速版先量測再承諾三分鐘；避免重複跑測試內已有的 100 場金標準。[run_tests.gd:989](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/run_tests.gd:989) | S／P1 |
| 14 | 卡頓不只重播：跳結果、覆盤重算、困難 AI 都同步跑完整模擬。[battle_view.gd:6](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:6)、[replay_view.gd:347](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd:347)、[hard_ai.gd:49](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/hard_ai.gd:49) | 先改成每幀限時／限 tick 的工作佇列，顯示進度並防重入；測量後再決定快照。 | M／P1 |
| 15 | 試玩紀錄只有全域規則版本／digest，沒有完整自訂規則；單靠陣型不能重建沙盒、讓子與時間限制。[game_screens.gd:357](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:357) | 每局記 battle code、紀錄格式版本與 session／battle ID；補離線彙整工具，避免 battle／rating 重複算局數。 | S／P1 |
| 16 | 平衡報表把 **鼓手與狂戰士名稱順序顛倒**，可能誤讀第 8／9 種的結果。[balance_report.py:17](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/balance_report.py:17)、[unit_defs.gd:12](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/unit_defs.gd:12) | 修正映射並抽查已產報表；讓工具從帶 ID 的共同資料讀名稱，不再各維護列表。 | S／**P0** |
| 17 | CI 驗證原始專案，沒有匯出成品驗收；匯出設定排除 tools/tests，但入口仍包含工具邏輯。[check_all.sh:20](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/check_all.sh:20)、[export_presets.cfg:8](/mnt/c/Users/timmy/projects/no-take-backs/game/export_presets.cfg:8) | 增加正式版／Demo 匯出 smoke：乾淨環境啟動、資料讀取、存讀、音訊、代碼、Demo 上限與完整出貨清單。 | M／**P0** |
| 18 | Steam 文件仍列 15 成就，程式已有 18；自測寫死 Spacewar 成就存在、自己的成就不存在，不能照文件直接換成正式 AppID。[steam-setup.md:24](/mnt/c/Users/timmy/projects/no-take-backs/docs/release/steam-setup.md:24)、[steam.gd:23](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd:23)、[steam.gd:83](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd:83) | 分開 Spacewar／正式 App 自測；同步成就清單、STORE_URL、Demo 設定及離線補送驗收。 | M／**P0** |
| 19 | 版面工具無條件 `rm -rf "$OUT"`，參數錯填可刪掉工作目錄；且綁定 WSL。[layout_check.sh:6](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/layout_check.sh:6) | 限制輸出到專用產物目錄，拒絕根目錄／repo／來源目錄；自動辨認原生 Windows、Linux、WSL。 | S／P1 |
| 20 | `_draw_settings()` 在繪圖時更新 `settings_item`，使狀態依賴繪圖時機；大重構前已有可隔離的小切口。[game_screens.gd:1428](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:1428) | 先分出輸入、狀態更新、繪圖與點擊描述；一次處理設定／結果等低耦合畫面，再評估 H1。 | M／P1 |
| 21 | 圖集固定 160px 格；改長槍、雙斧、勝利動作可能超框。快速重建又會跨兩個渲染等待點。[sprite_cache.gd:14](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:14)、[sprite_cache.gd:31](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:31) | C1 前先做全部姿勢接觸表與透明邊界檢查；重建採單一任務／代次檢查，防止舊結果覆蓋新配色。 | M／P1 |
| 22 | J1 只留 REPORT＋manifest 會失去重算證據；報表工具實際需要所有 JSONL，檔名也使用小寫 `report.md`。[balance_report.py:22](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/balance_report.py:22)、[balance_report.py:75](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/balance_report.py:75) | 歸檔保留原始分片、summary、manifest、commit／工具版本、雜湊及解壓重算命令；新增產物忽略規則。驗證可還原後才移除散檔。 | M／P1 |

**3. 暫不值得做，或應縮小的提案**

- **H1 全面組合化**：上架前收益不足以抵銷輸入、焦點、閉包與共用狀態回歸。先做 #20，再以一個畫面試行；不要同時 H1＋H2。
- **M1 每十秒完整快照**：模擬有 HashingContext、導航、事件歷史與展示緩衝，快照不能只存單位座標。[battle_sim.gd:91](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:91)、[replay_view.gd:61](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd:61) 先做 #14，快照需完整恢復一致性測試。
- **A1 自動斷言輸因**：事件次數不能證明「後排沒保護」「錢浪費」。先呈現可驗證事實，或實際試算一個改動再建議；現有程式已明寫「不宣稱因果」。[game_screens.gd:2009](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:2009)
- **C2 紅方全面換盔甲**：已有形狀圈，先量測遮擋時的分隊辨識；全面換裝增加圖集與辨識學習成本。
- **G1／G3 音樂轉 OGG、單聲道開關**：目前全部單聲道且已有匯入壓縮。先比較實際 PCK 體積、循環接縫與三軌同步，沒有量測收益就不做。
- **M2 禁區增量更新**：已有快取，場上最多數十兵；增量刪除／重疊處理更複雜，沒有瓶頸證據。
- **J6 清 Git 歷史**：181 MB 本身不足以支持破壞既有 commit 引用。先整理工作樹與未來產物，必要時才另案處理。
- **A3 每日挑戰、A8 大量成就、F5 新語言、D6 四季、A2 遠征自由化**：先凍結為 P2。都增加內容驗收矩陣；每日題尤其不能把「有驗證工具」等同「能穩定每日產出好題」。
- **D1 受傷三秒才顯示血條**：可能遮掉醫者選目標與瀕死資訊。先做可選簡化模式，保留選取／跟拍／低血量單位的血條。

**4. 修正里程碑順序**

1. **O0 正確性與防資料遺失**：#1、#5～#7、#12、#16；先修假成功測試與錯誤資料。
2. **O1 回歸與出貨護欄**：#9～#11、#13、#17、#18；建立自由模式基準、匯出驗收與版本契約。
3. **O2 操作與可讀性**：#2～#4、#14、#15；把 A4 自由排兵教學提前，搭配縮小版 A6／A7、D1。
4. **O3 有邊界的結構整理**：#19、#20、H2／H3／I1；每批驗收輸入與畫面。H1 暫不列必經里程碑。
5. **O4 角色與門面**：先 #21，再 C1 小樣、標題、美術與排版；通過辨識測試才擴展十兵種。
6. **O5 出貨收斂**：商店素材重拍、Demo 完整流程、Windows／Linux／手把實玩、存檔升降版演練。
7. **O6 發售後內容池**：每日挑戰、遠征自由化、新語言、額外成就與動畫。

J3 文件索引可早做；J1／J2 歸檔要在 #22 後。**H6 錯誤碼重構也不是純清理**：需檢查錯誤文字是否進入任何相容性輸出，才能安全替換。

**5. §16 決策清單增刪**

- **保留但具體化 C1**：改為「先核准兩至三種兵的剪影小樣與風格方向」，不一次承諾十種全面重畫。
- **H1 改為工程預設**：先局部拆分；只有試點證明收益且需要額外工期時，再請使用者決定全面重構。
- **F5 延後**：先完成雙語語意與操作一致性，再依目標市場決定第三語言。
- **J6 移到條件式決策**：只有量測到儲存／分發困難，並具備備份與引用遷移方案才提出。
- **新增：首發平台與設備承諾**——Windows／Linux 是否同步首發、Steam Deck 是否列正式驗收目標。
- **新增：Demo 與正式版界線**——維持七兵種上限？何時展示升級提示？Demo 進度是否承接正式版？
- **新增：首發功能凍結與工期上限**——先完成安全、操作、出貨護欄；每日題、新語言與大重構是否明確排除首發。
- **新增：重播相容承諾**——未來改平衡時，保留舊版重播行為，或接受版本警告後重算；這會直接決定維護成本。

CSV 修正、測試退出碼、備份保護、錯誤報表名稱與依賴補齊，屬例行正確性工作，不必放入使用者決策清單。