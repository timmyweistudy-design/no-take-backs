# Steam 上架與整合步驟（優化方案 N、N6～N9）

> 遊戲端已經準備好：`scripts/game/steam.gd` 封裝了成就與雲端。沒有 Steam 時只記在本機；接上 Steam 後，離線解鎖的成就會自動補送。
> 標 **【你】** 的要你的帳號、付款或授權；其餘 Claude 可以做。

## A. 帳號與 App（**【你】**）
1. 註冊 Steamworks：https://partner.steamgames.com/。要填稅務資料（台灣個人或公司）和銀行帳戶。
2. 付 Steam Direct 上架費 US$100。營收達 US$1,000 後回收；之後要等 30 天才能發售。
3. 建立 App，取得 **AppID**。把 AppID 告訴 Claude（寫進 `steam_appid.txt`，只在開發時用）。

## B. 遊戲端整合（Claude）——**11/01 已完成**
1. ✔ 已安裝 GodotSteam GDExtension 4.23.2（https://codeberg.org/godotsteam/godotsteam）到 `game/addons/godotsteam/`。
   - 只放 Windows 64 與 Linux 64，約 18 MB。
   - 匯出的 Windows build 會自動帶上 `steam_api64.dll` 與 GodotSteam 的 DLL，已實跑 0 錯誤。
   - 沒有 Steam 時自動退回「只記在本機」。
   - **Spacewar（AppID 480）實測還沒跑**：會讓你的 Steam 狀態顯示「正在玩 Spacewar」，自動權限擋下。你想測的話，在 Claude Code 輸入：
     ```
     ! "/mnt/c/Users/timmy/OneDrive/桌面/godot/Godot_v4.6.2-stable_win64.exe" --path "C:\Users\timmy\projects\no-take-backs\game" --resolution 640x400 -- --steam-test=480
     ```
     它只做讀取檢查：有沒有登入、AppID 是否相符、讀得到一個 Spacewar 成就、確認我們的成就 ID 在 480 不存在。
     - **不會解鎖成就、不寫統計、不讀寫你的遊戲存檔**（會改用 `shot_` 前綴的存檔）。
     - Godot 本身仍會照常寫執行日誌。
     - 全部符合就 `exit 0`，任何一項不符就 `exit 1`。
     - 輸出是一行 `STEAMTEST {...}`。拿到你自己的 AppID 後，把 480 換掉再跑一次：正式 App 會逐一核對這 24 個成就都建好了（少一個就 exit 1，會列出缺哪些）。
     - 另外建議在**沒開 Steam** 時跑一次，確認會回報失敗（`exit 1`）。
2. `steam.gd` 已經寫好：`Engine.has_singleton("Steam")` → `steamInitEx` → 解鎖時呼叫 `setAchievement` 與 `storeStats`。初始化時會補送本機的成就。
3. **成就**：在 Steamworks 後台建立以下 31 個（V1.5 新增 7 個，在表格最後），API 名稱要一模一樣（**【你】**在後台建立，或給 Claude 後台權限）：

| API 名稱 | 中文 | English | 條件 |
|---|---|---|---|
| FIRST_WIN | 初陣告捷 | First Victory | 第一次獲勝 |
| LONE_HERO | 孤勇者 | Lone Hero | 最後一隻撐到勝利 |
| COMEBACK | 絕地翻盤 | Comeback | 曾落後 ≥15% 後獲勝 |
| CLOSE_CALL | 一線之隔 | By a Hair | 勝方剩 ≤5% 戰力 |
| NO_TAKEBACKS | 落子無悔 | No Take-Backs | 打完一場輪流落子三戰兩勝 |
| HARD_WIN | 勝過困難 AI | Beat Hard AI | 打贏困難 AI |
| SWEEP | 二比零 | Clean Sweep | 三戰兩勝以 2:0 拿下 |
| TUTORIAL | 學會了 | Graduated | 完成 3 關教學 |
| PUZZLE_ALL | 殘局全破 | Puzzle Master | 第 1 章 10 關殘局都過關 |
| PUZZLE_3STAR | 完美解 | Perfect Solution | 任一關三星 |
| GAUNTLET | 七連勝 | Seven Straight | 遠征通關 |
| FRENZY_WIN | 狂熱中取勝 | Won in the Frenzy | 打到 60 秒後獲勝 |
| ALL_TYPES | 五兵齊出 | Combined Arms | 用五種兵獲勝 |
| CHARGE_5 | 鐵騎突擊 | Cavalry Storm | 一場 5 次以上衝鋒並獲勝 |
| BACKSTAB_3 | 暗影三連 | Shadow Trio | 一場 3 次以上背刺並獲勝 |
| CUSTOM_LOWGOLD | 精打細算 | Shoestring Army | 自訂規則：低金幣獲勝 |
| CUSTOM_UNDERDOG | 以寡擊眾 | Underdog | 自訂規則：讓子時以少勝多 |
| CUSTOM_BIG | 大軍壓境 | Grand Army | 自訂規則：大軍團獲勝 |
| FANTASY_WIN | 傭兵公會開張 | Monster Mercenaries | 只用奇幻軍獲勝 |
| BOOM_5 | 羊到爆炸 | Sheep Go Boom | 一場 5 次以上羊爆並獲勝 |
| RAISE_3 | 大家起來 | Rise and Shine | 一場復活 3 隻以上並獲勝 |
| PUZZLE_100 | 百局通關 | Hundred Puzzles | 100 關殘局全部過關（第十三輪） |
| PUZZLE_ALL3 | 百局三星 | Hundred Perfect | 100 關殘局全部三星 |
| TRIAL_ALL3 | 試煉滿星 | Trial Perfectionist | 30 關主題試煉全部三星 |
| GHOST_ALL | 名將皆敗 | Ghostbuster | 打敗全部幽靈名將的陣型（V1.5） |
| WEEKLY_WIN | 本週破盒 | Box Breaker | 打贏一次每週棋盒（V1.5） |
| WAVE_3 | 車輪不倒 | Last One Standing | 車輪戰連贏三波（V1.5） |
| REVENGE | 雪恥 | Sweet Revenge | 在遠征裡打敗宿敵（V1.5） |
| PAINTER | 自己的顏色 | True Colors | 在塗裝室換一次顏色（V1.5） |
| SHARP_EYE | 好眼力 | Sharp Eye | 競猜連續押中 5 場（V1.5） |
| SEALED_DONE | 封蠟三戰 | Sealed Fate | 打完一組雙封蠟三戰（V1.5） |

4. **雲端**：後台 Steam Cloud → Auto-Cloud。
   - 路徑：Windows `%APPDATA%/Godot/app_userdata/落子無悔 No Take-Backs/`，檔案 `save.json`（加上 `save.json.bak`）。
   - **不要**同步 `settings.json`：設定留在本機，各台電腦的畫面設定不同（〔X〕）。
5. **Remote Play Together**：本機多人遊戲官方會自動支援。商店頁勾選「Shared/Split Screen PvP」與「Remote Play Together」。要實測輪流操作（**【你】**找一位有 Steam 的朋友）。
6. **Steam Input／手把**：遊戲已支援手把，用 Godot 的 Joypad。Deck 驗收要求圖示對應輸入裝置；目前提示文字寫「A／B／X」，接 Steam Input 後改成依裝置顯示。

## B2. V1.6.0 要你在後台做的事（**【你】**，Claude 不能代做）
1. **成就 31 個**：照上面 B-3 的表在後台建立（還沒有正式 AppID，所以一個都還沒建）。建好後跑一次 `--steam-test=<你的 AppID>`，它會逐一核對、缺哪個會列出來。
2. **排行榜**：遊戲用 `findOrCreateLeaderboard` 自動建，不用手動建；但後台要允許「由遊戲建立排行榜」。名稱與規則：
   - `weekly_<週數>`：每週棋盒，分數＝花費（**越小越前面**），附加資料＝格子陣（版本 1）。
   - `daily_<UTC 日數>_v<Daily.VER>`（V1.6.1 起帶題目版本，目前 v1）：V1.6 每日挑戰，分數＝剩餘%×1000＋(999−花費)（**越大越前面**），附加資料＝自由座標陣（版本 2，紅方視角）。
   - 附加資料最多 64 個 int（`set_leaderboard_details_max(64)`）。
3. **商店頁網址**：拿到 AppID 後把 `game/scripts/game/steam.gd` 的 `STORE_URL` 填成 `https://store.steampowered.com/app/<AppID>/`。試玩版結尾畫面（V1.6 #1）與結果頁的「加入願望單」才會從「上架後開放」變成可按。
4. **雲端存檔**：Auto-Cloud 規則照 B 節（`save.json`）；V1.6 新增的存檔欄位（`funnel`、`seen`、`mastery`、`notebook`、`daily_streak`、`daily_pend`、`rush_best`、`rift_best`）都在同一個 `save.json` 裡，不用改規則。
5. 以上做完後，請 Claude 用 `--steam-test` 驗一次（不解鎖、不寫存檔）。

## C. 打包與上傳
1. Claude：`godot --headless --path game --export-release "Windows Desktop" ../build/windows/NoTakeBacks.exe`。Linux 同理，匯出設定已寫在 `game/export_presets.cfg`。
2. **【你】**：安裝 SteamCMD，用 `app_build.vdf` 上傳。範本：

```
"AppBuild" { "AppID" "<你的 AppID>" "Desc" "No Take-Backs build" "ContentRoot" "../build/" "BuildOutput" "../build/output/"
  "Depots" { "<DepotID>" { "FileMapping" { "LocalPath" "windows/*" "DepotPath" "." "recursive" "1" } } } }
```

3. 設定啟動選項：`NoTakeBacks.exe`。**不要加 Steam DRM 包裝**（〔X〕：保持乾淨，日後若用到 CC-BY-SA 素材也比較單純）。

## D. Steam Deck 自我檢查（提交驗證前）
- [ ] 1280×800 下所有字 ≥9px（目標中文 16px）。可以用設定裡的「文字大小 125%」
- [ ] 純手把能從標題玩完一場（方向鍵或搖桿移動、A 擺放、X 移除、Start 開戰、B 返回）
- [ ] 休眠後恢復，音樂與狀態正常
- [ ] 圖示對應輸入裝置（接 Steam Input 後）
- [ ] 不需要鍵盤輸入文字（陣型代碼用剪貼簿，Deck 上要用 Steam 的鍵盤，或不提供這個功能）

## E. 發售前檢查
- [ ] `check_assets.py` 全過、製作名單齊全
- [ ] 測試全過、Windows／Linux 指紋一致、100 組鏡像一致
- [ ] 平衡報表紅線全過
- [ ] 真人試玩兩輪的數據達標（`docs/playtest/protocol.md`）
- [ ] 商店頁審核通過、build 審核通過
- [ ] **【你】**決定發售日與價格
