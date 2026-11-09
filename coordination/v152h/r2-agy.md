### 1. 修訂稿錯誤與易做錯處（對照程式確認）

1. **`_draw_bookmark` 畫序與入口位置錯誤**（[r1-plan.md:12](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r1-plan.md#L12) 對照 [lobby_view.gd:487-491, 507-508, 513-528](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L487)）：
   - **畫序**：`_draw_lobby` 結尾（507～508 行）有 `if lobby_menu: _draw_lobby_menu(...)`。若在結尾繪製，書籤會**反向蓋住「我的預設」下拉彈窗**。
   - **層級與位置**：A 案書籤 y 座標為 96～126，完全在分頁按鈕內（[lobby_view.gd:517](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L517) y 96～164），根本不接觸下方的羊皮紙頁（y 168 起），修訂稿寫「且畫在紙頁之上」純屬對舊幾何的誤解。若在 491 行之後畫，反而會蓋過 487 行已畫好的分頁文字與金框，被迫「補畫一次金框」。正確做法應直接內嵌在 [`_draw_lobby_presets`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L510-L528) 依序繪製：分頁木框底 → 書籤 → 金框與文字。

2. **`_h1` 改 float 與呼叫端「一律改寫」不相容**（[r1-plan.md:10](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r1-plan.md#L10) 對照 [ui_base.gd:884-887](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L884)、[game_menus.gd:1246](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1246)、[lobby_view.gd:486](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L486)）：
   - GDScript 忽略非 void 回傳值完全合法，既有 31 處不改動可向下相容。
   - 但修訂稿寫「呼叫端一律 `var y := _h1(...) + GAP_L`」會引發兩大錯誤：(1) [game_menus.gd:1246](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1246)（首次啟動）等處已有 `var y := ...`，重複宣告會直接報編譯錯誤；(2) [lobby_view.gd:486](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L486) 等畫面下游元素座標寫死（如分頁 y=96），盲目套用會引發骨牌式跑版、壓出畫面。回傳值僅能選擇性用於 L3 清單，不可「一律改寫」。

3. **`--shot-data` 缺少存檔前綴隔離，存在污染真存檔風險**（[r1-plan.md:25](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r1-plan.md#L25) 對照 [game_screens.gd:14-19](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L14) 與 [dev_main.gd:1](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/dev_main.gd#L1)）：
   - 存檔前綴隔離在 `game_screens.gd:15`（比對 `--shot=`、`--perf=` 等）。若接手者除錯時單獨帶 `--shot-data`，`Save.prefix` 仍為空字串，注入假資料後若觸發存檔，**會直接覆寫並破壞使用者真實存檔 `user://save.json`**！
   - **指紋部分**：[`run_case`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/golden.gd#L27-L40) 純讀獨立資料檔案，**不會污染戰鬥指紋**；但真實存檔被污染會導致後續 `STATEFUL` 單元測試失敗。必須在 [game_screens.gd:15](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L15) 同步加入 `--shot-data=` 設定 `Save.prefix = "shot_"`。

4. **L1 目標座標未標明模態覆蓋層屬性**（[HANDOFF-v152.md:25](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/HANDOFF-v152.md#L25) 對照 [game_menus.gd:1184-1196](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1184)）：
   - 卡片面板在 [game_menus.gd:1195](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1195) 為 `Rect2(430, ..., 800, ...)`，且自帶全螢幕暗色遮罩（1184 行）。修訂稿改 `x=(1280-800)/2=240`，交接文件若未註明其為「全螢幕模態遮罩覆蓋層」，接手者會誤認其與主畫面左欄（x: 70～440）處於同層並列而不敢改置中。

5. **`layout_check.sh` 警告與例外清單未定義退出碼**（[r1-plan.md:24](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r1-plan.md#L24) 對照 [layout_check.sh:46, 65](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/layout_check.sh#L46)）：
   - 目前腳本結尾以 `sys.exit(1 if total else 0)` 僅判違規數。修訂稿要求列出警告明細與例外清單，卻未定義「未豁免的警告是否 exit 1」。若不退 1 則警告形同虛設；若退 1 則既有的大量警告（R5、R6）將讓 CI 在 M0 全面卡死。

---

### 2. 兩項定案審查與一句理由

- **「未選分頁預設不畫書籤」**：**同意**。未選分頁繪製褐色小耳會與 A 案置頂紅書籤產生視覺雜訊並干擾文字槽，預設不畫最乾淨，且可在 M0a 截圖由使用者最後裁決。
- **「確認框不捲動只截斷」**：**同意**。確認框為短暫模態對話框，手把（gamepad）焦點在捲動容器內操作極易發生焦點迷航與跳動，限制實高並截斷文字最符合無障礙與主機體驗。

---

### 3. 交接文件結構缺漏（30 分鐘內開工）

1. **開工單行命令流水線（One-liner Bootstrap）**：缺少一條串接「行程檢查 + load_all + check --quick」的直接可複製指令，接手者無需在各章節間翻找路徑與環境變數。
2. **L1～L11 程式錨點速查表（Anchor Map）**：缺少「代碼 : 檔案路徑 : 繪製函式名與目標行號」的直查索引，省去接手者前 20 分鐘逐一 grep 的摸索成本。
3. **M0a 基準產出物路徑與中線拼接規格**：要求輸出 19 組基準圖與接觸表，但未明定目錄結構與接觸表拼接腳本/指令，接手者易卡在產出準備。

---

有條件
