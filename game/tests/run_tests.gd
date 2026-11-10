extends SceneTree
## 測試入口（第七輪 I1 拆檔）：`godot --headless --path . --script res://tests/run_tests.gd [-- --only=<測試組>]`。
## 一律「至少 1 項通過且 0 失敗」才 exit 0（R2）；未知的測試組直接失敗。
## 測試組＝tests/suites/ 的檔名，另外 new＝units。
const FILES := {"v161": ["test_nb_key_v161", "test_nb_better_v161", "test_nb_sanitize_hash_v161", "test_pz_names_l10n_v161", "test_board_double_v161", "test_fog_free_v161", "test_hold_rebind_v161"], "v16": ["test_layout_r5_v160", "test_funnel_v160", "test_guide_v160", "test_tactical_marks_v160", "test_terrain_ai_v160", "test_access_settings_v160", "test_share_v160", "test_rush_v160", "test_coach_v160", "test_rift_v160", "test_persona_v160", "test_career_v160", "test_daily_board_v160", "test_foley_v160", "test_workbench_v160", "test_trio_v160", "test_fog_v160", "test_coop_v160", "test_adjacency_v160", "test_adjacency_code_v160", "test_save_v16_sanitize_v160", "test_mark_ids_v160", "test_state_reset_v160", "test_workbench_r2_v160", "test_sanitize_truncate_v160"], "modes": ["test_modes_v9", "test_flows_v9", "test_v10_fixes", "test_v10_input", "test_v10_feel", "test_v10_demo", "test_unit_brief", "test_no_unlock", "test_cmd_sim", "test_cmd_ui", "test_star_solutions", "test_trial_rules_valid", "test_daily_v11", "test_gauntlet_route_v11", "test_loss_summary_v11", "test_workshop_v11", "test_workshop_types_v11", "test_relay_v140", "test_playroom_v140", "test_commanders_v140", "test_waves_v140", "test_sealed_v140", "test_waves_lock_v140", "test_plan_fix_v140", "test_ghosts_v140", "test_sticker_reward_v140", "test_ga_info_v140", "test_sticker_contract_resume_v140", "test_mode_chain_v140", "test_unit_rec_v151", "test_wave_code_v151"], "maps": ["test_maps_v9", "test_maps_mirror_v9", "test_map_events_v140"], "anim": ["test_gait_v9", "test_gait_driver_v9"], "core": ["test_army_rules", "test_turn_placement", "test_determinism_and_mirror", "test_termination", "test_traits", "test_rule_fixes", "test_suspense", "test_codes_and_snake", "test_rally", "test_nav_r1", "test_golden", "test_stickers_v140", "test_boss_v140", "test_golden_v140"], "content": ["test_puzzle_solutions", "test_codex", "test_counter_lib"], "ui": ["test_event_routes", "test_ui_consumers", "test_sfx_priority", "test_play_effects", "test_input_queue", "test_crowd_readability", "test_replay_tools", "test_seek_clutch", "test_clutch_effects", "test_roster_ui", "test_replay_back_v7", "test_keymap_v7", "test_style_cache_v121", "test_ai_names_v121", "test_feel_v130", "test_characters_v131", "test_time_machine_v140", "test_contracts_v140", "test_nemesis_v140", "test_l10n_v140", "test_touch_v140", "test_projectile_timing_v150", "test_codex_controls_v150", "test_pause_menu_v150", "test_overlay_returns_v150", "test_data_swap_title_only_v150", "test_nav_back_v151", "test_cmd_delay_v151", "test_codex_summons_v151", "test_code_kind_speed_v151", "test_place_mode_v151", "test_free_tap_remove_v151", "test_codex_demo_projectile_v151", "test_layout_rules_v152", "test_layout_guard_wired_v152"], "units": ["test_new_units"], "rules": ["test_rules_v5", "test_sandbox_v5", "test_battle_code_v5", "test_rules_e2e_v5", "test_lobby_reopen_v5", "test_code_fuzz_v7"], "free": ["test_free_v6", "test_free_skip_v6", "test_review_free_v6", "test_to_free_keeps_units_v6", "test_free_review_fixes_v6"], "save": ["test_save_migration", "test_save_v7", "test_steam_v7", "test_play_log_v11", "test_records_v140", "test_paint_v140", "test_settings_v150", "test_presets_ten_v150", "test_restorable_v150", "test_playtest_report_v151", "test_backup_dir_prefix_v152"], "harness": ["test_harness_v7"], "fantasy": ["test_cat_pull", "test_fantasy_legacy_v8", "test_fantasy_rules_v8", "test_fantasy_regress_v8", "test_fantasy_mirror_v8", "test_fantasy_codes_v8", "test_fantasy_game_v8", "test_fantasy_codex_text_matches_stats"]}
const ALIASES := {"new": "units"}
## V1.1 E2：新測試只要登記在 FILES；ORDER 只保留舊執行順序，沒列到的依 FILES 順序接在後面。
const ORDER := ["test_cat_pull", "test_modes_v9", "test_flows_v9", "test_v10_fixes", "test_v10_input", "test_v10_feel", "test_v10_demo", "test_unit_brief", "test_no_unlock", "test_cmd_sim", "test_cmd_ui", "test_star_solutions", "test_trial_rules_valid", "test_maps_v9", "test_maps_mirror_v9", "test_gait_v9", "test_gait_driver_v9", "test_army_rules", "test_turn_placement", "test_determinism_and_mirror", "test_termination", "test_traits", "test_rule_fixes", "test_suspense", "test_codes_and_snake", "test_rally", "test_nav_r1", "test_puzzle_solutions", "test_codex", "test_event_routes", "test_ui_consumers", "test_sfx_priority", "test_save_migration", "test_play_effects", "test_input_queue", "test_golden", "test_crowd_readability", "test_replay_tools", "test_counter_lib", "test_seek_clutch", "test_clutch_effects", "test_new_units", "test_roster_ui", "test_rules_v5", "test_sandbox_v5", "test_battle_code_v5", "test_rules_e2e_v5", "test_lobby_reopen_v5", "test_free_v6", "test_free_skip_v6", "test_review_free_v6", "test_to_free_keeps_units_v6", "test_free_review_fixes_v6", "test_save_v7", "test_harness_v7", "test_code_fuzz_v7", "test_keymap_v7", "test_replay_back_v7", "test_steam_v7", "test_fantasy_legacy_v8", "test_fantasy_rules_v8", "test_fantasy_regress_v8", "test_fantasy_mirror_v8", "test_fantasy_codes_v8", "test_fantasy_game_v8", "test_fantasy_codex_text_matches_stats"]
var SUITES := {}
var ALL_TESTS: Array = []
var _objs := {}

func has_test(fn: String) -> bool:
	for g in FILES:
		if fn in FILES[g]:
			return load("res://tests/suites/%s.gd" % g).new().has_method(fn)
	return false

## V1.1 E2：suites 裡有 test_ 開頭的函式卻沒登記 → 擋下（以前會靜靜不跑）。
func unregistered() -> Array:
	var out := []
	var reg := {}
	for g in FILES:
		for fn in FILES[g]:
			reg[fn] = true
	var d := DirAccess.open("res://tests/suites")
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://tests/suites/" + f)
		for line in src.split("\n"):
			if line.begins_with("func test_"):
				var fn := line.substr(5).get_slice("(", 0).strip_edges()
				if not reg.has(fn):
					out.append(f.get_basename() + "." + fn)
	return out

## 純函式（測試用）：至少 1 項通過且 0 失敗才算成功。
static func exit_code(p: int, f: int) -> int:
	return 0 if p > 0 and f == 0 else 1

func _obj(g: String):
	if not _objs.has(g):
		_objs[g] = load("res://tests/suites/%s.gd" % g).new()
		_objs[g].runner = self
	return _objs[g]

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	for g in FILES:
		SUITES[g] = FILES[g]
	for al in ALIASES:
		SUITES[al] = FILES[ALIASES[al]]
	ALL_TESTS = ORDER.duplicate()
	for g in FILES:
		for fn in FILES[g]:
			if not fn in ALL_TESTS:
				ALL_TESTS.append(fn)
	var unreg := unregistered()
	if not unreg.is_empty():
		print("FAIL 測試函式沒登記在 FILES：", ", ".join(unreg))
		print("—— 0 通過 / 1 失敗")
		quit(1)
		return
	var names: Array = ALL_TESTS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prefix="):
			# V1.6 #4：會碰存檔的測試組分兩個行程平行跑，各用自己的存檔前綴
			load("res://scripts/game/save.gd").prefix = a.substr(9)
		if a.begins_with("--only="):
			# 第九輪 P0：可以逗號列多個，每項是測試組或單一 test_ 函式名
			names = []
			for k in a.substr(7).split(","):
				if k.begins_with("-"):
					names.erase(k.substr(1))   # 例：--only=core,-test_golden
				elif SUITES.has(k):
					names.append_array(SUITES[k])
				elif k in ALL_TESTS:
					names.append(k)
				else:
					print("FAIL 未知的測試組：", k, "（可用：", ", ".join(SUITES.keys()), "）")
					print("—— 0 通過 / 1 失敗")
					quit(1)
					return
	for fn in names:
		for g in FILES:
			if fn in FILES[g]:
				var t1 := Time.get_ticks_msec()
				_obj(g).call(fn)
				print("TIME %s %d" % [fn, Time.get_ticks_msec() - t1])
	var p := 0
	var f := 0
	for g2 in _objs:
		p += _objs[g2].passed
		f += _objs[g2].failed
	print("—— %d 通過 / %d 失敗（%d ms）" % [p, f, Time.get_ticks_msec() - t0])
	quit(exit_code(p, f))
