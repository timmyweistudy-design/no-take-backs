extends SceneTree
## V1.4 #12：巨獸平衡試算。godot --headless --path game --script res://tools/balance/boss_probe.gd -- --hp=4 --atk=1 ...
## 改 boss_defs 的值只在這次執行有效（用 set 蓋 const 不行，所以這裡直接改模擬單位）。
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const GM = preload("res://scripts/ui/screens/game_modes.gd")

func _init() -> void:
	var foe_b := 130
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--foe="):
			foe_b = int(a.substr(6))
	var my_b := 135
	var wins := 0
	var arm := 0
	var plate := 0
	var n := 16
	var by := {}
	for k in n:
		var r := RandomNumberGenerator.new()
		r.seed = 777 + k
		var e = AI.build(1, foe_b, r)["army"]
		if not "--noboss" in OS.get_cmdline_user_args():
			GM.add_boss(e)
			if "--plain" in OS.get_cmdline_user_args():
				for u in e.units:
					u.erase("boss")
		var p = AI.build(0, my_b, r)["army"]
		var s = Sim.new(p, e)
		s.fast = true
		var bid := -1
		for u0 in s.units:
			if u0.boss:
				bid = u0.id
		while not s.finished:
			s.step()
			for ev in s.events:
				if int(ev.get("tgt", -2)) == bid and ev.has("dmg"):
					var su = s.unit_by_id(int(ev["src"]))
					var kk := "%d:%s" % [su.type if su != null else -1, str(ev["kind"])]
					by[kk] = int(by.get(kk, 0)) + int(ev["dmg"])
				if ev["kind"] == "boss_arm":
					arm += 1
				elif ev["kind"] == "boss_plate":
					plate += 1
		if s.winner == 0:
			wins += 1
		var bu = null
		for u in s.units:
			if u.boss:
				bu = u
		if bu != null and false: print("  #%d 勝方 %d tick %d 巨獸血 %d/%d 前臂 %d 背甲 %d 造成 %d" % [k, s.winner, s.tick, bu.hp, bu.max_hp, bu.arm_hp, bu.plate_hp, bu.dmg_dealt])
	print("BY ", by)
	print("PROBE 勝 %d/%d 前臂斷 %d 背甲碎 %d" % [wins, n, arm, plate])
	quit()
