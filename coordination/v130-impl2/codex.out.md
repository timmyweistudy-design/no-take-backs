唯讀靜態審查完成；未改檔、未跑 Godot。以下檔名以 `game/scripts/ui/` 為基準。

1. **倒棋：已修。** `battle/battle_units.gd:726、740`：TOPPLE 先處理，1.3～1.7 秒淡出可到達。
2. **墓旗：已修。** `game_screens.gd:405`：只在跨越 1 秒時插旗一次。
3. **眼睛 transform：已修。** `units/kit.gd:110`：恢復 `_cur_xf`，不再破壞頭部部件轉換。
4. **轉身：部分修好。** `sprite_cache.gd:254`：出手寬度最低 0.45 正確；但 `sprite_cache.gd:287` 的 overlay 仍用正側面座標。烘焙眼睛中心依 `turn_c` 移動（`units/kit.gd:108`），overlay 未同步；盾、槍也未套部件透視，受擊眼睛、眉毛與武器光效仍會錯位。
5. **跳字：已修原問題。** `battle/battle_fx.gd:723`：只平移字與泡泡，移除新增放大；既有合併縮放與外框計算一致（`battle/battle_state.gd:126`）。
6. **首次破陣／暫停：未修。** `battle_view.gd:497` 已在 `with_fx=false` 時返回，故 `battle_view.gd:584` 永遠記不到跳播。另 `replay_view.gd:151` 清空後，前段快轉僅統計事件（`:115`），也未重建；只搬動賦值仍不足。暫停時 `game_screens.gd:384` 繼續累加 `time`，展示仍會耗盡。
7. **頭頂符號：已修主要規則。** `battle/battle_fx.gd:306` 選存活時間最長者刪除，再加入新提示。

新增檢查：

- **ring 十格未見索引錯誤。** `sprite_cache.gd:184、366、374` 對應圈 0～3、木座 4、影子 5、合成 6～9；`:212` 合成格選取正確。分層只縮影子並恢復 transform（`:215`）；戰場在 `battle/battle_units.gd:415` 才套用 0.15 門檻。
- **draw_base 未見新錯。** `sprite_cache.gd:226` 的原點、倍率、alpha 與 transform 還原一致；呼叫端有 ready 判斷（`battle/battle_units.gd:734`）。
- **新增小缺陷：** `battle/battle_fx.gd:309` 先刪舊提示，`:321` 才去重；新提示若遭拒，會白白少一筆。建議先通過去重再淘汰。

剩餘必修：轉身 overlay 對齊、跳播完整重建首次破陣、暫停凍結或清除展示。`game/tests/suites/ui.gd:813` 的新增測試未覆蓋這三項，不能據此判定修復完成。

結論：有條件同意（完成上述三項必修）
