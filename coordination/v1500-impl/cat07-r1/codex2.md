索引處理正確：召喚物開戰前預留，快照依序複製；焦點與血條判定已不讀動畫時鐘。只讀審查，未執行測試。

必改：

1. **P2 跟拍標記重複**：[新增白外緣 L1538](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1538) 後，[L843](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:843) 仍畫舊的粗金圈；新截圖可見兩圈疊加，削弱白色跟拍／朱紅目標的辨識。應合併為單一跟拍標記。
2. **P2 全形正號漏收**：[白名單 L1008](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:1008) 缺 `＋`，`＋３０` 仍判為文字並包泡泡，不符含全形正負號的規則。補入並加測。

結論：有條件
