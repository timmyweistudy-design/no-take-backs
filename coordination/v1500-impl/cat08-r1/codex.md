必改 1 項：

- [battle_units.gd:219](game/scripts/ui/battle/battle_units.gd#L219)：浮籤移到左上後，放大鏡仍只排除右上（[battle_view.gd:1153](game/scripts/ui/battle_view.gd#L1153)）。若放大鏡原在左上，遲滯會保留位置，且它後畫，會遮住浮籤。須依浮籤實際位置排除角落。

其餘核對：game_screens.gd:840 已切回 IDENTITY，217 行 `_cam * _upos(u)` 正確；224–227 行墨色開關無漏關。game_v16.gd:2484 仍登記按鈕，primary 不影響焦點；入口 game_menus.gd:1652 歸零焦點，第一題仍為預設。

結論：有條件
