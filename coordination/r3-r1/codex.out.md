以 **b0cd97e** 為準，唯讀審查，找到三項需修正：

1. **高｜新事件會讓正式戰鬥畫面報錯。**  
   [battle_sim.gd:314](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:314) 新增的 `rally_on/off` 只有 `team`，但 [battle_view.gd:103](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:103) 無條件讀 `src/tgt`；目前背水比例為 60，實戰可觸發。`taunt/flank/reveal` 雖有來源與目標，也被誤播成攻擊，更新攻擊動畫、受傷閃白並播放砍擊音效。建議先分流非傷害事件，只有帶 `dmg` 的事件進入攻擊演出；補正式 UI 消費各類事件的測試。純模擬測試抓不到這個問題。

2. **中｜小劇場技能觸發，卻不會跳字。**  
   [codex_view.gd:88](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:88) 把事件中的單位 ID 當成 `units` 索引。ID 是隊伍／格位編碼，例如藍方 `(5,4)` 為 69，遠大於示範兵數，因此遭範圍檢查略過；即使碰巧落在範圍內，也可能指錯單位。改用 `cx_sim.unit_by_id(who)`。現有 `test_codex` 只確認標籤出現，故仍綠燈；應推進 `_codex_tick()` 並確認 `cx_pops` 有正確位置的提示。

3. **中｜拖曳／塗兵狀態跨圖鑑殘留。**  
   [codex_view.gd:26](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:26) 開啟圖鑑未清除 `painting/drag_new/drag_from`；[game_screens.gd:552](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:552) 又在覆蓋層存在時提前返回，連滑鼠放開的清理都跳過。重現：按住塗兵→F1→放開滑鼠→Esc，之後僅移動滑鼠便繼續放兵；拖曳也可能在後續點擊誤移動／刪兵。建議開圖鑑時取消全部拖曳狀態，並讓放開事件始終執行清理。

勝場語意目前一致：對 AI／教學／殘局／遠征只計藍方勝，雙人計勝方兵種；包含已陣亡但曾上場的兵種，每小局或遠征每關各算一次。結果結算末尾統一存檔，圖鑑本身不寫檔。這符合共用本機進度的解讀，建議補各模式整合測試固定此規則。

新增模擬運算未見浮點或左右鏡像破壞來源。本機 Godot 啟動即崩潰，未能重跑測試。

可否繼續：**先修正以上三項並補驗證，再繼續。**