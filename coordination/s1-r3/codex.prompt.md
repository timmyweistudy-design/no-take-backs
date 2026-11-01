# 程式輪 S1～S4 第 3 輪（Codex 唯讀，本批最後一輪）

請看 `git diff f39ae64 HEAD -- game/`。

**你上一輪（coordination/s1-r2/codex.out.md）的點**：
- 硬上限：沒有同種可併時取代最舊的跳字；新測試一口氣 30 個關鍵跳字仍 ≤12，混戰測試改成嚴格 ≤TEXT_CAP。
- 塗兵：滑鼠移動一律排入，由 _paint_cmd 判斷。
- DPS：改成 atk×20/cd。另外 Claude 發現 atk_progress 與劍士交替也把 cd 多除了 4，一併修。
- 捲動：_scroll_draw 量完內容後重新夾 offset；大頭照區固定（"head" 區不可捲）。
- 時間軸：先排星等、系列、遠征、試玩評分，剩下空間給時間軸（不夠就縮或不畫）；標籤上下兩排；指紋放不下就不畫。
- 頂住標記改用 tgt 的隊伍。
- layout_check：每組 exit code、腳本錯誤、截圖張數（6×15）都檢查。90 張 0 違規。

**S4（7d992d6）**：
- art.gd variant（劍士上挑）、sprite_cache 交替招式 8 格（FRAMES_PER 2+6+8×2）。
- 盾擊前推、拉弓時看得到箭、刺客後手刀交叉、騎兵命中抬前蹄。
- graves 陣亡小旗 3 秒。

請確認修好了沒有、有沒有新問題（特別是 S4 圖集索引與 variant 傳遞、atk_progress 改單位後的時序）。繁體中文、≤800 字，最後一句給「可否繼續」。
