# 程式輪 S5～S8 第 2 輪（Codex 唯讀）

請看 `git diff 53a5194 HEAD -- game/`。

**你上一輪（coordination/s67-r1/codex.out.md）的五點**：
1. 三軌循環改在 .import 設 edit/loop_mode=2，runtime 不再自己算；測試檢查 loop_end/mix_rate ≈ 長度。
2. battle_view.clutch_cond 共用；_check_clutch 移到 _sim_step 每個畫面 tick 判定；_seek 快轉時用 clutch_cond(sim) 重算觸發 tick。測試 test_seek_clutch：觸發後→觸發前→觸發後（改壞會紅）。
3. balance_report 逐列核對 mode／rule／level（已用「訓練池改名成驗證池」驗證會被擋）。
4. 驗證池零決勝不能過；加秒數、平手、時間到紅線。
5. turns 摘要鍵依等級分開。

**S8（0f8d2bc）**：
- 輸入佇列執行端移到 game_screens；_begin_battle 移到 battle_view；宣傳模式分派移到 main（_ready 覆寫）；_mode_label 移到 ui_base；on_battle_finished 回呼。ui_base 的空函式全部拿掉。
- main --mem-check。

請確認五點修好沒有，並找 S8 搬家造成的問題，例如：
- main._ready 與 game_screens._ready 的順序
- 膠囊模式的 _draw_inner
- on_battle_finished 在測試裡沒設定
- _check_clutch 改成每 tick 呼叫後頓格／慢動作的時序

繁體中文、≤900 字，最後一句給「可否收尾」。
