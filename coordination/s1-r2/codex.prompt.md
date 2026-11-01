# 程式輪 S1＋S2 第 2 輪＋S3 第 1 輪（Codex 唯讀）

請看 `git diff 2de344b HEAD -- game/ .github/`。

**你上一輪（coordination/s1-r1/codex.out.md）的 8 點**：
1. CI 改用 `bash game/tools/check_all.sh`，git 模式設 100755。
2. 滑鼠按鍵（mb）、塗兵（paint）也進佇列，ui_base._process_cmds 依序處理；換畫面時放開仍清狀態。測試 #9（先按 2 再點格子＝盾兵）、#10（開圖鑑後塗兵丟掉）。
3. _layout_texts 移到 _process_inner 結尾（戰鬥更新後）；測試加「每個要畫的跳字都有 rr」。
4. _text_rect 含 pop 放大，畫字直接用同一份位置。
5. 硬上限：關鍵跳字超過上限時併進最近同種；關鍵特效滿額時取代最舊的。
6. 搖桿：stick 狀態＋_stick_repeat（遲滯 0.6/0.35、首次 0.35 秒、之後每 0.12 秒）；測試 #11。
7. check_all：匯入 exit code、素材匯入錯誤、打轉完成標記、mirror／golden／orbit 的腳本錯誤。
8. 星等移到 _build_report。

**S3（0515611）**：
- codex_view：_scroll_draw 自繪捲動（逐行裁切＋捲軸）、_cx_bars、滾輪／右搖桿／PageUp/Down。
- game_screens：_arc_clipped、_draw_counter_strip、拖曳時敵軍腳下圈、AI 性格、_lock_icon＋圖例、_mini_formation、總星數、_draw_timeline（power_log＋battle_marks＋leads）、_draw_pad_footer。
- tools/layout_check.sh＋main._layout_report（--layout-check）：90 張截圖 0 違規。

請找：正確性 bug、上一輪 8 點是否真的修好、S3 的新問題。例如：
- 捲動區的內容高度用上一幀的值
- 時間軸在很短或平手的戰鬥
- 迷你縮圖的欄位換算
- 剋制提示條超出畫面
- layout 檢查的假綠

繁體中文、≤1,200 字，每點附檔名:行號與建議修法，最後一句給「可否繼續」。
