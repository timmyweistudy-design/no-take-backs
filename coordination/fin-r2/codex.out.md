唯讀核對完成，未修改檔案。

1. **已解決**：初始化以 AppID 為第一參數，符合介面。[steam.gd:34](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd:34)
2. **已解決（存檔／成就範圍）**：測試傳入 `false`，跳過補送與 `storeStats`，已移除 `inputInit`；先設 `shot_`，測完立即返回。[main.gd:111](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/main.gd:111)；載入與遷移僅讀檔、修改記憶體。[save.gd:20](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:20)
3. **已解決**：四項條件共同決定 `ok`，失敗 exit 1。[steam.gd:78](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd:78)、[main.gd:120](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/main.gd:120)。反組譯隨附 Linux 4.23.2，確認回傳鍵為 `ret`、`achieved`；`ret` 表示讀取成功，判法正確，與[官方原始碼](https://raw.githubusercontent.com/GodotSteam/GodotSteam/9a3480ff1bdbc5064f5a53dda8341b5263ea5c09/godotsteam.cpp)一致。
4. **已解決**：記憶體驗證正常 exit 0；單筆缺少、全部缺少、空摘要皆 exit 2。[balance_report.py:85](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/balance_report.py:85)
5. **已解決**：PNG 失敗會印錯並 exit 1。[main.gd:1056](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/main.gd:1056)

未見新增確定錯誤。但「任何情況零寫入」不成立：[Godot 桌面預設會寫日誌](https://docs.godotengine.org/en/latest/tutorials/scripting/logging.html)，`shot_` 不隔離日誌。結案條件：唯讀口徑限存檔／成就，並補驗 Spacewar 成功及無 Steam exit 1；兩者目前仍未實跑。

這批可否結案：有條件可。