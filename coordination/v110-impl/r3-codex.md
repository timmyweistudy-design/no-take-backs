已核對 HEAD＝`2d35b51`。全程只讀；僅做 Python AST 語法解析，未執行遊戲或會寫檔的測試。

1. **部分修好，必改**：版本、小數與解碼軍令驗證已補；`solution_code.gd:59` 的 `plan_legal` 有核對技能次數、時間與冷卻。但 [save.gd:461](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:461) 仍只驗通用範圍，未按關卡驗軍令及部署。非法軍令、重疊部署搭配 `[3,100,0]` 仍可留存，讓 `solution_code.gd:81` 擋住後續合法最佳解；「套用時略過放不下的兵」無法解決排名卡住。應在載入時依關卡驗證，丟棄非法紀錄。

2. **已修**：`game_menus.gd:437` 已將 `ap==1` 納入實際繪製協力徽記的條件。

3. **已修**：`game_result.gd:86` 練習分支只呼叫 `_daily_finish`，保留勝利提示；`game_v16.gd:123、128、132` 分別排除 AI 戰績、有效場數與生涯累積，未見此修法新增結算問題。

4. **部分修好，必改**：[replay_view.gd:868](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd:868) 已用 `.part`，取消及改名失敗也會清理；但 `store_buffer` 後未檢查寫入錯誤。磁碟滿時仍可能將不完整暫存檔改成正式 GIF 並回報成功。應確認寫入成功才提交，失敗則清理。

5. **已修**：`game_v16.gd:34` 流水號已取消上限，不再於第 101 份覆寫。

6. **已修原列問題**：`check.py:166、188` 的結尾「.」避開步驟名稱前綴碰撞；匯入中斷已有清理。`_run_all/_run_steps/_finish` 靜態未見漏傳變數，工作例外會先清程序再關池；跨系統中斷行為未實跑驗證。

結論：有條件