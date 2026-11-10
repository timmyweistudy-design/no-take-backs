本輪為只讀靜態審查，未執行會寫檔的測試，未修改模擬或 FINGERPRINT。以下行號依目前工作樹。

**必改（10 條）**

1. **P0｜steam.gd:344、358、391**  
   A 逾時後僅停 3 秒便送 B；A 的遲到找榜失敗會直接結束 B，同榜下載／上傳也會因 handle 相同而誤收，甚至清掉 B 的待送。舊上傳未完成時再送，也破壞單筆在途限制。應以 SDK call-result 身分關聯請求；無法關聯時，逾時只結束 UI 等待，通道須維持隔離，不能靠固定冷卻時間。參照 [Valve 規範](https://partner.steamgames.com/doc/api/ISteamUserStats#UploadLeaderboardScore)。

2. **P0｜steam.gd:105、117**  
   `storeStats()` 回 true 即把 `store_ok` 設 true；若回呼不來，就永久停止重試。初始化／補送又忽略 `setAchievement()` 失敗，後續成功送出可掩蓋未設成功的成就。改用 dirty／inflight／已確認批次，合併重入解鎖、檢查每筆設定結果、加確認逾時；僅成功回呼清除對應批次。[StoreStats 文件](https://partner.steamgames.com/doc/api/ISteamUserStats#StoreStats)

3. **P0｜puzzles.gd:315**  
   已取消或期限已過，但戰鬥不足 64 tick 就結束時，完全不檢查 ctl，仍回成功，三考可能寫紀錄。進入模擬前、每次迴圈及回傳 outcome 前都檢查取消／期限；只改運算包裝，不動模擬。

4. **P0｜game_v16.gd:1669**  
   `Thread.start()` 失敗便在主執行緒無期限重算，會卡畫面且失去取消能力。應回報計算失敗並容許重試，或採可逐幀取消的工作；不可退回無 ctl 的同步運算。

5. **P0｜game_v16.gd:1698、1793**  
   計算中按結果頁「返回」或 Esc，只關 overlay，工作仍可寫星數；同題重新開始又可能因 mode key 相同而不取消舊工作。統一離開處理：增加工作世代、呼叫 `_trio_cancel()`，並要求結果仍屬當前嘗試才准寫入。

6. **P0｜workshop.gd:247、269；game_modes.gd:325**  
   匯入直接同步重跑作者解，最長可凍結主執行緒約 8／24 秒，玩家無法取消或離場。將驗解移至背景工作，從 UI 傳入取消控制，補工作淘汰與退出回收。

7. **P0｜save.gd:91、543**  
   `_quarantine()` 雖回報失敗，呼叫端仍忽略；隔離失敗後 `_write()` 仍可能以 tmp 覆蓋原壞檔，證據消失。隔離失敗應阻止該路徑覆寫，保留待存狀態並顯示失敗。

8. **P1｜game_v16.gd:1759；game_menus.gd:1313**  
   從殘局牌開三考，再按畫面返回會直接回首頁；Esc 卻依 nav_stack 回卡片，路徑不一致。導覽、出題台等仍有同類 `overlay = ""`。統一走 `_nav_back()`，並保存原卡焦點。

9. **P0｜.github/workflows/ci.yml:86、103**  
   夜間／標籤驗收仍只匯出 Linux 正式版，沒有 Linux Demo 與兩個 Windows 成品，無法覆蓋 T2 四成品門檻。完整層須建立並啟動四成品，逐一驗退出碼、demo、版本及 `ok`；快速層則避免每次都跑完整匯出。

10. **P1｜dev_main.gd:1276、1297**  
    `--sil` 在 `super._ready()` 後才切 `Save.prefix`；此前已載入玩家資料並可能初始化 Steam、補送成就。應在父類初始化前辨識 `--sil`，先設定隔離前綴及工具模式；PNG 寫入失敗也須非零退出。

**其餘建議**

- **v16_guide.gd:11、17**：教學勝利也計入 `stats.games/wins`，完成教學即可跳過 AI 推薦，首關殘局後亦可能過早推遠征。改用明確 AI 勝利旗標及正式殘局通關數。
- **codex_view.gd:373、377**：投彈兵缺少 `SPLASH_R` 示意；沙漏範圍仍寫死 2500。補技能圈並引用常數。
- **game_v16.gd:34**：回報寫檔在 close 前取錯誤，未驗證落盤內容；建議 flush 後檢查並讀回比對。
- **game_core.gd:115；game_result.gd:305**：試煉重打已延後至 ID 設定後套用；補自由部署與固定兵案例，防後續順序回歸。

結論：不可。