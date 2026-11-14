只讀審查，未執行測試。同刻 ID 排序及死亡／隱身排除正確；直接送三角形仍沿用同一 CanvasItem 的命令順序與 transform（[引擎實作](https://github.com/godotengine/godot/blob/4.6/scene/main/canvas_item.cpp#L881)），未見鏡頭／table_view 額外錯位。

必改：

1. **P1 時間基準**：[焦點判定 L1525](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1525) 使用持續前進的 `time`；暫停後暈光消失、血條變淡。跳轉清空紀錄且 `with_fx=false` 不補回，同 tick 與順播不同。改用展示 tick 並重建近期事件。
2. **P1 固定截圖**：上述判定遇 [L496 重設時鐘](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/dev_main.gd:496)，事件時間未同步：前跳使焦點失效，倒退則負時間差也算近期。隔離動畫時鐘，並限制 `0≤age<期限`。
3. **P2 合併數字漏降噪**：[L1002](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:1002) 拒絕實際合併字串 `×3（24）`，仍畫泡泡。應依事件種類／tier 決定樣式；帶單位、全形數字及各負號須明訂政策。
4. **P2 噪音預算漏接**：[L1531](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1531) 暈光直接畫，未納入 `FX_CLASS` 地面預算及強調仲裁；獨立四隻上限不足以滿足規劃。
5. **P2 測試不足**：[L1038](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/battle_visual.gd:1038) 僅測純函式。須補同刻亂序、暫停／倒帶／固定截圖、合併字串及鏡頭對位回歸。截圖與暫停仍屬 `live`（`s==view`），不能用非 live 分支解釋。

結論：有條件
