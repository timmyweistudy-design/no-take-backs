extends RefCounted
## 戰鬥核心（純邏輯、全整數、確定性）。企劃 §2.3、§2.4、§3.3。
## 每 tick 固定五步：①讀快照 ②選目標＋提出移動 ③統一解碰撞 ④產生攻擊 ⑤同時結算。
## 任何一步都只讀「這一步開始前」的狀態，所以不會因為誰先算就佔便宜。

const D = preload("res://scripts/core/unit_defs.gd")
const M = preload("res://scripts/core/imath.gd")

const TPS := 20
const MAX_TICKS := 1800          # 90 秒
const FRENZY_TICK := 1200        # 60 秒起狂熱
const CELL := 1000
const COLS := 16
const ROWS := 9
const W := COLS * CELL
const H := ROWS * CELL
const MIN_SEP := 450             # 最小碰撞間距 0.45 格
const EDGE := 200
const HASH_MOD := 1099511627689  # < 2^40，乘上 1000003 不會溢位

class Unit:
	var id: int
	var team: int
	var type: int
	var x: int
	var y: int
	var hp: int
	var max_hp: int
	var cost: int
	var cd := 0                # 子刻度（×4）；平常每 tick 扣 4，狂熱扣 5
	var target := -1           # 目標的索引
	var fx := 0                # 面向（長度約 1000）
	var fy := 0
	var mx := 0                # 這一 tick 提出的移動
	var my := 0
	var lmx := 0               # 上一次實際移動（判斷騎兵是否直行）
	var lmy := 0
	var stealth := 0
	var charge := 0
	var stun := 0
	var slow := 0
	var wp_x := -1             # 騎兵繞翼途經點
	var wp_y := -1
	var wp_for := -1
	var alive := true
	var dmg_dealt := 0
	var kills := 0

var units: Array = []          # 依 id 排序
var tick := 0
var budget := 100
var finished := false
var winner := -2               # -2 進行中；-1 平手；0／1 勝方
var reason := ""
var fingerprint := 0
var events: Array = []         # 這一 tick 的事件（給畫面演出用，不影響計算）
var frenzy := false

func _init(army0, army1) -> void:
	budget = army0.budget
	var raw: Array = []
	for a in [army0, army1]:
		for u in a.units:
			raw.append([a.team * 1000 + u["row"] * COLS + u["col"], a.team, u])
	raw.sort_custom(func(p, q): return p[0] < q[0])
	for r in raw:
		var u = r[2]
		var s = D.STATS[u["type"]]
		var n := Unit.new()
		n.id = r[0]
		n.team = r[1]
		n.type = u["type"]
		n.x = u["col"] * CELL + CELL / 2
		n.y = u["row"] * CELL + CELL / 2
		n.hp = s["hp"]
		n.max_hp = s["hp"]
		n.cost = s["cost"]
		n.fx = 1000 if n.team == 0 else -1000
		if n.type == D.ASSASSIN:
			n.stealth = D.STEALTH_TICKS
		units.append(n)
	if alive_count(0) == 0 or alive_count(1) == 0:
		finished = true
		winner = -1
		reason = "有一方沒有兵"

func alive_count(team: int) -> int:
	var c := 0
	for u in units:
		if u.alive and u.team == team:
			c += 1
	return c

## 剩餘戰力＝Σ⌊兵價×剩血×1000÷滿血⌋（企劃 §2.4）。
func power(team: int) -> int:
	var p := 0
	for u in units:
		if u.alive and u.team == team:
			p += u.cost * u.hp * 1000 / u.max_hp
	return p

func run_to_end() -> void:
	while not finished:
		step()

# ───────────────────────── 一個 tick ─────────────────────────
func step() -> void:
	if finished:
		return
	tick += 1
	frenzy = tick >= FRENZY_TICK
	events = []
	var n := units.size()

	# ② 選目標＋提出移動（只讀舊位置）
	var nx := PackedInt64Array()
	var ny := PackedInt64Array()
	nx.resize(n)
	ny.resize(n)
	var new_target := PackedInt64Array()
	new_target.resize(n)
	var new_fx := PackedInt64Array()
	var new_fy := PackedInt64Array()
	new_fx.resize(n)
	new_fy.resize(n)
	for i in n:
		var u: Unit = units[i]
		nx[i] = u.x
		ny[i] = u.y
		new_target[i] = u.target
		new_fx[i] = u.fx
		new_fy[i] = u.fy
		if not u.alive:
			continue
		var t := _choose_target(i)
		new_target[i] = t
		u.mx = 0
		u.my = 0
		if t == -1 or u.stun > 0:
			continue
		var tg: Unit = units[t]
		var reach: int = D.STATS[u.type]["reach"]
		var d2 := M.dist2(u.x, u.y, tg.x, tg.y)
		var dest := Vector2i(tg.x, tg.y)
		var stop_at := reach - 50
		if u.type == D.ASSASSIN and u.stealth > 0:
			# 潛行中繞到目標背後
			dest = Vector2i(tg.x - tg.fx * 6 / 10, tg.y - tg.fy * 6 / 10)
			stop_at = 0
		elif u.type == D.CAVALRY:
			var wp := _flank_waypoint(i, t)
			if wp.x >= 0:
				dest = wp
				stop_at = 0
		var need_move := d2 > reach * reach or (u.type == D.ASSASSIN and u.stealth > 0)
		if need_move:
			var dx := dest.x - u.x
			var dy := dest.y - u.y
			var l := M.isqrt(dx * dx + dy * dy)
			var spd: int = D.STATS[u.type]["speed"]
			if u.slow > 0:
				spd /= 2
			var stp := mini(spd, l - stop_at)
			if stp > 0 and l > 0:
				u.mx = dx * stp / l
				u.my = dy * stp / l
				nx[i] = u.x + u.mx
				ny[i] = u.y + u.my
		# 面向：交戰中鎖定朝目標；否則朝移動方向（企劃 §3.3）
		var face: Vector2i
		if d2 <= (reach + CELL) * (reach + CELL):
			face = M.unit1000(tg.x - u.x, tg.y - u.y)
		else:
			face = M.unit1000(u.mx, u.my)
		if face != Vector2i.ZERO:
			new_fx[i] = face.x
			new_fy[i] = face.y

	# ③ 統一解碰撞（固定兩輪，所有推力加總後一次套用）
	for _pass in 2:
		var px := PackedInt64Array()
		var py := PackedInt64Array()
		px.resize(n)
		py.resize(n)
		for i in n:
			var a: Unit = units[i]
			if not a.alive or a.stealth > 0:
				continue
			for j in range(i + 1, n):
				var b: Unit = units[j]
				if not b.alive or b.stealth > 0:
					continue
				var dx := nx[j] - nx[i]
				var dy := ny[j] - ny[i]
				if absi(dx) >= MIN_SEP or absi(dy) >= MIN_SEP:
					continue
				var d2 := dx * dx + dy * dy
				if d2 >= MIN_SEP * MIN_SEP:
					continue
				var d := M.isqrt(d2)
				var ux := 0
				var uy := 0
				if d == 0:
					# 零距離：不同隊左右分開（藍往左、紅往右）；同隊依編號上下分開
					if a.team != b.team:
						ux = 1000 if a.team == 0 else -1000
					else:
						uy = 1000
				else:
					ux = dx * 1000 / d
					uy = dy * 1000 / d
				var half := (MIN_SEP - d) / 2 + 1
				px[i] -= ux * half / 1000
				py[i] -= uy * half / 1000
				px[j] += ux * half / 1000
				py[j] += uy * half / 1000
		for i in n:
			nx[i] = clampi(nx[i] + px[i], EDGE, W - EDGE)
			ny[i] = clampi(ny[i] + py[i], EDGE, H - EDGE)

	# 套用移動、目標、面向
	for i in n:
		var u: Unit = units[i]
		if not u.alive:
			continue
		var moved_x: int = nx[i] - u.x
		var moved_y: int = ny[i] - u.y
		if u.type == D.CAVALRY:
			var ml := M.isqrt(moved_x * moved_x + moved_y * moved_y)
			if ml > 0:
				if _same_dir(u.lmx, u.lmy, moved_x, moved_y):
					u.charge += ml
				else:
					u.charge = ml
				u.lmx = moved_x
				u.lmy = moved_y
		u.x = nx[i]
		u.y = ny[i]
		u.target = new_target[i]
		u.fx = new_fx[i]
		u.fy = new_fy[i]

	# ④ 產生攻擊（讀這一 tick 已確定的位置與面向）
	var hits: Array = []   # [來源, 目標, 傷害, 種類]
	var stun_set := {}
	var slow_set := {}
	var reveal := {}
	var knock: Array = []
	var countered := {}
	var dec := 5 if frenzy else 4
	for i in n:
		var u: Unit = units[i]
		if not u.alive:
			continue
		if u.cd > 0:
			u.cd = maxi(0, u.cd - dec)
		if u.stun > 0 or u.target == -1 or u.cd > 0:
			continue
		var tg: Unit = units[u.target]
		var reach: int = D.STATS[u.type]["reach"]
		if M.dist2(u.x, u.y, tg.x, tg.y) > reach * reach:
			continue
		if u.type == D.ASSASSIN and u.stealth > 0 and not _is_behind(u, tg):
			continue
		var dmg: int = D.STATS[u.type]["atk"]
		var kind := "hit"
		if u.type == D.SWORD:
			if tg.type == D.SHIELD:
				dmg = dmg * 3 / 2
				kind = "breaker"
		elif u.type == D.ARCHER:
			kind = "arrow"
			if tg.type == D.SHIELD and not _is_behind(u, tg):
				dmg = dmg / 4
				kind = "blocked"
		elif u.type == D.CAVALRY:
			if u.charge >= D.CHARGE_NEED:
				if tg.type == D.SHIELD and not _is_behind(u, tg):
					stun_set[i] = true
					kind = "braced"
				else:
					dmg = dmg * 5 / 2
					kind = "charge"
					knock.append([u.target, tg.x - u.x, tg.y - u.y])
				u.charge = 0
		elif u.type == D.ASSASSIN:
			if _is_behind(u, tg):
				dmg *= 2
				kind = "backstab"
			if tg.type == D.CAVALRY:
				slow_set[u.target] = true
			reveal[i] = true
		hits.append([i, u.target, dmg, kind])
		u.cd += D.STATS[u.type]["cd"] * 4
		# 劍士反擊：被刺客打到立刻回砍，每 tick 最多一次，反擊不會再觸發反擊
		if u.type == D.ASSASSIN and tg.type == D.SWORD and not countered.has(u.target):
			countered[u.target] = true
			hits.append([u.target, i, D.STATS[D.SWORD]["atk"], "counter"])

	# ⑤ 同時結算
	var dmg_in := PackedInt64Array()
	dmg_in.resize(n)
	var last_hit := PackedInt64Array()
	last_hit.resize(n)
	last_hit.fill(-1)
	for h in hits:
		dmg_in[h[1]] += h[2]
		units[h[0]].dmg_dealt += h[2]
		if last_hit[h[1]] == -1:
			last_hit[h[1]] = h[0]
		events.append({"src": units[h[0]].id, "tgt": units[h[1]].id, "dmg": h[2], "kind": h[3]})
	# 狂熱耗損：第 1200+100k tick 扣 (k+1)×2% 滿血（至少 1）
	if tick >= FRENZY_TICK and (tick - FRENZY_TICK) % 100 == 0 and (tick - FRENZY_TICK) / 100 <= 5:
		var k := (tick - FRENZY_TICK) / 100
		for i in n:
			if units[i].alive:
				dmg_in[i] += maxi(1, units[i].max_hp * (k + 1) * 2 / 100)
		events.append({"kind": "attrition", "k": k})
	for kb in knock:
		var v := M.unit1000(kb[1], kb[2])
		var t: Unit = units[kb[0]]
		t.x = clampi(t.x + v.x * D.KNOCKBACK / 1000, EDGE, W - EDGE)
		t.y = clampi(t.y + v.y * D.KNOCKBACK / 1000, EDGE, H - EDGE)
	for i in n:
		var u: Unit = units[i]
		if not u.alive:
			continue
		u.hp -= dmg_in[i]
		if u.stun > 0:
			u.stun -= 1
		if u.slow > 0:
			u.slow -= 1
		if u.stealth > 0:
			u.stealth -= 1
		if reveal.has(i):
			u.stealth = 0
		if stun_set.has(i):
			u.stun = D.STUN_TICKS
			u.charge = 0
		if slow_set.has(i):
			u.slow = D.SLOW_TICKS
	for i in n:
		var u: Unit = units[i]
		if u.alive and u.hp <= 0:
			u.alive = false
			u.hp = 0
			if last_hit[i] != -1:
				units[last_hit[i]].kills += 1
			events.append({"kind": "death", "id": u.id})

	_update_fingerprint()
	_check_end()

# ───────────────────────── 規則細節 ─────────────────────────

## 選目標（企劃 §3.3）：排除潛行 → 弓手警覺 → 盾兵嘲諷（近戰）→ 兵種偏好 → 距離 → 剩血 → 編號。
func _choose_target(i: int) -> int:
	var u: Unit = units[i]
	var reach: int = D.STATS[u.type]["reach"]
	var best := -1
	var bk := [99, 0, 0, 0, 0, 0]
	for j in units.size():
		var e: Unit = units[j]
		if e.team == u.team or not e.alive or e.stealth > 0:
			continue
		var d2 := M.dist2(u.x, u.y, e.x, e.y)
		var rank := 3
		if u.type == D.ARCHER and e.type == D.ASSASSIN and d2 <= reach * reach:
			rank = 0
		elif D.is_melee(u.type) and e.type == D.SHIELD and d2 <= D.TAUNT_RANGE * D.TAUNT_RANGE:
			rank = 1
		elif u.type == D.CAVALRY and e.type == D.ARCHER:
			rank = 2
		elif u.type == D.ASSASSIN and (e.type == D.SHIELD or e.type == D.CAVALRY):
			rank = 2
		var depth: int = e.x if e.team == 0 else W - e.x
		var key := [rank, d2, e.hp, e.y, depth, e.id]
		if best == -1 or _key_less(key, bk):
			best = j
			bk = key
	return best

func _key_less(a: Array, b: Array) -> bool:
	for k in a.size():
		if a[k] != b[k]:
			return a[k] < b[k]
	return false

## 攻擊者是否在目標背後（以目標面向的內積判斷；剛好側面算正面）。
func _is_behind(att: Unit, tg: Unit) -> bool:
	var dx := att.x - tg.x
	var dy := att.y - tg.y
	return dx * tg.fx + dy * tg.fy < 0

func _same_dir(ax: int, ay: int, bx: int, by: int) -> bool:
	# 夾角小於約 25 度
	var dot := ax * bx + ay * by
	if dot <= 0:
		return false
	var la := ax * ax + ay * ay
	var lb := bx * bx + by * by
	return dot * dot * 100 >= la * lb * 82

## 騎兵繞翼：目標是弓手、直線上 1.5 格內有盾兵時，往敵兵較少的那側偏 2 格走途經點。
func _flank_waypoint(i: int, t: int) -> Vector2i:
	var u: Unit = units[i]
	var tg: Unit = units[t]
	if tg.type != D.ARCHER:
		u.wp_for = -1
		return Vector2i(-1, -1)
	if u.wp_for == tg.id:
		if M.dist2(u.x, u.y, u.wp_x, u.wp_y) > 400 * 400:
			return Vector2i(u.wp_x, u.wp_y)
		return Vector2i(-1, -1)   # 已經到過途經點，直衝
	var dx := tg.x - u.x
	var dy := tg.y - u.y
	var l2 := dx * dx + dy * dy
	if l2 == 0:
		return Vector2i(-1, -1)
	var blocked := false
	var above := 0
	var below := 0
	for e in units:
		if e.team == u.team or not e.alive:
			continue
		if e.y < u.y:
			above += 1
		elif e.y > u.y:
			below += 1
		if e.type != D.SHIELD or e.stealth > 0:
			continue
		var ex: int = e.x - u.x
		var ey: int = e.y - u.y
		var proj: int = ex * dx + ey * dy
		if proj <= 0 or proj >= l2:
			continue
		var cross: int = ex * dy - ey * dx
		if cross * cross < 1500 * 1500 * l2:
			blocked = true
	if not blocked:
		return Vector2i(-1, -1)
	var wy: int
	if above <= below:
		wy = mini(u.y, tg.y) - 2 * CELL
	else:
		wy = maxi(u.y, tg.y) + 2 * CELL
	u.wp_for = tg.id
	u.wp_x = u.x + (tg.x - u.x) / 2   # 用差值往 0 截斷，左右鏡像才對稱
	u.wp_y = clampi(wy, EDGE, H - EDGE)
	return Vector2i(u.wp_x, u.wp_y)

func _update_fingerprint() -> void:
	var h := fingerprint
	for u in units:
		var v: int = u.x * 7 + u.y * 13 + u.hp * 17 + u.fx * 3 + u.fy * 5 + u.target * 11 + u.cd + u.stealth * 19 + u.charge \
				+ u.stun * 23 + u.slow * 29 + u.wp_x * 31 + u.wp_y * 37 + u.lmx * 41 + u.lmy * 43 + (1 if u.alive else 0)
		h = posmod(h * 1000003 + v, HASH_MOD)
	fingerprint = h

func _check_end() -> void:
	var a0 := alive_count(0)
	var a1 := alive_count(1)
	if a0 == 0 and a1 == 0:
		_finish(-1, "同時全滅")
	elif a1 == 0:
		_finish(0, "全滅")
	elif a0 == 0:
		_finish(1, "全滅")
	elif tick >= MAX_TICKS:
		var p0 := power(0)
		var p1 := power(1)
		if absi(p0 - p1) < budget * 30:
			_finish(-1, "時間到・戰力相當")
		elif p0 > p1:
			_finish(0, "時間到・剩餘戰力較高")
		else:
			_finish(1, "時間到・剩餘戰力較高")

func _finish(w: int, r: String) -> void:
	finished = true
	winner = w
	reason = r

func unit_by_id(id: int) -> Unit:
	for u in units:
		if u.id == id:
			return u
	return null
