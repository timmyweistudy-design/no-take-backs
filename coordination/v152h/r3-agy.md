### 1. 易做錯與卡住處（對照程式，共 4 條）

1. **分頁 150% 文字槽缺少明確幾何算式**（[lobby_view.gd:522](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L522) 對照 [r2-plan.md:3](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r2-plan.md#L3)）：
   - **專項檢查**：書籤進 [`_draw_lobby_presets`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L510-L531) 後，**簡化介面**（脫離材質分支）與 **`lb_mine`**（在迴圈外 :529-530，原就無書籤）邏輯皆正確；**手把焦點框**先畫雖被書籤覆蓋內緣，但緊隨的選中金框（:521）會補蓋，視覺完整。
   - **卡點**：文字現為 `w/2 = 77` 置中、限寬 `w - 12 = 142`。A 案書籤占用右側 34px，150% 字級（`tz("B")`=24）或英文時右側必撞書籤。修訂稿應給出明確公式：6 格文字一律改以 `(w - 34)/2 ≈ 60` 置中且限寬 `w - 38`，避免切換分頁時文字左右跳動。

2. **備份隔離的 6 處硬編碼與 static 限制**（[game_menus.gd:853-874, 886, 891](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L853) 對照 [r2-plan.md:5](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r2-plan.md#L5)）：
   - **升級相容檢查**：玩家正式遊戲時 `Save.prefix == ""`，目錄仍為 `user://backup`，**既有存檔讀取 100% 相容無損**。
   - **卡點**：[`backup_list`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L853) 是 `static func`，不可呼叫實體方法；且全檔有 6 處寫死 `"user://backup"`（:855, :866, :871, :874, :886, :891）。須明定宣告 `static func _backup_dir() -> String: return "user://%sbackup" % Save.prefix` 並統一替換，避免接手者編譯報錯或漏改 :891 還原讀取。

3. **`_ask_confirm` 破壞既有呼叫契約**（[game_menus.gd:835-846, 950](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L835) 對照 [r2-plan.md:7](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r2-plan.md#L7)）：
   - **卡點**：既有呼叫（如 :950 還原確認）傳入純字串。若強制改為 Dictionary 參數，呼叫端會直接型別報錯。首個參數須宣告為 `Variant`，傳入 `String` 時自動轉為 `{head: msg, items: []}`，維持向下相容。

4. **`layout_check.sh` 靜態畫面名提取陷阱**（[layout_check.sh:38-51, 63-64](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/layout_check.sh#L38) 對照 [dev_main.gd:808-814](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/dev_main.gd#L808)、[r2-plan.md:6](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152h/r2-plan.md#L6)）：
   - **卡點**：檢查器以 `grep -o '_snap("[^"]*")'` 靜態提取截圖集合。若案例截圖名（如 `59b_nemeses@full.png`）在 `dev_main.gd` 採字串拼接，grep 會漏抓，引發集合比對失敗（:51, :64 退出 1）。須明文要求接手者寫死字面常數字串。

---

### 2. 新交接結構評估（0～8 章）
- **多餘獨立章**：§8「需要使用者的事」僅有開工口令與另案外部驗收兩行，內容過於單薄。應將「開工前置」併入 §1、「驗收邊界」併入 §7。
- **建議合併**：§3「鐵則／不要做」與 §4「已知坑」皆為開工前的防禦知識，建議合併為「§3 鐵則與已知坑（防禦清單）」，結構精簡為 0～6 章更為緊湊實用。

同意定稿
