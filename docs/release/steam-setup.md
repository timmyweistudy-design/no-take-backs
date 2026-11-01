# Steam 上架與整合步驟（優化方案 N、N6～N9）

> 遊戲端已經準備好：`scripts/game/steam.gd` 封裝了成就與雲端。沒有 Steam 時只記在本機；接上 Steam 後，離線解鎖的成就會自動補送。
> 標 **【你】** 的要你的帳號、付款或授權；其餘 Claude 可以做。

## A. 帳號與 App（**【你】**）
1. 註冊 Steamworks：https://partner.steamgames.com/。要填稅務資料（台灣個人或公司）和銀行帳戶。
2. 付 Steam Direct 上架費 US$100。營收達 US$1,000 後回收；之後要等 30 天才能發售。
3. 建立 App，取得 **AppID**。把 AppID 告訴 Claude（寫進 `steam_appid.txt`，只在開發時用）。

## B. 遊戲端整合（Claude）
1. 安裝 GodotSteam GDExtension，版本要對應 Godot 4.6：https://github.com/GodotSteam/GodotSteam。放進 `game/addons/godotsteam/`。
2. `steam.gd` 已經寫好：`Engine.has_singleton("Steam")` → `steamInitEx` → 解鎖時呼叫 `setAchievement` 與 `storeStats`。初始化時會補送本機的成就。
3. **成就**：在 Steamworks 後台建立以下 15 個，API 名稱要一模一樣（**【你】**在後台建立，或給 Claude 後台權限）：

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
| PUZZLE_ALL | 殘局全破 | Puzzle Master | 10 關殘局都過關 |
| PUZZLE_3STAR | 完美解 | Perfect Solution | 任一關三星 |
| GAUNTLET | 七連勝 | Seven Straight | 遠征通關 |
| FRENZY_WIN | 狂熱中取勝 | Won in the Frenzy | 打到 60 秒後獲勝 |
| ALL_TYPES | 五兵齊出 | Combined Arms | 用五種兵獲勝 |
| CHARGE_5 | 鐵騎突擊 | Cavalry Storm | 一場 5 次以上衝鋒並獲勝 |
| BACKSTAB_3 | 暗影三連 | Shadow Trio | 一場 3 次以上背刺並獲勝 |

4. **雲端**：後台 Steam Cloud → Auto-Cloud。
   - 路徑：Windows `%APPDATA%/Godot/app_userdata/落子無悔 No Take-Backs/`，檔案 `save.json`（加上 `save.json.bak`）。
   - **不要**同步 `settings.json`：設定留在本機，各台電腦的畫面設定不同（〔X〕）。
5. **Remote Play Together**：本機多人遊戲官方會自動支援。商店頁勾選「Shared/Split Screen PvP」與「Remote Play Together」。要實測輪流操作（**【你】**找一位有 Steam 的朋友）。
6. **Steam Input／手把**：遊戲已支援手把，用 Godot 的 Joypad。Deck 驗收要求圖示對應輸入裝置；目前提示文字寫「A／B／X」，接 Steam Input 後改成依裝置顯示。

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
