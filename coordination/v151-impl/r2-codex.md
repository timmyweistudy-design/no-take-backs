以 **`37c0a6e` 為準，尚不能全數結案**。本次只讀檔，未修改檔案；完成靜態追查、拼表檢視與不寫檔的數值驗證，未啟動 Godot。審查期間出現的未提交 `codex_view.gd` 修改不納入判定。以下行號均指該 commit。

**第 1 輪「已修」逐條驗證**

| 項目 | 結論 |
|---|---|
| 擺陣開圖鑑返回錯頁 | **已修**。`_start_mode()` 清空堆疊；每日挑戰也經過此入口。 |
| 匯入／恢復預設繞過全螢幕保護 | **已修**。相關路徑都有 `_guard_fs()`；通用確認框先設 `overlay = confirm_ret` 才執行回呼，不會覆蓋新開的 `fs_confirm`。Esc 會還原。 |
| 競猜、輪抽、選波、幽靈、每週與離開確認的 Esc／B | **列出的路徑已修**。但 Antigravity #7 的試玩版戰後返回、備份還原返回仍未處理，見下方。 |
| 實驗室局污染新兵種勝率 | **已修**。新增的 `unit_games_rec`／`unit_wins_rec` 在沙盒判定後才更新；舊 `unit_games` 仍會增加。 |
| 轉身使用真實時鐘、零寬度、漏畫表情 | **部分已修**。改用畫面 tick、最小寬度 0.45、表情補畫均正確；反方向攻擊前半仍背對目標。 |
| 重烘後未補回轉身攻擊格 | **已修，受 10 種上限限制**。保留 `ta_wanted`，重建完成後重新要求烘焙。 |
| 投彈兵敲擊少一格前搖 | **已修**。近身命中使用自己的兩 tick 前搖。`proj_phase()` 兩個正式呼叫端都已核對：角色動畫讀第 4、5 欄，陣亡施放者的飛行物只讀前三欄，沒有漏接或錯位。 |
| 轉身攻擊格新增交替／特殊招式 | **索引正確**。貼圖為 `3072×384`，一般／特殊各八格；藍隊 0–15、紅隊 16–31。`_post(img, 16)` 正確讓兩列分別使用兩隊墨色。 |
| 近看長槍裁切、子視窗持續渲染 | **原問題已修**。水平空間足夠；閒置超過 300ms 停用兩個 viewport，使用時恢復。但著色器高度映射另有問題，見新問題 #4。 |
| 校對格式碼、日文覆寫優先序 | **原案例已修**。`%.1f`、`%+d`、`%%` 可辨識；`ja_zz_review.json` 優先於 `OVERRIDE`。 |
| 預設預覽舊值→新值 | **已修**，確認文字已有逐項差異。 |
| 召喚物近看殘留、劍士特殊 variant | **已修**。開圖鑑重設近看，經典兵使用 variant 1。 |
| 軍令同刻去重、跳轉 fallback 延遲 | **這兩項已修**。去重包含 `skill`，fallback 與 `ViewBuffer` 的延遲選法一致。但同條意見中的 `replay_marks` 殘留尚未處理。 |
| 寶箱怪背面、騎兵馬頭 | **原指出的幾何問題已修**；已檢視拼表，仍需動態驗收角度切換。 |
| 開場軍令冷卻遮罩 | **未修好**。目前公式不能解決原回報。 |

**仍未結案的既有問題**，不算本輪新問題：

- [battle_units.gd:728](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:728)：反向出手時，`kf < 0.5` 仍取 `signf(f0)`，前半段仍朝舊方向蓄力。零寬度已修，背對目標問題僅縮短。
- [battle_view.gd:477](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:477)：`cmd_cd=160`、開場等待 60 tick 時，遮罩仍從 **37.5%** 開始；冷卻小於準備時間時，又會先維持滿格一段時間。分母需要固定的階段總長，不能取每幀剩餘等待。
- [replay_view.gd:319](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd:319)：`watch_code()` 與 `_begin_battle()` 都沒有清除／重建 `replay_marks`，輸入他人代碼仍可能顯示上一局的時間軸刻度。
- [game_place.gd:45](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:45)、[game_menus.gd:905](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:905)：試玩版戰後仍不回卡片面板；備份還原成功仍關閉設定。這兩項是 Antigravity #7 尚未涵蓋的分支。

ledger 判為誤報的兩項，我**同意撤銷**：對 AI 的敵軍確實沒有混入新勝率；全螢幕確認框的 Esc 確實走還原。至於「特殊挑戰一律排除戰績」，方案 0.2 要求的是分子分母一致，沒有明定全面排除，不能據此直接判錯。

**「重新裁決」四條表態**

| 條目 | 表態與理由 |
|---|---|
| A3 補交替／專屬轉身格 | **同意改案，暫不同意宣告完成**。兩列與著色索引正確，但反向前搖仍有上述問題；超過十種時也仍有側面退路，「一律不跳」描述過滿。 |
| B2 重建陣亡旗與飛行物 | **部分同意**。緩衝回溯能重新登記飛行物；陣亡旗只補到部分死亡時間，見新問題 #1。 |
| C4 點一下移除、時間軸延後 | **部分同意**。點選移除方向可接受，但自由排兵漏接、格子模式也未可靠區分拖曳。時間軸可明確列延期，不能算原需求已完成。 |
| A4 維持不改畫序 | **仍不同意據此結案**。`_part()` 只改位置與縮放，沒有交換繪製順序；現有拼表也不足以驗證 3/4 角攻擊全程的前後手遮擋。這是驗收證據不足，並非本輪已確認新的穿插案例。 |

**本輪新問題共 4 條**

1. **P2｜跳轉前不足一秒的死亡，之後永遠不插旗。**  
   [replay_view.gd:167](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd:167)  
   **觸發**：長緩衝重播跳到 tick 100，某兵在 tick 90 死亡。快轉停在 92，因此死亡已收進 `_seek_deaths`；但 `age=0.5` 被排除，且沒有重建 `dying`。  
   **後果**：恢復播放後沒有跨過一秒的死亡演出可觸發插旗，該兵的小旗整段缺失。應重建剩餘死亡演出或安排延後插旗。

2. **P2｜取消拖曳會被誤判成點選刪兵。**  
   [game_screens.gd:282](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:282)  
   **觸發**：「只點選」模式抓起既有兵，拖離原格，再拖回原格放開。  
   **後果**：只比較起終格相同便刪兵，無法辨識玩家曾拖曳；取消搬移反而移除單位。需要記錄拖曳距離／是否跨過門檻。

3. **P2｜自由排兵沒有「點一下自己的兵拿掉」。**  
   [game_screens.gd:241](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:241)、[free_place.gd:354](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/free_place.gd:354)  
   **觸發**：自由排兵選「只點選」，點一下可編輯的己方兵。  
   **後果**：事件先被 `_fp_mb()` 消耗，永遠到不了新增的格子移除分支；自由模式只會搬移或原地不動，與設定說明不符。

4. **P2｜圖鑑漬洗／乾掃高度仍與戰場不一致，縮放還會改變明暗分布。**  
   [codex_bake.gd:55](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_bake.gd:55)、[unit_bake.gdshader:29](/mnt/c/Users/timmy/projects/no-take-backs/game/shaders/unit_bake.gdshader:29)  
   **觸發**：一般圖鑑大圖與近看切換縮放。`cell` 固定約 444，只對齊腳底比例，沒有依角色縮放調整。  
   **後果**：同一局部高度 `y=-40`，戰場烘焙的 `ly=0.5`；圖鑑兩倍時卻是 `0.653`，已進入陰影區，放大至 3.4 倍又變成 `0.527`。單純放大會改變角色著色，尚未達到 A6 的一致化。