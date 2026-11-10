- **工程長立場：有條件支持正式版整合；先補失敗路徑，再整理命名。**本輪只讀與查網，未改檔、未執行測試。以下成本為工程量；「小／低」代表成本小、風險低。
- 行號縮寫：`G=game/scripts/game/`、`U=game/scripts/ui/screens/`、`K=game/scripts/core/`、`V=U/game_v16.gd`、`S=G/steam.gd`、`D=G/save.gd`、`T=game/tools/`。

- **§0**
  - 改號：**整理，小／低**。同意 App 改 1.0.0，同步 Windows 四處版本欄；保留規則、存檔與代碼版本。證據：`game/project.godot:14`、`game/export_presets.cfg:29,90`、`D:5,93`。勿連帶改產品名稱，避免 `user://` 路徑改變。
  - 併入：**整理，中／中**。同意文件改依功能組織；歷史版本與金標準留存，不能把歷史測試當過期功能刪除。
  - `v16_*`：**整理，中／中**。純邏輯改功能名可做；`game_v16.gd` 先拆職責再命名，勿整條繼承鏈同輪重構。`V:1` 繼承 menus，menus 又繼承 playroom。改名須同步 preload、工具相依、測試登錄與匯出，守住既有 FINGERPRINT。

- **M：逐項程式提案**
  - M1 教學：**優化，小／低**。合併導覽入口但保留教學 ID、完成進度；測返回與重入。`G/puzzles.gd:32`。
  - M2 AI：**不動，小／低**。自由困難已走候選模擬，先量延遲再談換演算法；補過期反制庫回退案例。`U/game_core.gd:207,222`。
  - M3 同機：**新增，中／中**。同種子交換先後手量測，區分鏡像正確與落子順序公平；暫不改規則。`K/turn_placement.gd:30,66`。
  - M4 遠征：**新增，大／中**。整場碼包裝各戰碼、路線及事件；總結共用接力資料。需驗續局可重現。`U/game_core.gd:773`。
  - M5 接力：**整理，中／中**。入口可併遠征，保留獨立模式旗標；驗中途退出、續局輪替及總結。`V:1752,1773`、`U/game_core.gd:802`。
  - M6 殘局：**優化，中／中**。維持唯一 `outcome/play`；主角非必要題先標記，不直接改目標而傷舊星數。`G/puzzles.gd:257,297`。
  - M7 試煉：**不動，小／低**。凍結索引，調題只追加；比對遊戲、工具三星結果。`U/game_modes.gd:19,140`。
  - M8 每日：**優化，中／高**。補跨 UTC、離線補送、版本分榜；下載陣再驗規則合法性。`S:198,219,230`。
  - M9 每週：**優化，中／高**。補跨週、重登、雲端較佳成績保留；榜失敗仍能玩本地。`U/game_playroom.gd:508,562`。
  - M10 遊戲間：**整理，中／中**。五模式補切換後狀態清空案例。草稿誤列：車輪戰已有整場 NTW1，毋須重做。`U/game_playroom.gd:221`、`U/game_result.gd:330`。
  - M11 極速：**優化，中／中**。先明訂計時只算擺陣、暫停是否免時計，再分級題庫；今日種子另鎖題庫版本。`V:635`、`G/v16_rush.gd:23,51`。
  - M12 裂隙：**不動，小／低**。先遍歷週種子驗三異變皆合法；擴池須升 VER，避免同週內容偷偷變。`G/v16_rift.gd:8,31`。
  - M13 三考：**優化，中／高**。加入可取消步進、快照隔離及 Thread.start 失敗處理；設計門檻另校準。`V:1598,1603`、`G/v16_trio.gd:60`。
  - M14 迷霧：**不動，小／低**。固定三分之一；驗排序穩定、重入不洩露全陣，再考慮比例選項。`V:1709,1718`。
  - M15 工坊：**優化，中／高**。匯入限制長度、兵數與模擬時間；重跑作者解可取消。`G/workshop.gd:197`。
  - M16 代碼：**整理，中／中**。建立前綴／格式／規則相容表，驗壞碼與未知版本；不統一重編舊碼。`U/game_menus.gd:1174`。
  - M17 試玩：**新增，中／高**。正式／試玩成品各驗入口及匯入限制，確認獨立存檔。`U/game_modes.gd:291`、`D:49`。
  - M18 娛樂規則：**新增，中／中**。指定槍騎、鼓狂陣，補左右交換及技能重播案例；不改數值。`K/adj_defs.gd:16`、`K/cmd_defs.gd:34`。

- **C／F／T／D／W**
  - C 大檔與繼承：**整理，大／高**。先抽背景工作、模式資料、Steam 排程；保留 UI 分派，逐步縮短繼承鏈。`V:680,1575`。
  - C 死碼／重複／註解：**整理，中／中**。建立呼叫表，納入字串 `call/get/set` 後才刪；`if true` 可清，但不是死碼證據。同名覆寫先驗 super。`U/game_core.gd:182`、`V:509,1755`。
  - C static：**優化，小／中**。檢查實際持有物與退出碼，勿見 static 就搬；UI 尚有字典、陣列快取。`game/scripts/ui/ui_base.gd:685,1174`。
  - F 繪圖／GPU：**優化，中／中**。Deck 成品量 CPU、GPU、p95、8 倍速及最壞規則；桌機數字不能直接當 Deck 預算。`docs/STATE.md:245`。
  - F 貼圖／開機：**優化，中／中**。按兵種需求延後烘焙、量快取峰值及切頁卡頓；不可只降記憶體卻增加戰鬥卡頓。`game/scripts/ui/sprite_cache.gd:81,173,212`。
  - F 背景取消：**優化，中／高**。三考採有界取消；教練共享控制物的讀寫改明確同步。`V:748,764`。
  - T 統一檢查：**優化，中／中**。已有快取、分片、長項先跑；分析 summary 關鍵路徑，隔離存檔後細拆 stateful，PR 快驗、夜間全驗。不能先斷言 <600 秒只能刪測試。`T/check.py:119,240`。
  - T 版面／平衡／量產：**不動，小／低**。保留完整驗收；開發期按受影響組重跑，報告區分抽驗與全驗。`docs/STATE.md:237,239`。
  - T 匯出：**優化，小／高**。自檢須驗 `"ok":true`；Linux Demo 目前只匯出，補實際啟動。`T/export_check.sh:17,38`。
  - D schema／sanitize：**不動，小／低**。不為改號升 4；僅破壞性欄位變更才升版。保留未知欄位與未來版鎖定。`D:44,480`。
  - D 備份／舊 ws：**整理，中／中**。保留十份與試玩隔離；無法歸題的 ws 提供匯出封存，勿猜題遷移或刪除。`docs/STATE.md:131,232`。
  - W 成就：**優化，中／高**。37 個 API ID 對後台發布；檢查 setAchievement 回傳、接收儲存結果、離線重試。初始化補送目前忽略回傳。`S:71,95`。
  - W 排行榜：**優化，中／高**。改全域上傳佇列、節流、超時及明確請求歸屬；目前只按榜互斥。`S:250,307`。
  - W 雲端：**新增，中／高**。驗帳號隔離、Root Overrides、衝突、斷網及 Deck 休眠；不盲開 Dynamic Cloud Sync。`D:55`。
  - W 鍵盤／手把／商店連結：**優化，中／中**。正式 AppID 驗輸入、取消、圖示切換並填商店 URL。`S:59,131`。

- **r0 漏項與查網結論**
  - 找榜失敗 `found=0` 時，讀取請求不完成回呼；還可能錯放最早的上傳。新增失敗／亂序測試。`S:288`。
  - Valve 限排行榜上傳每 10 分鐘 10 次、同時一筆；跨每日／每週也須串行，details 最多 64 ints。[排行榜 API](https://partner.steamgames.com/doc/api/ISteamUserStats#UploadLeaderboardScore)
  - 成就補送不能把「送出成功」當「已儲存」。新版文件已將 RequestCurrentStats 標 deprecated，應依內附 SDK 核對，不能照舊教學硬補。[成就 API](https://partner.steamgames.com/doc/api/ISteamUserStats#StoreStats)
  - 壞檔隔離 rename 未驗回傳；補權限不足與隔離失敗處置。`D:66`。Auto-Cloud 還需每帳號路徑及跨平台覆寫。[雲端規範](https://partner.steamgames.com/doc/features/cloud)
  - 4.6 有 2D batching 改善，但本案用 Compatibility，先量瓶頸再決定換 renderer；工作執行緒不操作場景樹／GPU。[4.6](https://godotengine.org/releases/4.6/)、[執行緒](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html)
  - Deck Verified：800p 預設可玩 30fps；字最少 9px、建議 12px，圖示須符合當前輸入；必要文字輸入須自動叫鍵盤或提供完整手把輸入。[Valve 清單](https://partner.steamgames.com/doc/steamhardware/compat)
  - 加速可用隔離分片＋CI matrix，不能讓快取掩蓋漏依賴；發布仍跑無快取全驗。[GitHub matrix](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)

- **1.0.0 必做前 15 條**
  1. Steam 找榜失敗歸屬。
  2. 全域上傳節流。
  3. 成就儲存確認與補送。
  4. 正式 AppID 整合驗收。
  5. 雲端衝突／帳號隔離。
  6. 三考有界取消。
  7. Thread.start 失敗處理。
  8. 模式切換狀態回歸。
  9. 壞碼／匯入超時防護。
  10. 存檔失敗與遷移驗收。
  11. 四種成品啟動自檢。
  12. Deck 效能實測。
  13. Deck 全手把／鍵盤／字級驗收。
  14. 凍結指紋與完整回歸。
  15. 版本同步、修正過期限制清單。