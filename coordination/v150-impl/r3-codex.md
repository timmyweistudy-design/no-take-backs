只讀審查，未執行會寫檔的測試。第二輪主要修正均已落實：還原驗證、寫入結果檢查、流水號、幽靈成就、清除欄位、塗裝重套、醫者投射物、暫停離開、設定返回、下拉遮擋、競猜連中及提示延遲關閉都有對應程式。

`Art.back` **未見正常流程殘留至戰場或圖集**：圖鑑同步繪製結束會清回 `false`（[codex_view.gd:601](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:601)），轉身及走路轉身圖集也明確清除；但圖鑑切換兵種仍有角度漏洞，見建議。

**必修**

1. **還原／清除後，舊對局仍能改寫新進度。** [game_menus.gd:757](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:757)、[game_menus.gd:807](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:807)：從戰鬥暫停進設定執行還原或全部清除，只替換 `Save.data`，沒有結束目前對局。繼續後，舊局結算會寫入新進度；遠征前往下一站還會以舊局狀態覆蓋剛還原的 `gauntlet_run`（[game_core.gd:771](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_core.gd:771)）。資料交換應結束舊流程，或限制在標題執行。

2. **唯讀存檔清除仍假報成功。** [game_menus.gd:803](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:803)、[save.gd:422](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:422)：載入未來版本存檔後執行清除，沒有檢查 `data_locked`；`save_data()` 略過寫入卻回傳 `true`，因此顯示清除完成，重啟資料又回來。自動備份存的也是替代用的新進度，並非受保護原檔。清除應比照還原直接拒絕。

3. **流水號排序會刪掉最新備份。** [game_menus.gd:712](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:712)、[game_menus.gd:736](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:736)：同秒連續建立第 11 份備份時，字串倒序把 `_10`、`_11` 排在 `_2` 後面；保留十份會把剛寫好的 `_11` 刪掉，卻回報備份成功。應採數值排序或固定寬度流水號。

**建議**

1. **換兵種重設角度，手動背面判定也加 `BACK_OK`。** [codex_view.gd:60](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:60) 保留 `cx_angle`；在人形轉到第 12 格後切換騎兵／奇幻兵，[第 572 行](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:572) 仍設 `Art.back = true`，讓不支援背面的兵缺五官。這是圖鑑局部畫面錯誤，沒有戰場污染證據。

2. **§8「設定完成」應縮小宣稱。** [方案:244](/mnt/c/Users/timmy/projects/no-take-backs/docs/2026-11-09-v1.5.0-plan.md:244) 除既列延後項目，還漏列：進階收合、即時預覽、每頁恢復預設、修改標記、預設套用前差異預覽、戰鬥設定生效標示。`_apply_preset()` 是直接套用，並未先預覽；STATE 也應補列。

3. **驗收狀態要獨立列出。** [方案:253](/mnt/c/Users/timmy/projects/no-take-backs/docs/2026-11-09-v1.5.0-plan.md:253) 寫「指紋見收尾驗收」，但 [STATE:183](/mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md:183) 最新紀錄仍是 V1.4；本版效能重測、四語三字級與輸入方式驗收也未交代。不能把程式完成等同驗收完成。

4. **十份備份應都能在介面選取。** [game_menus.gd:779](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:779) 只顯示六份且無捲動，其餘四份需要玩家自行管理檔案；應補操作方式或列為限制。

**結論：同意九種人形背面追加及已明列的「部分／延後」取捨，不必補齊才發布，但目前應先修上述三項資料流程問題再收尾。**