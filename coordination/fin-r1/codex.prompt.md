# 收尾批（Codex 唯讀，新批次第 1 輪）

上一個里程碑（N1～N7）你審了三輪；第 3 輪之後 Claude 又修了幾項，當時標「未經複查」。這一批把那些修正和新的 N6／N8 工作一起送審：`git diff 53f43fc dcf9593 -- game/`（不用看 docs、二進位檔、addons/godotsteam 的 dll／so）。

內容：
1. 第 3 輪 #6：balance_report.py 加了模式白名單＋分片檔集合完整性。Claude 用故意改壞的資料驗過：缺一片 exit 2、亂寫模式 exit 2、正常 exit 0。
2. 手感輪抓到的錯位：art.gd 的 `draw_set_transform` 會蓋掉鏡頭，改成 `Art.base * local`；main.gd 在世界繪製前後設定／重設 `Art.base`。
3. unit_defs.gd 的 data_digest：StringName 排序是比位址，改成轉 String 再排。三種入口腳本都算出 da00a18644009f14。
4. main.gd：
   - 純畫面錯開 ±4px（`_upos`，只影響畫面）。
   - 判詞與單兵 MVP 口徑。
   - 截圖／影片／膠囊模式不初始化 Steam。
   - 膠囊圖模式 `_draw_capsule`。
   - 影片模式 `_run_video`（還沒實際錄過）。
5. steam.gd：
   - `init(app_id)`。
   - 唯讀 `self_test`：只用 getAchievement 讀、不 set。
   - 離線成就補送。
   - main.gd 的常數改名 SteamApi（GodotSteam 會註冊原生類別 Steam）。

Claude 已驗證：
- 測試 51/51（Linux＝Windows 指紋 e37abdf43baa6880）。
- 完整狀態鏡像 100/100。
- 平衡紅線全過。
- 13 關驗證全過。
- 匯出的 Windows build（含 steam_api64.dll）實跑 9 畫面 0 錯誤。
- **Spacewar 480 實測被權限擋下**（會改變使用者 Steam 狀態顯示），沒跑。

請用繁體中文、≤1,200 字，附檔案:行號、標嚴重／中／低：
1. 上面 1～3 的修正是否正確、完整？
2. 新程式有沒有錯誤（特別是 Steam 在沒有 Steam 或 init 失敗時是否安全退回本機、`self_test` 是否真的不會寫入）？
3. 有沒有測試假綠燈或確定性風險？
最後一句：這批可否結案（可／有條件可／不可）。不要改任何檔案。
