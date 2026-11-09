已比對 `3a44461～9fe7f37` 的五個 commit、方案及 ledger。全程只讀；以下為靜態審查，未啟動 Godot。裁切尺寸與校對佔位符另以不寫檔的 Python 驗證。

依嚴重度排序，共 12 條：

1. **P1｜擺陣頁開圖鑑，返回會誤回卡片面板。**  
   [ui_base.gd:946](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:946)、[game_result.gd:17](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:17)  
   路徑：「對戰」→「對 AI」→大廳開戰進入擺陣→F1 開圖鑑→返回／Esc／B。進入擺陣時未清除 `hub_play` 堆疊，開圖鑑也未登記擺陣來處，因此返回會彈出 `hub_play`。此時底層仍是 `St.PLACE`，卻顯示主畫面的卡片面板。殘局、試煉首次擺陣同樣受影響。

2. **P1｜匯入、恢復預設會繞過全螢幕 10 秒保護。**  
   [game_menus.gd:757](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:757)、[game_menus.gd:802](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:802)  
   匯入與目前 `fullscreen` 不同的 NTS1 設定，或全螢幕下恢復畫面頁預設，直接經 `_apply_all_settings()` 切換；不會建立 `fs_prev`、期限及確認框。若新顯示狀態不可用，沒有自動還原。

3. **P2｜通用 Esc／B 返回分支仍與畫面返回鈕不一致。**  
   [game_screens.gd:344](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:344)  
   這些子頁未登記堆疊，卻一律呼叫 `_nav_back()`：
   - 遊戲間→競猜／輪抽→Esc／B：回主畫面；返回鈕則回遊戲間。
   - 代碼→貼上 NTW1→選波頁→Esc／B：回主畫面；返回鈕則回代碼。
   - 系列戰中暫停→離開確認→Esc／B：關閉選單但保留 `paused=true`；「留下」則回暫停選單。

4. **P2｜實驗室局仍污染新兵種戰績。**  
   [game_result.gd:84](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:84)、[game_modes.gd:893](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd:893)  
   開啟沙盒數值調整、完成對 AI／雙人局。`_progress_and_achievements()` 雖因 `BADGE_LAB` 返回，呼叫端仍繼續 `_record_match()`，增加 `unit_games_rec`、`unit_wins_rec`。因此可用調整數值的局刷兵種勝率，違反介面「沙盒不記戰績」的說明。

5. **P2｜攻擊轉身使用真實時鐘，暫停與倍速下會失同步。**  
   [battle_units.gd:719](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:719)  
   轉身途中出手後立即暫停，`time` 仍增加，繪圖中的插值仍會完成轉身，攻擊進度卻停住。8 倍速時，一次攻擊可能在約 0.04 秒內播完，轉身仍要求真實時間 0.12 秒，造成整擊尚未轉正，連擊又重新取起點。

6. **P2｜戰中重烘圖集後，轉身攻擊格整局不會補回。**  
   [sprite_cache.gd:96](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:96)、[ui_base.gd:1108](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1108)  
   已開戰→設定切換色盲，或執行會呼叫 `_apply_all_settings()` 的恢復預設。`build()` 清空 `ta_tex`，但只有開戰的 `_ensure_sprites()` 會呼叫 `ensure_turn_atk()`；當前戰鬥不會重新要求補烘。之後一般攻擊持續退回強制側面，重新出現跳格。

7. **P2｜手動軍令局的投彈兵近身敲擊，前搖少播一 tick。**  
   [battle_state.gd:98](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd:98)、[battle_units.gd:585](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:585)  
   投彈兵貼身觸發 `BONK`，沒有飛行物。`proj_phase()` 仍按兵種取得 `wind=1`，到命中前一 tick 才選中此擊；後續動畫卻按非飛行命中的 `wind=2` 計算。首次顯示便已走過一半前搖，原先應出現的第一 tick 被跳過。

8. **P2｜近看放大會裁掉長槍槍尖。**  
   [codex_bake.gd:6](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd:6)、[codex_view.gd:683](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:683)  
   圖鑑→長槍兵→近看→放大→一般攻擊揮擊末端。固定貼圖為 `380×330`，腳底置於 x=190，只剩右側 190px；依武器與姿勢轉換計算，3.4 倍時槍尖約伸到右側 241px，因此約 51px 超出貼圖，槍尖被硬切。

9. **P2｜關閉圖鑑後，兩個 SubViewport 仍永久持續渲染。**  
   [codex_bake.gd:41](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd:41)、[codex_bake.gd:48](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd:48)  
   首次開啟非簡化圖鑑後返回，`cx_bake` 持續掛在遊戲節點下，兩個 viewport 都是 `UPDATE_ALWAYS`；沒有關閉時停用或釋放的路徑。之後主畫面、戰鬥甚至切成簡化介面，仍保留渲染目標並執行後處理。這是持續資源占用，並非每次開啟都增加一份。

10. **P2｜校對回填漏驗浮點格式，可能放入無法格式化的譯文。**  
    [l10n_review.py:39](/mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_review.py:39)  
    `var_set()` 只辨識 `%d`、`%s`、`%%`。例如將 `rc_time` 的兩個 `%.1f` 全刪掉，仍通過驗證；簡中重建又直接採用校對文字，沒有第二次驗證。遊戲帶入兩個格式參數時會產生格式化錯誤；日文則可能被後續建置退回英文。

11. **P2｜部分日文校對回填成功，重建後卻被舊覆寫表蓋掉。**  
    [l10n_build.py:113](/mnt/c/Users/timmy/projects/no-take-backs/tools/gen/l10n_build.py:113)  
    校對 `pf_none`、`set_tab_6` 等已列入 `OVERRIDE` 的日文鍵→import→重建。輸出先取 `OVERRIDE`，根本不讀校對後的 `ja_zz_review.json`。工具顯示回填成功，但遊戲仍保留舊譯文，母語校對無法生效。

12. **P3｜預設套用預覽沒有顯示「舊值→新值」。**  
    [game_menus.gd:730](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:730)  
    設定→無障礙→套用任一有差異的預設。確認框只有項目名稱與數量，例如「震動、閃白、慢動作」，看不到各項目前值與套用值。玩家無法在確認前判斷實際變更，未完成方案 C2 要求的差異預覽。

ledger 六條 **Ruling** 的裁決如下：

| Ruling | 表態 | 理由 |
|---|---|---|
| A3：交替／特殊攻擊不烘轉身格 | **不同意** | 「轉身出手不跳」是本輪核心目標，交替攻擊也包含常見劍士招式；記憶體理由尚缺實測，不能據此宣告 A3 完成。 |
| A4：不另做雙手武器畫序 | **不同意** | `_part()` 改的是部件位置與縮放，沒有交換繪製順序，不能作為前後手遮擋已處理的證據。需要對應角度的驗收圖。 |
| B2：不重建跳轉後飛行物與墓旗 | **不同意** | 短緩衝回溯無法涵蓋存續數秒的歷史特效；ledger 也承認仍缺畫面。這是已知未完成項，不能以局部回溯替代方案驗收。 |
| C3：不做「只拖曳」 | **同意** | 「只點選」與「點選＋拖曳」已涵蓋主要需求；禁止點選本身缺乏明確效益。方案與說明應同步改成兩選項。 |
| C4：不做移除工具與時間軸點選操作 | **不同意** | 只點選擺兵並未改善移除兵與編排軍令，兩者是獨立需求；「要另設計」可作延期理由，不能視為已被其他功能解決。 |
| C7：不做進階收合 | **同意** | 資訊可見性與免捲動足以支持保留展開；但 ledger「每頁最多七列」已被資料頁八列推翻，應以四語、150% 字級實際版面證據結案。 |