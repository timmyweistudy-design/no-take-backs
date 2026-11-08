唯讀檢查完成，未改檔、未跑 Godot。以下路徑皆相對 `game/`。

- **定格完全不會觸發**：`scripts/ui/battle_view.gd:470` 讀死亡事件的 `src`，但 `scripts/core/battle_sim.gd:862` 只提供 `kind、id`，故 `last_kill[0]` 永遠為 −1。正常播放與重播皆失效。
- **計時問題被上述 bug 遮住**：`scripts/ui/battle/battle_units.gd:583` 使用全域 `time`，而 `scripts/ui/game_screens.gd:384` 在暫停、頓格期間仍累加；修好來源後，暫停會耗完定格，殘局頓格也會吃掉其時間。另開戰、seek 未清除紀錄，`with_fx=false` 又不更新，須一併處理，避免跳播沿用舊紀錄。
- **遺物提前消失**：`scripts/ui/battle/battle_units.gd:787` 在屍體透明度歸零（約 0.75 秒）便返回，導致 `:832` 不再畫遺物；但 `:838` 的遺物此時仍約有 83% 不透明度，會突然消失，無法淡出至 1 秒。應讓遺物繪製獨立於屍體透明度。

其餘：`sfx.gd:136` 的預設 pitch 保持舊呼叫相容；環境音獨立，UI 音與 FakeSfx 相容。`_draw_relic` 有 reduce_fx／時間防護，未見生命週期越界。`ui_base.gd:939` 是每實例緩衝區，多個 CanvasItem 不會共用。補丁未改模擬或 FINGERPRINT；未執行驗證數值。

結論：有條件同意（修正擊倒者來源、定格計時與重設、遺物提前截斷）
