唯讀審查，不改檔。《落子無悔》Godot 4.6 確定性自動對決。審 git diff v1.0-base..HEAD 裡 game/scripts/ 的地圖與模式：core/terrain.gd、core/map_defs.gd、core/battle_sim.gd（_t_ 開頭、fw/fh）、core/army.gd、core/ruleset.gd、core/formations.gd、core/mirror_check.gd、ui/ui_base.gd（_sync_field、_fld_xf、_btn）、ui/free_place.gd、ui/game_screens.gd、ui/lobby_view.gd、ui/screens/game_modes.gd、game_result.gd。繁中 900 字內、附 檔案:行號、沒證據別列：
1. 舊場次位元組會不會變；鏡像、僵局、卡牆（吸塵、擊退、分裂、復活、幽靈）；對戰代碼、重播、覆盤在非標準大小與地形下壞不壞（重播 rules 有帶地圖嗎？覆盤畫面、對戰代碼 decode 的縱深檢查）。
2. 滑鼠換算、全場模式、手把游標在小／大地圖對不對；連續地圖 map_mode、keep_formation。
3. 挑戰碼、試煉、禁牌、遠征獎勵、戰績的流程 bug（例如 trial_id 重置、challenge_army 殘留到下一局、last_armies、試玩版、存檔）。
最多 12 條必改（給具體失敗情境），最後一行「結論：可／有條件／不可」。
