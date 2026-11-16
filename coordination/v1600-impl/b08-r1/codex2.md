- [battle_fx.gd:330](game/scripts/ui/battle/battle_fx.gd:330)：合併使文字變寬，卻未重算已放好的 rr／dr、避讓與面積預算；當幀可蓋臉、出盤，量測仍用舊框。須重新排版。
- [battle_fx.gd:327](game/scripts/ui/battle/battle_fx.gd:327)：異種關鍵字也累加 n／sum，卻不更新文字；下次同種合併會把其他技能傷害算入。須保留各事件語意，或轉戰報並正確計數。
- [battle_fx.gd:316](game/scripts/ui/battle/battle_fx.gd:316)：下外擴 12px 不足；紙條底點實際達 r.end.y＋13.1（2＋9.5＋1.6），仍漏算 1.1px，零遮蓋／出盤量測不成立。

結論：不可
