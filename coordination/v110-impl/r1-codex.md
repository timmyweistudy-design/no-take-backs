只讀審查完成；未改檔、未碰 FINGERPRINT。以下為靜態呼叫路徑判讀，未執行會寫檔的遊戲測試。

必改：

1. **Q1 可繞過雙人落子鎖定** — [game_screens.gd:20](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:20)。雙人輪流落子時長按 X，會直接 `_clear_mine()`，跳過清空鈕既有的 `_can_edit_existing()` 限制，能刪掉已承諾的兵。起按及觸發時都須檢查可編輯資格。

2. **N5 未保存軍令，無法重現最佳解** — [solution_code.gd:10](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/solution_code.gd:10)、game_core.gd:793。時序關卡用非預設軍令過關後分享，碼只有關卡與部署；接收者會用預設或自己先前留下的 `puzzle_plan`。存檔、編碼、驗證及匯入須一起保存軍令與規則識別。

3. **N5 匯入會被算成自力解題** — [game_menus.gd:1294](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:1294)、game_v16.gd:1220、947。貼朋友解碼後過關，`_pick_puzzle()` 清掉協力旗標，結算便可更新自力最佳。匯入後須標記外部協助，並讓同題重打保留此資格。

4. **N4 練習仍流入一般進度** — [game_result.gd:87](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:87)、game_v16.gd:108、111。補打舊題仍跑一般成就、熟練度及有效場數結算；可反覆累積 `eff_games`、觸發成就。應在共用結算入口套用練習資格，明列允許寫入項目，不能只在 `_daily_finish()` 擋每日欄位。

5. **GIF 最後一格取消仍可能寫檔** — [gif.gd:76](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/gif.gd:76)、replay_view.gd:863。最後一格編碼期間退出，之後沒有再讀 `stop`，仍回傳完整資料並開檔。編碼完成及開檔前都須重查取消／期限；用暫存檔提交，取消時刪除。

6. **A13 丟失來源關係** — [game_v16.gd:485](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:485)。四兵以上鎖同一目標時，第四隻起完全不畫；「×N」只能知道總數，無法知道哪些兵鎖它。應保留每個來源到合併束的連接，再共同接到目標，符合方案「保留全部關係」。

7. **N1 同秒回報覆寫** — [game_v16.gd:26](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:26)。同秒送兩次回報會以相同檔名覆蓋，違反方案明訂的不撞檔要求。加入微秒／流水號並檢查存在。

8. **最佳解存檔驗證過鬆** — [save.gd:329](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:329)。例如星數 999、非法座標或空部署仍能留下；異常高星數還會阻止合法新解取代。依關卡驗整數、排名範圍、非空部署與 `check_extra()`；decode 也須驗 `v == 1`。

9. **H2 例外路徑未保證收尾** — [check.py:270](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/check.py:270)。load 失敗提前返回、future 拋例外或中斷時，可跳過 `gate.shutdown()`；boot／Windows 子程序仍可能留著。executor 與 marker 清理須放 `try/finally`；每步使用獨立 marker，避免某步逾時殺掉全輪其他工作。

其餘建議／確認：

- H1：replay_view.gd:583 的離開條件正確；入口確實設為 `review`。世代作廢、`rv_old` 回收及退出 join 路徑成立。另建議替 :362 的同步基準重算加期限，避免開覆盤時卡住。
- H5：ui_base.gd:128 與 free_place.gd:51 共用正反轉換，部署與重播路徑相符；圖鑑用獨立畫框。仍需補小地圖首排、點擊與重播的實際截圖驗收。
- N4：每日最佳、每日連勝、`daily_pend`、分享格已有防線；game_result.gd:20 的重打條件會保留練習旗標。
- B13、E3：未見新增阻斷；`_settings_row_y()` 已同步偏移。A15 色條與裁決一致，但不等於分類瀏覽。
- E2：steam.gd:223、228 應以隨附 GodotSteam 真實回傳字典驗證，現有替身測試不足。A21 退出清回呼路徑成立。
- t_stateful2／3 的前綴及自訂測試檔名未見新增交集。v161_metrics.gd:85、86 偶數樣本取的是上中位數，建議改兩中央值平均。

結論：有條件