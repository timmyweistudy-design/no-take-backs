# 收尾輪第 2 輪（Codex 唯讀）

請看 `git diff 128e7de HEAD -- game/`。你上一輪（coordination/r68-r1/codex.out.md）的五點：
1. save.gd load_all 改 `migrate(_read(_dp(), {}))`，遷移裡才補預設；unit_wins 不是 Dictionary 一律修好；新測試用 prefix 寫 v1 檔走正式 load_all（已證明改回會紅）。
2. 徽章卡：c0cf37b 已加 maxw 84 自動縮字（你審的 diff 在那之前）。
3. 擺放上方列：標題 ≤26px、膠囊 ≤15px、提示列 ≤17px 且總寬 >1260 再縮；docs/shots-r8-en150 是英文 150% 截圖。
4. sprite_cache.draw_unit：atk>0 時 walk 當 0，貼圖與疊加的呼吸一致。
5. 測試逐事件核對攻擊者演出（fx 帶 src）、末格 0.5px；另外加了「畫面腳本能載入」的守門。

另外 c0cf37b：_text 加 maxw、fit()、圖鑑依字高排版 _fit_block。

請確認這五點是否修好、有沒有新問題。繁體中文、≤800 字，最後一句給「可否收尾」。
