extends SceneTree
## V1.6.1 N5／B4：V1.6 新模式的難度與節奏指標（求解器／AI 代理，不是真人）。
##  --what=trio：每組三支敵陣對作者解、三星解：首波交戰 tick、局長；隨機合法陣三場全勝率（--n 個）。
##  --what=rift：未來 --weeks 週的異變組合：AI 對 AI（我方用同一套 AI 擺法）勝率、平均局長、時間到比例。
##  --what=rush：極速賽題庫：每題三星解的首波交戰與局長。
## 輸出一行一筆 JSON 到 --out。用法（game/ 下）：godot --headless --path . --script res://tools/balance/v161_metrics.gd -- --what=trio --out=res://m_trio.jsonl
const Trio = preload("res://scripts/game/trio.gd")
const Rift = preload("res://scripts/game/rift.gd")
const Rush = preload("res://scripts/game/rush.gd")
const PZ = preload("res://scripts/game/puzzles.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")

## 中位數：偶數個取中間兩個平均（Codex v110-i1）；空的回 -1
static func med(v: Array) -> float:
	if v.is_empty():
		return -1.0
	var n := v.size()
	return float(v[n / 2]) if n % 2 == 1 else (float(v[n / 2 - 1]) + float(v[n / 2])) / 2.0

func pace(a0, a1, rr) -> Dictionary:
	var s = Sim.new(a0.copy(), a1.copy(), rr)
	var first := -1
	while not s.finished:
		s.step()
		if first < 0:
			for e in s.events:
				if e.has("dmg"):
					first = s.tick
					break
	return {"first": first, "ticks": s.tick, "winner": s.winner, "reason": s.reason}

func pz_pace(pz: Dictionary, extra: Array) -> Dictionary:
	var a0 = PZ.player_army(pz)
	for e in extra:
		a0.units.append({"type": int(e[0]), "col": int(e[1]), "row": int(e[2])})
	return pace(a0, PZ.enemy_army(pz), PZ.rules_of(pz))

func rand_extra(s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var al: Array = s["allowed"]
	var pz := Trio.make_pz(s, 0)
	var a0 = PZ.player_army(pz)
	var out: Array = []
	for k in 40:
		var t := int(al[rng.randi_range(0, al.size() - 1)])
		var c := rng.randi_range(0, 5)
		var r := rng.randi_range(0, 8)
		if a0.check_place(t, c, r) == "":
			a0.place(t, c, r)
			out.append([t, c, r])
	return out

func _init() -> void:
	var what := "trio"
	var out_path := ""
	var n := 60
	var weeks := 26
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--what="): what = a.substr(7)
		elif a.begins_with("--out="): out_path = a.substr(6)
		elif a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--weeks="): weeks = int(a.substr(8))
	var lines: Array = []
	match what:
		"trio":
			for s in Trio.sets():
				var rec := {"id": s["id"], "sol": [], "sol3": []}
				for k in 3:
					rec["sol"].append(pz_pace(Trio.make_pz(s, k), s["sol"]))
					if s.has("sol3"):
						rec["sol3"].append(pz_pace(Trio.make_pz(s, k), s["sol3"]))
				var rng := RandomNumberGenerator.new()
				rng.seed = 4242
				var allw := 0
				var st_n := [0, 0, 0, 0]   # 1.1.0 B12：隨機合法陣拿到 0～3 星的個數
				var rems: Array = []
				var spents: Array = []
				for i in n:
					var ex := rand_extra(s, rng)
					var res := Trio.results(s, ex)
					var st := Trio.stars(s, res)
					st_n[st] += 1
					if st >= 1:
						allw += 1
						rems.append(Trio.rem_avg(res))
						spents.append(Trio.spent_pct(s, res))
				rec["rand_pct"] = allw * 100 / n
				rec["rand_stars"] = st_n
				rems.sort()
				spents.sort()
				rec["win_rem_med"] = med(rems)
				rec["win_spent_med"] = med(spents)
				rec["s2"] = Trio.s2_of(s)
				rec["s3"] = Trio.s3_of(s)
				lines.append(JSON.stringify(rec))
				print("M trio ", s["id"], " rand ", rec["rand_pct"])
		"rift":
			var wk0 := Rift.week()
			for w in weeks:
				var wk := wk0 + w
				var ps: Array = Rift.picks(wk, (1 << 20) - 1)
				var r = Rift.make_rules(ps, (1 << 20) - 1, wk)
				var e = Rift.enemy(r, wk)
				var wins := 0
				var tsum := 0
				var tout := 0
				var fsum := 0
				var rng := RandomNumberGenerator.new()
				rng.seed = wk * 31 + 7
				for i in n:
					var a0 = AI.build(0, r.budget_of(0), rng, -1, r.pool_of(0), r)["army"]
					var pc := pace(a0, e, r)
					wins += 1 if int(pc["winner"]) == 0 else 0
					tsum += int(pc["ticks"])
					fsum += maxi(0, int(pc["first"]))
					tout += 1 if str(pc["reason"]).contains("時間到") else 0
				var names: Array = []
				for k in ps:
					names.append(Rift.ANOMS[k][0])
				lines.append(JSON.stringify({"wk": wk, "anoms": names, "ai_win_pct": wins * 100 / n, "avg_ticks": tsum / n, "avg_first": fsum / n, "timeout_pct": tout * 100 / n}))
				print("M rift ", wk, " ", names, " win ", wins * 100 / n)
		"rush":
			for pid in Rush.pool(1):
				var pz := PZ.get_puzzle(pid)
				var best: Array = pz.get("best", {}).get("u", [])
				if best.is_empty() and not pz.get("solutions", []).is_empty():
					best = pz["solutions"][0]
				var pc := pz_pace(pz, best)
				lines.append(JSON.stringify({"id": pid, "first": pc["first"], "ticks": pc["ticks"]}))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
	print("METRICS done ", what, " ", lines.size())
	quit(0)
