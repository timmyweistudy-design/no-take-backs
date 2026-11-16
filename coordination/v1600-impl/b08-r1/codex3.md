- [battle_fx.gd:306](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:306)：重排期間仍可合併，但 `_relayout_in` 阻止再次重排，313 行又清掉標記。例如首輪 C 併入 B；次輪 B 變寬擠不下，再併入已排好的 A，A 的框、避讓與面積仍是舊值。裁決：第 2 輪第 1 條仍未解；最後一次排版須禁止合併，擠不下轉戰報。

結論：不可
