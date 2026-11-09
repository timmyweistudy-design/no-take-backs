共 12 條，依嚴重度排序。列號從附圖最上方算第 1 列。全程只讀；審查期間工作區另有變動，以下行號以最後讀取版本為準。

1. **[高／資料保護] 自動備份失敗仍繼續還原、清除。**  
   [game_menus.gd:657](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:657)：備份開檔失敗只提示並返回，呼叫端第 681、722 行仍繼續覆寫；也未檢查備份寫入及 `save_data()` 結果。磁碟滿、權限錯誤時，可能沒有可復原副本，最後卻顯示成功。違反方案 §4「還原失敗保護」。

2. **[高／資料相容] 還原未驗證存檔身分與版本。**  
   [game_menus.gd:677](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:677)：任何 Dictionary 都接受；備份內容若是 `{}`，會補成新進度並覆寫現況。未來版備份也未套用 `load_all()` 的版本鎖定，會經清洗後存回，破壞既有未來版本保護。

3. **[高／演出 bug] 投彈兵貼身敲擊會憑空丟炸彈。**  
   [battle_view.gd:219](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:219)：`BONK` 也是帶傷害的 attack，因投彈兵 `proj_fly > 0` 而被登記為飛行物。長緩衝局貼身敲人時，會提早演出動作並生成炸彈，命中卻走敲擊效果。應依事件種類分配飛行預算。

4. **[高／時間同步] 手動軍令局仍先受傷、後中箭。**  
   [battle_view.gd:567](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:567)：短緩衝分支在命中事件到達後，才建立 `fly = 0.28` 的箭；此時 HP、閃白已發生。原問題在此模式完整保留，違反 §3.1 的快速飛行與命中同步要求。

5. **[中／方案違反] 設定匯入、還原沒有預覽／覆蓋確認。**  
   [game_menus.gd:625](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:625) 匯入後立即逐項存檔；第 700 行點備份名稱即還原。誤點或貼錯代碼會直接改掉設定／進度，未做到 §2.2 要求的差異預覽及覆蓋範圍確認。

6. **[中／紙片感，全部列] 「16 方向」沒有背面。**  
   [codex_view.gd:561](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:561)：角度只取 `cos` 的正負與絕對值，`turn_s` 永遠非負；90°、270°得到同一姿勢。附圖前八格實際是正面轉身往返，無法驗收背面遮擋；違反 §3.3「背面不能用鏡像代替」。

7. **[中／轉身 bug] 戰場攻擊途中會突然跳回側面。**  
   [sprite_cache.gd:354](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:354)：轉身尚未完成就攻擊時，直接把 `face` 改成 ±1。雖避免壓扁，仍造成姿勢跳變，且沒有走方案指定的「當幀直接繪製」路徑。

8. **[中／圖鑑控制] 切換慢動作會跳幀。**  
   [codex_view.gd:555](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:555)：進度以「距起始時間 × 目前倍率」計算。攻擊播到一半切 0.25 倍，會倒退到四分之一進度；切回則可能直接播完。需要累積播放游標，才能連續檢視動作。

9. **[中／無障礙方案] 低操作負擔預設未提供承諾的操作。**  
   [game_menus.gd:581](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:581)：只改確認、提示倍率、長按時間等，沒有「點選擺放／切換操作／提示手動關閉」。其中 `toast_mult = 3` 仍會自動消失；預設也直接套用，沒有事前差異預覽。違反 §2.1。

10. **[中／設定契約] 新安裝預設與合法選項偏離定案。**  
    [save.gd:14](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:14)：死區預設 35%、震動及閃白 100%，方案分別要求 20%、25%、柔和。設定頁音量也只有少數離散值，無法按要求以 5% 調整；提示停留實際為 2／4／6 秒，沒有 12 秒及手動關閉。

11. **[低／缺件，第 9 列鼓手] 鼓槌缺少對應握持手與柄尾。**  
    [kingdom.gd:274](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd:274)：只畫兩條槌桿及槌頭，沒有在握點畫手指；通用後手位於另一處。附圖出手時鼓槌像浮在鼓前，未完成 §3.2 的握持與短柄尾要求。

12. **[低／遮擋錯誤，第 5、10 列刺客／狂戰士] 遠側武器仍覆在身體前。**  
    [kingdom.gd:168](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd:168)、[kingdom.gd:289](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd:289)：軀幹先畫，兩把武器後畫；`_part()` 只調位置與縮放，沒有依深度交換畫序。轉身時遠刀／遠斧仍貼在正面，保留紙片疊件感。

未發現核心模擬檔變更或畫面狀態流入模擬；既有檢查紀錄仍為 `FINGERPRINT b8fe741bcbfcf800`，本次未重跑。附圖未能確認手持物被畫布邊界硬裁，故不把縮短或遮擋誤列為裁切。