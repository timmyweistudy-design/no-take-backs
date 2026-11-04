extends SceneTree
## 測試入口（第七輪 I1 拆檔）：`godot --headless --path . --script res://tests/run_tests.gd [-- --only=<測試組>]`。
## 一律「至少 1 項通過且 0 失敗」才 exit 0（R2）；未知的測試組直接失敗。
## 測試組＝tests/suites/ 的檔名，另外 new＝units。
const FILES := {"core": ["test_army_rules", "test_turn_placement", "test_determinism_and_mirror", "test_termination", "test_traits", "test_rule_fixes", "test_suspense", "test_codes_and_snake", "test_rally", "test_nav_r1", "test_golden"], "content": ["test_puzzle_solutions", "test_codex", "test_counter_lib"], "ui": ["test_event_routes", "test_ui_consumers", "test_sfx_priority", "test_play_effects", "test_input_queue", "test_crowd_readability", "test_replay_tools", "test_seek_clutch", "test_clutch_effects", "test_roster_ui", "test_replay_back_v7", "test_keymap_v7"], "units": ["test_new_units"], "rules": ["test_rules_v5", "test_sandbox_v5", "test_battle_code_v5", "test_rules_e2e_v5", "test_lobby_reopen_v5", "test_code_fuzz_v7"], "free": ["test_free_v6", "test_free_skip_v6", "test_review_free_v6", "test_to_free_keeps_units_v6", "test_free_review_fixes_v6"], "save": ["test_save_migration", "test_save_v7", "test_steam_v7"], "harness": ["test_harness_v7"]}
const ALIASES := {"new": "units"}
const ALL_TESTS := ["test_army_rules", "test_turn_placement", "test_determinism_and_mirror", "test_termination", "test_traits", "test_rule_fixes", "test_suspense", "test_codes_and_snake", "test_rally", "test_nav_r1", "test_puzzle_solutions", "test_codex", "test_event_routes", "test_ui_consumers", "test_sfx_priority", "test_save_migration", "test_play_effects", "test_input_queue", "test_golden", "test_crowd_readability", "test_replay_tools", "test_counter_lib", "test_seek_clutch", "test_clutch_effects", "test_new_units", "test_roster_ui", "test_rules_v5", "test_sandbox_v5", "test_battle_code_v5", "test_rules_e2e_v5", "test_lobby_reopen_v5", "test_free_v6", "test_free_skip_v6", "test_review_free_v6", "test_to_free_keeps_units_v6", "test_free_review_fixes_v6", "test_save_v7", "test_harness_v7", "test_code_fuzz_v7", "test_keymap_v7", "test_replay_back_v7", "test_steam_v7"]
var SUITES := {}
var _objs := {}

func has_test(fn: String) -> bool:
	for g in FILES:
		if fn in FILES[g]:
			return load("res://tests/suites/%s.gd" % g).new().has_method(fn)
	return false

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
	var names: Array = ALL_TESTS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			var k := a.substr(7)
			if not SUITES.has(k):
				print("FAIL 未知的測試組：", k, "（可用：", ", ".join(SUITES.keys()), "）")
				print("—— 0 通過 / 1 失敗")
				quit(1)
				return
			names = SUITES[k]
	for fn in names:
		for g in FILES:
			if fn in FILES[g]:
				_obj(g).call(fn)
	var p := 0
	var f := 0
	for g2 in _objs:
		p += _objs[g2].passed
		f += _objs[g2].failed
	print("—— %d 通過 / %d 失敗（%d ms）" % [p, f, Time.get_ticks_msec() - t0])
	quit(exit_code(p, f))
