只讀靜態審查，必改 3 項：

1. **P2｜[game_menus.gd:1037](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:1037)**：資料頁進階 5／6 列時，R14 實際計數為 **11／12**（分頁組、整頁恢復、各列、抽屜、單項恢復、底部兩鈕）。`click_count()` 連停用鈕也計入，現有豁免只涵蓋撤回，會直接失敗。須減項或補合理豁免及文件。

2. **P2｜[game_menus.gd:738](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:738)**：抽屜開合只清 `_btns`，舊 `vol_rails` 留到重畫。聲音頁同幀開抽屜再按舊木軌，`vol_press()` 仍可修改已隱藏音量。開合時應結束拖曳並清木軌。

3. **P2｜[ui.gd:2553](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:2553)**：測試手造按鈕後只驗 `set_adv_focus` 旗標，未重畫、驗實際焦點或再次按 A；移除焦點恢復程式仍會通過。須補開合重畫後的焦點、列說明及木軌位置回歸。

列繪製、滑鼠／手把判列與木軌都共用 `_settings_row_y()`，正常重畫後的位移一致。

結論：有條件
