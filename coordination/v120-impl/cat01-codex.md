已核對指定規劃、ledger 與兩段 commit；全程只讀，未跑遊戲或產檔驗收。以下為靜態審查，量測數字沿用 ledger。

必改共 8 條（路徑均相對 `game/`）：

1. **A1 部分完成**：輸入已複製、重開會退休舊工作，未見明確過期結果回寫；修改「如果」陣型也不必取消不變的原局基準。但逾時後基準永遠空白、持續顯示計算中且不能重算；啟動失敗又退回無期限同步。應提供失敗／重試狀態，保留背景計算期間的操作能力。`scripts/ui/replay_view.gd:551、565、705`。

2. **B1 防漏不足**：依賴正則仍只收 gd/json/csv；未知 load 只補四個素材目錄，沒有依規劃強制實跑。稽核亦忽略兩次指令的退出碼，兩邊同樣失敗仍可能報 AUDIT OK。應補完整依賴或停用該步快取，並要求兩次檢查成功、步驟集合相等。`tools/check.py:16、46`；`tools/audit_selection.sh:9、28`。

3. **B2 部分完成**：TIME 可作執行紀錄，但只檢查 missing／dup，沒檢查額外 ID；FILES 解析失敗還會退成空表。應核對雙向差集並讓解析失敗直接擋下。`tools/check.py:65、358`。

4. **B3 鍵目前未見漏模擬輸入**：核心遞迴雜湊＋完整關卡／部署／軍令涵蓋現有呼叫；但固定抽樣讓同一批未抽中的鍵永遠免複算，並非「每次命中隨機 5%」。應改逐次抽樣並加入快取格式版本。`tests/sim_cache.gd:15、32`。

5. **B4／B5 部分完成**：一般逾時、非零退出與腳本錯誤有記錄；但收尾只驗 JSONL，PNG 寫失敗仍能全過。應檢查 save_png 回傳與實際圖片集合，收集各 worker 退出狀態；預設兩工目前只有兩組比較證據，須補全24組。`tools/dev_main.gd:462`；`tools/layout_check.sh:35、44、70`。

6. **B6 會漏真實狀態**：固定 delta 可供視覺比較，但不能取代真實時間驗收；`_snap` 還直接把 clutch_t 改成0.8，跳過出入場。應另保留真實時間流程及過渡狀態截圖；跳過存圖時也須保留等待，否則 LAYOUT_SHOTS 會改變後續時序。`scripts/ui/game_screens.gd:526`；`tools/dev_main.gd:449、455`。

7. **B8 統計錯誤**：用 A、B 混合標準差，會把版本差異算成雜訊；純記憶體試算 A=[100,101]、B=[10,11] 仍判雜訊內。應以各輪 ABBA 差值估計波動，拒絕失敗或殘留輸出。`tools/perf_ab_sum.py:15`；`tools/perf_ab.sh:14`。

8. **1.1.0 補審**：NTD1 缺 rules 欄可通過前置驗證後越界取值；skip 只查歷史存在，重複紀錄也接受，應逐筆消耗比對。GIF 設120秒期限但編碼只看 stop，期限無效。`scripts/game/duel_code.gd:52、70、114`；`scripts/game/gif.gd:52`。entry_valid、GIF寫入錯誤修正，以及 A7、版面、N6回收、B10、B14、A4／A22搬移未見其他明確阻擋錯誤。

其餘逐項：**A2部分**，234→78ms仍未達<40；`sprite_cache.gd:242`的 CLEAR_ONCE 累積符合[官方語意](https://docs.godotengine.org/en/stable/classes/class_subviewport.html#enum-subviewport-clearmode)，但 Compatibility 全頁像素一致仍待驗。**A3完成邏輯**（`game_menus.gd:832`）；**A4部分**，測試直接呼叫完成函式，缺規劃的 FakeLB三筆／逾時案例（`modes_live.gd:260`）；**A5文件已改，驗收未齊**。**B7部分**，黑色採抽樣、單位框硬編碼（`dev_main.gd:270、293`）；**B9缺**指定 profile、逐場耗時與重複比例。

下一步先修上述防漏，再補同 commit 稽核、24組單／多工比較與視覺簽核；重測 A2、完整檢查<600秒，未達者保留未完成。

結論：有條件