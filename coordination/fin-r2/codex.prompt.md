# 收尾批第 2 輪（Codex 唯讀，針對性複查）

你在第 1 輪（coordination/fin-r1/codex.out.md）結論「不可」，列了 5 項。Claude 已修並 commit 60abaf7（上一版 dcf9593）：`git diff dcf9593 60abaf7 -- game/`。

修正內容：
1. steamInitEx 參數順序：Claude 用 ClassDB 查了本機 GodotSteam 4.23.2 的實際簽章，是 `steamInitEx(app_id:int=0, embed_callbacks:bool=false)`，改成 `steamInitEx(app_id)`。
2. 自我檢查真正唯讀：
   - `init(app_id, sync_local=false)` 不補送、不 storeStats。
   - 移除 inputInit。
   - `--steam-test` 模式改用 `shot_` 存檔前綴，不讀玩家存檔。
3. 自我檢查會判定：`ok`＝登入、AppID 相符、已知成就讀得到、我們的 ID 讀不到；不 ok 就 exit 1。
4. 報表：任何一筆缺 digest 就 exit 2（Claude 用故意刪掉 digest 的資料驗過 exit 2；正常 exit 0）。
5. 膠囊 save_png 失敗會 printerr＋exit 1。

注意：Spacewar 實測與「沒有 Steam 時 exit 1」的實測都被自動權限擋下，沒有實際跑過。

請用繁體中文、≤700 字、附檔案:行號：
1. 逐項核對 5 項：已解決／未解決。
2. 修正有沒有新錯誤，尤其要查：
   - `known.get("ret")` 是否符合 GodotSteam 4.23.2 `getAchievement` 的回傳格式。
   - `--steam-test` 路徑會不會在任何情況寫入。
最後一句：這批可否結案（可／有條件可／不可）。不要改任何檔案。
