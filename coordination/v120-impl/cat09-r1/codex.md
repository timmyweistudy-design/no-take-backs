只讀審查；未執行測試。第 9 大類有 4 項必改：

1. [battle_view.gd:212](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:212)：`_pump_view()` 仍把 EXT_FIRE 收入 `atk_hit／atk_seq／proj_tgt`。因此命中處雖提前返回，前搖階段仍會讓存活射手拉弓、飛箭；射手剛倒下時也可能預播假箭。改為在登記攻擊動畫前跳過 EXT_FIRE，保留傷害統計與歸屬。

2. [frags.gd:74](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/frags.gd:74)：單格上限只在 `_admit()` 檢查；水平移動後，多格碎片可聚入同格超過兩片，之後新增也只刪一片。改為移動後重新分格，每格依 `born` 留最新兩片；補跨格聚集測試。

3. [game_screens.gd:699](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:699)：繪製沒有檢查 `_frags_on()`。戰鬥中切減少特效、簡化或 4 倍速，只停止生成，舊碎片仍顯示到消失。改為關閉時清空並停止繪製，補切換測試。

4. [ui.gd:10](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:10)：事件測試未開擴充規則，實際碰不到 RESCUE／BEAT／EXT_FIRE；TAGS 雖已登記，沒有驗證新事件。加入必定觸發三者及射手先倒下的案例，斷言標籤、分流與無額外箭。另 [battle_visual.gd:675](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/battle_visual.gd:675)「最新仍在」是從剩餘列表取最大值再查存在，必然通過；應核對預期保留序號。

其餘：總數 30 與丟最舊正確，獨立於 FX_CAP，不會淘汰必要提示；每命中最多掃約 3×30，逐幀最多 30，未見明顯效能風險。雜湊固定初始散射；完整截圖重現需既有 `--shot-fixed`。現行 seek、開局及重播返回均清空，結果頁不畫碎片。倒下單位仍保留，last_hitter、戰報、MVP、跟拍未見失效引用。RESCUE 僅新增事件標籤，未進模擬雜湊，金標準指紋不應改變。

結論：有條件