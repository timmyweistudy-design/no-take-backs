唯讀靜態審查完成；未改檔、未跑 Godot。以下路徑以 `game/scripts/ui/` 為基準。

**必修**

- `battle/battle_units.gd:724`：舊 `al <= 0` 提前返回，讓 TOPPLE 在 0.75 秒消失，後面的 1.3～1.7 秒淡出永遠跑不到。修法：TOPPLE 分支移到舊透明度判斷之前。
- `game_screens.gd:406`：倒棋延長至 1.7 秒後，從第 1 秒起每幀都新增墓旗，單次死亡可累積數十筆。修法：只在跨越門檻時新增一次，或於移除 dying 時新增。
- `units/kit.gd:107`：`_eyes()` 恢復的是身體 transform，會破壞呼叫前 `_part()` 的頭部 transform；劍士、盾兵、騎士眼睛之後的頭盔又被壓窄。修法：保存並恢復目前部件 transform，讓 `_part_end()` 才結束部件。
- `sprite_cache.gd:239`：轉身分支直接 return，遺失 `mood`，包括受擊表情、狂熱眉毛、頂盾等；`hurt`、alpha、lean、crouch 有保留。另外 `battle/battle_state.gd:425` 對試點回傳最低 0.18，但攻擊會跳過轉身分支，重新把整張攻擊圖夾到 0.18。修法：轉身頁補對齊後的 overlay；轉身進度與一般貼圖寬度分開傳。
- `battle/battle_fx.gd:725`：字體新增最多 1.3 倍印章縮放，`battle/battle_state.gd:126` 的排版外框卻未計入，文字會超出泡泡、遮擋判定失準。修法：繪製與外框共用字級計算。
- `replay_view.gd:151`、`battle_view.gd:497`：跳播把 `key_used` 清空，略過的首次破陣又不記狀態；跳到首次破陣之後，第二次破陣仍會演「首次」。`game_screens.gd:505` 也讓效果在暫停時繼續消耗。修法：快轉時重建首次破陣是否發生；暫停時清除或凍結展示計時。
- `battle/battle_fx.gd:305`：OVERHEAD_CAP 滿時丟新的，與方案「先砍舊的」相反，新事件提示會被舊提示擋住。修法：淘汰同種類最舊的一筆再加入。

**建議**

- `ui_base.gd:971、991、1007`：粉筆線每幀逐段計算及呼叫繪製；波線、手繪圈仍每次配置點陣列，不能據此宣稱不增加成本。修法：靜態線預烘，動態圈快取幾何；效能節省待實測。
- `free_place.gd:632`：沉降中的角色仍以原高度補畫 xray，密陣會出現錯位重影；群拖成功也未登記沉降。修法：xray 共用沉降位置，群拖逐隻登記；中斷時清理相關狀態。
- `ui_base.gd:951`：settle 鍵目前皆為 Vector2i，型別無誤，但只靠再次繪製該位置清理。修法：定期清除過期項目，換陣時清空。

**不用改**

- `sprite_cache.gd:313、337`：烘焙同步區段會關閉呼吸並恢復 turn 狀態；未找到污染一般烘焙、圖鑑或 MVP 的路徑。一般 overlay 呼吸對齊，保留。
- `sprite_cache.gd:93、94、331`：轉身隊伍排列與 `_post(per=3)` 相符，世代檢查完整；六格 ring 與 air 縮影邏輯可保留。
- `battle/battle_units.gd:438`：九桶搜尋、嚴格 `<1600`、扣自己及 pc 快取與舊雙迴圈等價，保留。
- 箭 fly/dur、跳字數量上限、inkring 去重與 reduce_fx、木珠、chart_zoom、ui_quill 登錄未見確定錯誤；保留。diff 未改模擬或 FINGERPRINT，實際指紋未執行驗證。

結論：先修七項必修，再做逐格與效能驗收。
