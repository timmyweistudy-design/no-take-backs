extends SceneTree
## 新兵種驗收工具（第四輪方案 §2.6、§3.4）。由 tools/balance/unit_eval.sh 分片執行，tools/balance/unit_eval_report.py 合併判定。
## 模式：
##   core  —— 核心剋制關係逐條驗：「X 為主＋同樣的劍弓填充」對「Y 為主＋同樣填充」，40 種排法 × 交換左右
##   repl  —— 替換實驗：含 X 的 200 套陣型，整批拿掉 X、用三種固定補法補回，對同一批對手（驗證池）比勝率差 Δ
##   cover —— 支援兵覆蓋曲線：沒有支援兵的陣型，從後排拿掉戰鬥兵換成 k 隻支援兵（k＝0～4），看勝率變化
## 每一列都帶 digest、ntypes、模式與鍵，報表會核對筆數與鍵集合（第三輪學到：資料可能被改名騙過）。
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const F = preload("res://scripts/core/formations.gd")

## 核心關係（§2.6 預先指定，不能事後改表過關）：[X, Y, 說明]
const CORE := [
	[D.PIKE, D.CAVALRY, "長槍兵 > 騎兵"],
	[D.BOMBER, D.SHIELD, "投彈兵 > 盾兵牆"],
	[D.CAVALRY, D.BOMBER, "騎兵 > 投彈兵"],
	[D.ARCHER, D.BOMBER, "弓箭手 > 投彈兵"],
	[D.ASSASSIN, D.MEDIC, "刺客 > 醫者"],
	[D.ARCHER, D.BERSERKER, "弓箭手 > 狂戰士"],
]
const CORE_SEEDS := 40
const REPL_N := 200
const REPL_OPPS := 6
const COVER_N := 120
const COVER_OPPS := 4

var args := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var shard := int(args.get("shard", "0"))
	var shards := int(args.get("shards", "1"))
	var nt := int(args.get("ntypes", str(D.COUNT)))
	if args.has("free"):
		# 第六輪：自由部署驗收（--free=間距,縱深）：每套陣型照規則用「拉開」轉成自由座標，模擬傳規則
		var fv := str(args["free"]).split(",")
		FREE_R = load("res://scripts/core/ruleset.gd").standard()
		FREE_R.deploy = "free"
		FREE_R.spacing = int(fv[0])
		FREE_R.depth = int(fv[1])
	match args.get("mode", "core"):
		"core": core(shard, shards)
		"repl": repl(int(args.get("unit", "5")), nt, shard, shards)
		"replshield": repl(int(args.get("unit", "9")), nt, shard, shards, true)
		"cover": cover(int(args.get("unit", "7")), nt, shard, shards)
		"contract":
			# 實驗契約（Codex 實作審查第 2 輪 #7）：規則、數值摘要、兩個對手池的身分；報表逐列核對
			print("CONTRACT ", JSON.stringify({"rules": D.RULES_VERSION, "digest": D.data_digest(), "ntypes": nt, "code": code_hash(), "free": str(args.get("free", "")),
				"pool_val": pool_hash(F.validation_pool(0, nt)), "pool_shield": pool_hash(shield_pool(200))}))
	quit(0)

var pool_id := ""

## 對手池的身分：池內全部陣型代碼的 SHA-256 前 12 碼（每列都帶，報表核對同一模式只有一個池；Codex 實作審查 #7）
static func pool_hash(opps: Array) -> String:
	var parts := PackedStringArray()
	for a in opps:
		parts.append(a.to_code())
	return ",".join(parts).sha256_text().substr(0, 12)

## 程式身分（Codex 第 3 輪 #2）：模擬、數值、陣型產生器、AI、本工具的原始碼 SHA-256 前 12 碼；每列都帶，報表核對和契約相同。
static func code_hash() -> String:
	var txt := ""
	for p in ["res://scripts/core/battle_sim.gd", "res://scripts/core/unit_defs.gd", "res://scripts/core/formations.gd", "res://scripts/core/army.gd",
			"res://scripts/core/ai_army.gd", "res://scripts/core/imath.gd", "res://tools/balance/unit_eval.gd"]:
		txt += FileAccess.get_file_as_string(p)
	return txt.sha256_text().substr(0, 12)

static var _code := ""

func emit(d: Dictionary) -> void:
	if _code == "":
		_code = code_hash()
	d["digest"] = D.data_digest()
	d["rules"] = D.RULES_VERSION
	d["src"] = _code
	if FREE_R != null:
		d["free"] = "%d,%d" % [FREE_R.spacing, FREE_R.depth]
	if pool_id != "":
		d["pool"] = pool_id
	print("R ", JSON.stringify(d))

## a 是藍方表示的陣型（team 0）、b 也是；交換左右各打一場。回傳 a 的得分列表 [第一場, 第二場]（1／0.5／0）。
static var FREE_R = null

## 自由部署時把格子陣型轉成自由座標（替換實驗換上的兵在同一個座標：先換兵、再轉座標）。
static func fz(a: Army) -> Army:
	return a if FREE_R == null else F.to_free(a, FREE_R, null, "stretch")

static func duel2(a: Army, b: Army) -> Array:
	a = fz(a)
	b = fz(b)
	var s1 = Sim.new(a.copy(), b.mirrored(), FREE_R)
	s1.fast = true
	s1.run_to_end()
	var s2 = Sim.new(b.copy(), a.mirrored(), FREE_R)
	s2.fast = true
	s2.run_to_end()
	return [1.0 if s1.winner == 0 else (0.5 if s1.winner < 0 else 0.0), 1.0 if s2.winner == 1 else (0.5 if s2.winner < 0 else 0.0)]

func core(shard: int, shards: int) -> void:
	var idx := 0
	for ri in CORE.size():
		for sd in CORE_SEEDS:
			idx += 1
			if idx % shards != shard:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = 90001 + ri * 1013 + sd * 7919
			var wx := D.zeros()
			wx[CORE[ri][0]] = 3
			wx[D.SWORD] += 1
			wx[D.ARCHER] += 1
			var wy := D.zeros()
			wy[CORE[ri][1]] = 3
			wy[D.SWORD] += 1
			wy[D.ARCHER] += 1
			var style: String = F.STYLES[sd % F.STYLES.size()]
			var ax := F.weighted_formation(0, rng, wx, style)
			var ay := F.weighted_formation(0, rng, wy, style)
			var sc := duel2(ax, ay)
			emit({"mode": "core", "r": ri, "seed": sd, "s0": sc[0], "s1": sc[1]})

## 含 X 的陣型：從 ntypes 範圍的混編裡產生，X 的權重至少 2；第 i 套固定種子。
static func with_unit(x: int, nt: int, i: int) -> Army:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242 + x * 100003 + i * 7919
	for tries in 50:
		var w := D.zeros()
		for t in nt:
			w[t] = rng.randi_range(0, 3)
		w[x] = maxi(2, w[x])
		if D.is_support(x):
			# 支援兵（醫者、鼓手）不疊加、AI 一種最多帶 2 隻：只取帶 1～2 隻的陣型（第四輪驗收時修正，見報告）
			w[x] = 1
		var a := F.weighted_formation(0, rng, w)
		if a.count_of(x) > 0 and (not D.is_support(x) or a.count_of(x) <= 2):
			return a
	return null

## 整批拿掉 X，空出的錢與格子用 fill 兵種補回：先補原本 X 的格子（前排→後排、中間→兩邊），再補其他空格；錢不夠就留著。
static func refill(a: Army, x: int, fill: int) -> Army:
	var b := Army.new(0, 100)
	var holes: Array = []
	for u in a.units:
		if u["type"] == x:
			holes.append(Vector2i(u["col"], u["row"]))
		else:
			b.units.append(u.duplicate())
	holes.sort_custom(func(p, q): return p.x > q.x or (p.x == q.x and absi(p.y - 4) < absi(q.y - 4)) or (p.x == q.x and absi(p.y - 4) == absi(q.y - 4) and p.y < q.y))
	for h in holes:
		b.place(fill, h.x, h.y)
	for c in [5, 4, 3, 2, 1, 0]:
		for r in [4, 3, 5, 2, 6, 1, 7, 0, 8]:
			if b.left() < D.cost(fill):
				return b
			b.place(fill, c, r)
	return b

## 補法 a：這套陣型裡（拿掉 X 後）金額最多的舊兵種；同額取編號小的；沒有就劍士。
static func most_common_other(a: Army, x: int) -> int:
	var comp := F.composition(a)
	var best := -1
	for t in D.CLASSIC:
		if t != x and comp[t] > 0 and (best == -1 or comp[t] > comp[best]):
			best = t
	return best if best >= 0 else D.SWORD

## 盾兵為主的對手池（狂戰士的混編驗收用，§2.4）：盾兵權重 4，其他經典兵種 0～2。
static func shield_pool(n: int) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	for i in n:
		rng.seed = 616161 + i * 7919
		var w := D.zeros()
		for t in D.CLASSIC:
			w[t] = rng.randi_range(0, 2)
		w[D.SHIELD] = 4
		out.append(F.weighted_formation(0, rng, w))
	return out

func repl(x: int, nt: int, shard: int, shards: int, vs_shield := false) -> void:
	var opps := shield_pool(200) if vs_shield else F.validation_pool(0, nt)
	pool_id = pool_hash(opps)
	var mname := "replshield" if vs_shield else "repl"
	var idx := 0
	for i in REPL_N:
		idx += 1
		if idx % shards != shard:
			continue
		var orig := with_unit(x, nt, i)
		if orig == null:
			emit({"mode": mname, "unit": x, "i": i, "skip": "no_unit", "nt": nt})
			continue
		var variants := {"orig": orig, "a": refill(orig, x, most_common_other(orig, x)), "b": refill(orig, x, D.SWORD), "c": refill(orig, x, D.ARCHER)}
		for k in REPL_OPPS:
			var opp: Army = opps[(i * 7 + k * 31) % opps.size()]
			for pol in ["orig", "a", "b", "c"]:
				var sc := duel2(variants[pol], opp)
				emit({"mode": mname, "unit": x, "i": i, "k": k, "opp": (i * 7 + k * 31) % opps.size(), "pol": pol, "s0": sc[0], "s1": sc[1],
					"left": variants[pol].left(), "n": variants[pol].count(), "nt": nt, "code": variants[pol].to_code() if k == 0 else ""})

## 和 duel2 一樣，另外回傳支援兵的實際覆蓋（Codex 第 2 輪 #9）：
## 鼓手＝每隻鼓手平均每 tick 鼓舞到幾隻友軍（drum_cover ÷ 存活 tick）；醫者＝開戰時每隻醫者 3 格內有幾隻戰鬥兵友軍。兩場取平均。
static func duel2_cover(a: Army, b: Army, sup: int) -> Array:
	var covs: Array = []
	var res: Array = []
	for side in 2:
		var fa := fz(a)
		var fb := fz(b)
		var s = Sim.new(fa.copy(), fb.mirrored(), FREE_R) if side == 0 else Sim.new(fb.copy(), fa.mirrored(), FREE_R)
		s.fast = true
		var me := 0 if side == 0 else 1
		var start := 0.0
		var nsup := 0
		for u in s.units:
			if u.team == me and u.type == sup:
				nsup += 1
				if sup == D.MEDIC:
					for o in s.units:
						if o.team == me and not D.is_support(o.type) and (o.x - u.x) * (o.x - u.x) + (o.y - u.y) * (o.y - u.y) <= D.HEAL_RANGE * D.HEAL_RANGE:
							start += 1.0
		s.run_to_end()
		var cv := 0.0
		if nsup > 0:
			if sup == D.DRUMMER:
				var tot := 0
				for u in s.units:
					if u.team == me and u.type == sup:
						tot += u.drum_cover
				cv = float(tot) / float(nsup * maxi(1, s.tick))
			else:
				cv = start / nsup
		covs.append(cv)
		res.append((1.0 if s.winner == me else (0.5 if s.winner < 0 else 0.0)))
	return [res[0], res[1], snappedf((covs[0] + covs[1]) / 2.0, 0.01)]

## 從後排（離自己底線近）、兩邊往中間拿掉戰鬥兵，直到空出 need 金；再把 k 隻支援兵照角色欄位擺上。
static func with_supports(base: Army, sup: int, k: int) -> Army:
	var b: Army = base.copy()
	var need := k * D.cost(sup)
	var order := b.units.duplicate()
	order.sort_custom(func(p, q): return p["col"] < q["col"] or (p["col"] == q["col"] and absi(p["row"] - 4) > absi(q["row"] - 4)) or (p["col"] == q["col"] and absi(p["row"] - 4) == absi(q["row"] - 4) and p["row"] < q["row"]))
	for u in order:
		if b.left() >= need:
			break
		b.remove_at(u["col"], u["row"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for j in k:
		F.place_styled(b, sup, "role", rng)
	return b

func cover(sup: int, nt: int, shard: int, shards: int) -> void:
	var opps := F.validation_pool(0, nt)
	pool_id = pool_hash(opps)
	var idx := 0
	for i in COVER_N:
		idx += 1
		if idx % shards != shard:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 515151 + sup * 100003 + i * 7919
		var w := D.zeros()
		for t in nt:
			if not D.is_support(t):
				w[t] = rng.randi_range(0, 3)
		if w.max() == 0:
			w[D.SWORD] = 1
		var base := F.weighted_formation(0, rng, w)
		for kk in 5:
			var v := with_supports(base, sup, kk)
			for k in COVER_OPPS:
				var opp: Army = opps[(i * 11 + k * 37) % opps.size()]
				var sc := duel2_cover(v, opp, sup)
				emit({"mode": "cover", "unit": sup, "i": i, "kk": kk, "k": k, "opp": (i * 11 + k * 37) % opps.size(), "s0": sc[0], "s1": sc[1], "have": v.count_of(sup), "nt": nt,
					"cov": sc[2]})
