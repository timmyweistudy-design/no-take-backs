唯讀審查，不改檔。《落子無悔》Godot 確定性自動對決。審第九輪 P2 步態（畫面層）：git diff 2200df8..HEAD；重點 game/scripts/ui/units/gait.gd、battle/battle_state.gd 的 _gait_tick/_walk_of、battle/battle_units.gd 的 _draw_units_of/_draw_death、sprite_cache.gd、units/*.gd。繁中 600 字內、附 檔案:行號：
1. 會不會影響模擬（指紋）？重播跳轉、略過、慢動作、變速、覆盤、結果畫面下步態有沒有壞？
2. 影格編號、bake 與 draw_unit 的離地與上半身轉換有沒有重複或不一致？overlay 位置？
3. 效能（每幀 sort、_walk_of 呼叫次數、_gait_tick 迴圈）。
最多 8 條必改，最後一行「結論：可／有條件／不可」。
