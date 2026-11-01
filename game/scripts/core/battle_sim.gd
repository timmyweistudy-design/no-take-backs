extends RefCounted
## 戰鬥核心（純邏輯、全整數、確定性）。企劃 §2.3、§2.4、§3.3；優化方案 B1、L1。
## 每 tick 固定五步：①讀快照 ②選目標＋提出移動 ③統一解碰撞 ④產生攻擊 ⑤同時結算。
## 任何一步都只讀「這一步開始前」的狀態，所以不會因為誰先算就佔便宜。
## 禁止新增浮點運算（imath.isqrt 內的浮點估計之後一定用整數修正）。
## 指紋＝每 tick 完整狀態（固定欄位、int64 小端序）串接後的 SHA-256。

const D = preload("res://scripts/core/unit_defs.gd")
const M = preload("res://scripts/core/imath.gd")

const TPS := 20
const MAX_TICKS := D.MATCH_TICKS
const FRENZY_TICK := D.FRENZY_TICK
const CELL := 1000
const COLS := 16
const ROWS := 9
const W := COLS * CELL
const H := ROWS * CELL
const MIN_SEP := D.MIN_SEP
const EDGE := 200

class Unit:
	var id: int
	var team: int
	var type: int
	var x: int
	var y: int
	var hp: int
	var max_hp: int
	var cost: int
	var reach: int
	var speed: int
	var atk: int
	var cd_base: int
	var cd := 0                # 子刻度（×4）；平常每 tick 扣 4，狂熱扣 FRENZY_CD_RATE
	var target := -1           # 目標的索引
	var fx := 0                # 面向（長度約 1000）
	var fy := 0
	var face_lock := -1        # 面向鎖定中的目標索引（交戰中只在換目標時重算面向）
	var mx := 0                # 這一 tick 提出的移動
	var my := 0
	var cdx := 0               # 騎兵這段衝鋒的起始方向
	var cdy := 0
	var stealth := 0
	var charge := 0
	var stun := 0
	var slow := 0
	var wp_x := -1             # 騎兵繞翼途經點
	var wp_y := -1
	var wp_for := -1
	var alive := true
	var dmg_dealt := 0
	var dmg_taken := 0
	var kills := 0

var units: Array[Unit] = []    # 依 id 排序
var tick := 0
var budget := 100
var finished := false
var winner := -2               # -2 進行中；-1 平手；0／1 勝方
var reason := ""
var fingerprint := ""          # 結束時的 SHA-256（十六進位）
var events: Array = []         # 這一 tick 的事件（給畫面演出用，不影響計算）
var frenzy := false
var rally := [false, false]    # 這一 tick 哪一隊在「背水」（畫面提示用；計算用的是第④步當下的值）
var power_log: PackedInt64Array = PackedInt64Array()   # 每 tick 的（藍戰力−紅戰力），懸念指標用
var _hash := HashingContext.new()
var fast := false              # 平衡工具用：不算每 tick 指紋（結果完全一樣，只是沒有指紋）

func _init(army0, army1) -> void:
	budget = army0.budget
	_hash.start(HashingContext.HASH_SHA256)
	var raw: Array = []
	for a in [army0, army1]:
		for u in a.units:
			raw.append([a.team * 1000 + u["row"] * COLS + u["col"], a.team, u])
	raw.sort_custom(func(p, q): return p[0] < q[0])
	for r in raw:
		var u = r[2]
		var s: Dictionary = D.STATS[u["type"]]
		var n := Unit.new()
		n.id = r[0]
		n.team = r[1]
		n.type = u["type"]
		n.x = u["col"] * CELL + CELL / 2
		n.y = u["row"] * CELL + CELL / 2
		n.hp = s["hp"]
		n.max_hp = s["hp"]
		n.cost = s["cost"]
		n.reach = s["reach"]
		n.speed = s["speed"]
		n.atk = s["atk"]
		n.cd_base = s["cd"]
		n.fx = 1000 if n.team == 0 else -1000
		if n.type == D.ASSASSIN:
			n.stealth = D.STEALTH_TICKS
		units.append(n)
	var hdr := PackedInt64Array([D.RULES_VERSION_INT, budget, units.size()])
	_hash.update(hdr.to_byte_array())
	_hash.update(D.data_digest().to_utf8_buffer())
	if alive_count(0) == 0 or alive_count(1) == 0:
		_finish(-1, "有一方沒有兵")

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

	# ① 快照（之後的選目標、碰撞都只讀這些陣列）
	var sx := PackedInt64Array()
	var sy := PackedInt64Array()
	var st := PackedInt64Array()     # 隊伍
	var sk := PackedInt64Array()     # 兵種
	var sh := PackedInt64Array()     # 血
	var sv := PackedByteArray()      # 可被選為目標（活著且沒潛行）
	sx.resize(n); sy.resize(n); st.resize(n); sk.resize(n); sh.resize(n); sv.resize(n)
	for i in n:
		var u := units[i]
		sx[i] = u.x
		sy[i] = u.y
		st[i] = u.team
		sk[i] = u.type
		sh[i] = u.hp
		sv[i] = 1 if (u.alive and u.stealth == 0) else 0

	# ② 選目標＋提出移動
	var nx := sx.duplicate()
	var ny := sy.duplicate()
	var new_target := PackedInt64Array()
	var new_fx := PackedInt64Array()
	var new_fy := PackedInt64Array()
	var new_lock := PackedInt64Array()
	new_target.resize(n); new_fx.resize(n); new_fy.resize(n); new_lock.resize(n)
	for i in n:
		var u := units[i]
		new_target[i] = u.target
		new_fx[i] = u.fx
		new_fy[i] = u.fy
		new_lock[i] = -1
		u.mx = 0
		u.my = 0
		if not u.alive:
			continue
		var t := _choose_target(i, sx, sy, st, sk, sh, sv)
		new_target[i] = t
		if t == -1 or u.stun > 0:
			continue
		var tg := units[t]
		var reach := u.reach
		var d2 := M.dist2(u.x, u.y, tg.x, tg.y)
		var dest_x := tg.x
		var dest_y := tg.y
		var stop_at := reach - 50
		if u.type == D.ASSASSIN and u.stealth > 0:
			# 潛行中繞到目標背後
			dest_x = tg.x - tg.fx * D.BEHIND_DIST / 1000
			dest_y = tg.y - tg.fy * D.BEHIND_DIST / 1000
			stop_at = 0
		elif u.type == D.CAVALRY:
			var wp := _flank_waypoint(i, t)
			if wp.x >= 0:
				dest_x = wp.x
				dest_y = wp.y
				stop_at = 0
		var need_move := d2 > reach * reach or (u.type == D.ASSASSIN and u.stealth > 0)
		if need_move:
			var dx := dest_x - u.x
			var dy := dest_y - u.y
			var l := M.isqrt(dx * dx + dy * dy)
			var spd := u.speed
			if u.slow > 0:
				spd = spd * D.SLOW_NUM / D.SLOW_DEN
			var stp := mini(spd, l - stop_at)
			if stp > 0 and l > 0:
				u.mx = dx * stp / l
				u.my = dy * stp / l
				nx[i] = u.x + u.mx
				ny[i] = u.y + u.my
		# 面向（優化方案 B1）：交戰中鎖定，只有換目標才重算；不交戰時朝移動方向
		var engage := reach + CELL
		if d2 <= engage * engage:
			new_lock[i] = t
			if u.face_lock != t:
				var f := M.unit1000(tg.x - u.x, tg.y - u.y)
				if f != Vector2i.ZERO:
					new_fx[i] = f.x
					new_fy[i] = f.y
		else:
			var f2 := M.unit1000(u.mx, u.my)
			if f2 != Vector2i.ZERO:
				new_fx[i] = f2.x
				new_fy[i] = f2.y

	# ③ 統一解碰撞（固定兩輪，所有推力加總後一次套用）
	for _pass in 2:
		var px := PackedInt64Array()
		var py := PackedInt64Array()
		px.resize(n)
		py.resize(n)
		for i in n:
			if sv[i] == 0:
				continue
			var xi := nx[i]
			var yi := ny[i]
			for j in range(i + 1, n):
				if sv[j] == 0:
					continue
				var dx := nx[j] - xi
				var dy := ny[j] - yi
				if dx >= MIN_SEP or dx <= -MIN_SEP or dy >= MIN_SEP or dy <= -MIN_SEP:
					continue
				var d2 := dx * dx + dy * dy
				if d2 >= MIN_SEP * MIN_SEP:
					continue
				var d := M.isqrt(d2)
				var ux := 0
				var uy := 0
				if d == 0:
					# 零距離：不同隊左右分開（藍往左、紅往右）；同隊上下分開
					if st[i] != st[j]:
						ux = 1000 if st[i] == 0 else -1000
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
		var u := units[i]
		if not u.alive:
			continue
		var moved_x: int = nx[i] - u.x
		var moved_y: int = ny[i] - u.y
		if u.type == D.CAVALRY:
			_update_charge(u, moved_x, moved_y)
		u.x = nx[i]
		u.y = ny[i]
		u.target = new_target[i]
		u.fx = new_fx[i]
		u.fy = new_fy[i]
		u.face_lock = new_lock[i]   # 只在第②步已經轉向目標之後才鎖定

	# ④ 產生攻擊（讀這一 tick 已確定的位置與面向）
	var hits: Array = []   # [來源, 目標, 傷害, 種類]
	var stun_set := {}
	var slow_set := {}
	var reveal := {}
	var knock: Array = []
	var attacked := PackedByteArray()
	attacked.resize(n)
	var sword_hit_by := {}   # 劍士索引 → 這一 tick 打中它的刺客索引們
	var dec := D.FRENZY_CD_RATE if frenzy else 4
	# 背水（追趕機制，預設關閉）：用這一 tick 開始時的戰力判斷，兩隊同時算
	var rally_bonus := [0, 0]
	rally = [false, false]
	if D.RALLY_RATIO_PCT > 0:
		var pw := [power(0), power(1)]
		for tm in 2:
			if pw[tm] * 100 < pw[1 - tm] * D.RALLY_RATIO_PCT:
				rally_bonus[tm] = D.RALLY_CD_BONUS
				rally[tm] = true
	for i in n:
		var u := units[i]
		if not u.alive:
			continue
		if u.cd > 0:
			u.cd = maxi(0, u.cd - dec - rally_bonus[u.team])
		if u.stun > 0 or u.target == -1 or u.cd > 0:
			continue
		var tg := units[u.target]
		if M.dist2(u.x, u.y, tg.x, tg.y) > u.reach * u.reach:
			continue
		if u.type == D.ASSASSIN and u.stealth > 0 and not _is_behind(u, tg):
			continue
		var dmg := u.atk
		var kind := "hit"
		if u.type == D.SHIELD and tg.type == D.CAVALRY:
			dmg = dmg * D.ANTICAV_NUM / D.ANTICAV_DEN
			kind = "anticav"
		if u.type == D.SWORD:
			if tg.type == D.SHIELD:
				dmg = dmg * D.BREAKER_NUM / D.BREAKER_DEN
				kind = "breaker"
		elif u.type == D.ARCHER:
			kind = "arrow"
			if tg.type == D.ASSASSIN:
				dmg = dmg * D.ALERT_NUM / D.ALERT_DEN
			if tg.type == D.SHIELD and not _is_behind(u, tg):
				dmg = dmg * D.BLOCK_NUM / D.BLOCK_DEN
				kind = "blocked"
			elif tg.type == D.CAVALRY:
				dmg = dmg * D.HIDE_ARROW_NUM / D.HIDE_ARROW_DEN
		elif u.type == D.CAVALRY:
			if u.charge >= D.CHARGE_NEED:
				if tg.type == D.SHIELD and not _is_behind(u, tg):
					stun_set[i] = true
					kind = "braced"
				else:
					dmg = dmg * D.CHARGE_NUM / D.CHARGE_DEN
					kind = "charge"
					knock.append([u.target, tg.x - u.x, tg.y - u.y])
		elif u.type == D.ASSASSIN:
			if _is_behind(u, tg):
				dmg = dmg * D.BACKSTAB_NUM / D.BACKSTAB_DEN
				kind = "backstab"
			if tg.type == D.CAVALRY:
				slow_set[u.target] = true
			reveal[i] = true
			if tg.type == D.SWORD:
				if not sword_hit_by.has(u.target):
					sword_hit_by[u.target] = []
				sword_hit_by[u.target].append(i)
		hits.append([i, u.target, dmg, kind])
		attacked[i] = 1
		u.cd += u.cd_base * 4
		if u.type == D.CAVALRY:
			u.charge = 0   # 任何一擊之後都要重新直行才能再衝
	# 劍士反擊（優化方案 B1）：這一 tick 打中它的刺客裡，挑「最近→列小→離自己底線近」的那一隻，每 tick 最多一次
	var swords := sword_hit_by.keys()
	swords.sort()
	for si in swords:
		var sw := units[si]
		hits.append([si, pick_counter(si, sword_hit_by[si]), sw.atk * D.COUNTER_PCT / 100, "counter"])

	# ⑤ 同時結算
	var dmg_in := PackedInt64Array()
	dmg_in.resize(n)
	var last_hit := PackedInt64Array()
	last_hit.resize(n)
	last_hit.fill(-1)
	var per_pair := {}   # (目標, 攻擊者) → 這一 tick 的傷害
	for h in hits:
		dmg_in[h[1]] += h[2]
		units[h[0]].dmg_dealt += h[2]
		units[h[1]].dmg_taken += h[2]
		var key: int = h[1] * 4096 + h[0]
		per_pair[key] = int(per_pair.get(key, 0)) + h[2]
		events.append({"src": units[h[0]].id, "tgt": units[h[1]].id, "dmg": h[2], "kind": h[3]})
	# 擊殺歸屬：傷害最高者；同傷害比列小、再比離自己底線近（只用鏡像不變的鍵）
	var best_d := PackedInt64Array()
	best_d.resize(n)
	for key in per_pair:
		var tgt: int = key / 4096
		var src: int = key % 4096
		var d: int = per_pair[key]
		var cur: int = last_hit[tgt]
		var better := cur == -1 or d > best_d[tgt]
		if not better and d == best_d[tgt]:
			var a := units[src]
			var b := units[cur]
			var da: int = a.x if a.team == 0 else W - a.x
			var db: int = b.x if b.team == 0 else W - b.x
			better = a.y < b.y or (a.y == b.y and da < db)
		if better:
			last_hit[tgt] = src
			best_d[tgt] = d
	# 狂熱耗損：第 1200+100k tick（k＝0～5）扣 (k+1)×STEP% 滿血（至少 1）
	if tick >= FRENZY_TICK and (tick - FRENZY_TICK) % 100 == 0 and (tick - FRENZY_TICK) / 100 <= 5:
		var k := (tick - FRENZY_TICK) / 100
		for i in n:
			if units[i].alive:
				dmg_in[i] += maxi(1, units[i].max_hp * (k + 1) * D.ATTRITION_STEP_PCT / 100)
		events.append({"kind": "attrition", "k": k})
	for kb in knock:
		var v := M.unit1000(kb[1], kb[2])
		var t: Unit = units[kb[0]]
		t.x = clampi(t.x + v.x * D.KNOCKBACK / 1000, EDGE, W - EDGE)
		t.y = clampi(t.y + v.y * D.KNOCKBACK / 1000, EDGE, H - EDGE)
	for i in n:
		var u := units[i]
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
		# 騎兵這一 tick 沒動也沒出手（被擋、等待）→ 衝鋒歸零
		if u.type == D.CAVALRY and u.mx == 0 and u.my == 0 and attacked[i] == 0:
			u.charge = 0
	for i in n:
		var u := units[i]
		if u.alive and u.hp <= 0:
			u.alive = false
			u.hp = 0
			if last_hit[i] != -1:
				units[last_hit[i]].kills += 1
			events.append({"kind": "death", "id": u.id})

	power_log.append(power(0) - power(1))
	if not fast:
		_hash_state()
	_check_end()

# ───────────────────────── 規則細節 ─────────────────────────

## 選目標（企劃 §3.3）：排除潛行 → 弓手警覺 → 盾兵嘲諷（近戰）→ 兵種偏好 → 距離 → 剩血 → 列 → 深度 → 編號。
## 只讀快照陣列，比較全部用整數（不配置陣列）。
func _choose_target(i: int, sx: PackedInt64Array, sy: PackedInt64Array, st: PackedInt64Array,
		sk: PackedInt64Array, sh: PackedInt64Array, sv: PackedByteArray) -> int:
	var my_team: int = st[i]
	var my_type: int = sk[i]
	var ux: int = sx[i]
	var uy: int = sy[i]
	var reach: int = units[i].reach
	var reach2 := reach * reach
	var taunt2 := D.TAUNT_RANGE * D.TAUNT_RANGE
	var melee := my_type != D.ARCHER
	var best := -1
	var b_rank := 99
	var b_d2 := 0
	var b_hp := 0
	var b_y := 0
	var b_dep := 0
	var n := sx.size()
	for j in n:
		if sv[j] == 0 or st[j] == my_team:
			continue
		var dx: int = sx[j] - ux
		var dy: int = sy[j] - uy
		var d2 := dx * dx + dy * dy
		var et: int = sk[j]
		var rank := 3
		if my_type == D.ARCHER and et == D.ASSASSIN and d2 <= reach2:
			rank = 0
		elif melee and et == D.SHIELD and d2 <= taunt2:
			rank = 1
		elif my_type == D.CAVALRY and et == D.ARCHER:
			rank = 2
		elif my_type == D.ASSASSIN and (et == D.SHIELD or et == D.CAVALRY):
			rank = 2
		if best != -1:
			if rank > b_rank:
				continue
			if rank == b_rank:
				if d2 > b_d2:
					continue
				if d2 == b_d2:
					var hp: int = sh[j]
					if hp > b_hp:
						continue
					if hp == b_hp:
						var ey: int = sy[j]
						if ey > b_y:
							continue
						if ey == b_y:
							var dep: int = sx[j] if st[j] == 0 else W - sx[j]
							if dep >= b_dep:
								continue
		best = j
		b_rank = rank
		b_d2 = d2
		b_hp = sh[j]
		b_y = sy[j]
		b_dep = sx[j] if st[j] == 0 else W - sx[j]
	return best

## 劍士反擊選人：打中它的刺客裡挑「最近→列小→離自己底線近」；只用鏡像不變的鍵，不用編號。
func pick_counter(si: int, attackers: Array) -> int:
	var sw := units[si]
	var best := -1
	var bd := 0
	var by := 0
	var bdep := 0
	for ai in attackers:
		var a := units[ai]
		var d2 := M.dist2(sw.x, sw.y, a.x, a.y)
		var dep: int = a.x if a.team == 0 else W - a.x
		if best == -1 or d2 < bd or (d2 == bd and (a.y < by or (a.y == by and dep < bdep))):
			best = ai
			bd = d2
			by = a.y
			bdep = dep
	return best

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

## 騎兵衝鋒累積（優化方案 B1）：只算「沿著這段衝鋒起始方向」的實際前進距離；
## 被推開的位移不算；方向跟起始方向差太多（逐步轉彎也算）就重新開始；被擋住前進不到一半就歸零。
func _update_charge(u: Unit, moved_x: int, moved_y: int) -> void:
	if u.mx == 0 and u.my == 0:
		return   # 沒有提出移動（停下攻擊或等待），在第⑤步處理
	var ml := M.isqrt(u.mx * u.mx + u.my * u.my)
	# 只算沿著自己提出方向的前進，而且最多算自己提出的距離（被往前推的部分不算）
	var along := mini(ml, (moved_x * u.mx + moved_y * u.my) / maxi(1, ml))
	if along * 2 < ml:
		u.charge = 0
		u.cdx = 0
		u.cdy = 0
		return
	if u.charge == 0 or not _same_dir(u.cdx, u.cdy, u.mx, u.my):
		u.charge = along
		u.cdx = u.mx
		u.cdy = u.my
	else:
		u.charge += along

## 騎兵繞翼：目標是弓手、直線上 FLANK_DETECT 內有盾兵時，往敵兵較少的那側偏 FLANK_OFFSET 走途經點。
func _flank_waypoint(i: int, t: int) -> Vector2i:
	var u := units[i]
	var tg := units[t]
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
		if cross * cross < D.FLANK_DETECT * D.FLANK_DETECT * l2:
			blocked = true
	if not blocked:
		return Vector2i(-1, -1)
	var wy: int
	if above <= below:
		wy = mini(u.y, tg.y) - D.FLANK_OFFSET
	else:
		wy = maxi(u.y, tg.y) + D.FLANK_OFFSET
	u.wp_for = tg.id
	u.wp_x = u.x + (tg.x - u.x) / 2   # 用差值往 0 截斷，左右鏡像才對稱
	u.wp_y = clampi(wy, EDGE, H - EDGE)
	return Vector2i(u.wp_x, u.wp_y)

## 完整狀態指紋：每 tick 依 id 順序寫入固定 26 個 int64 欄位。
func _hash_state() -> void:
	var a := PackedInt64Array()
	a.resize(units.size() * 26 + 1)
	a[0] = tick
	var k := 1
	for u in units:
		a[k] = u.x; a[k + 1] = u.y; a[k + 2] = u.hp; a[k + 3] = u.cd; a[k + 4] = u.target
		a[k + 5] = u.fx; a[k + 6] = u.fy; a[k + 7] = u.face_lock; a[k + 8] = u.mx; a[k + 9] = u.my
		a[k + 10] = u.cdx; a[k + 11] = u.cdy; a[k + 12] = u.stealth; a[k + 13] = u.charge; a[k + 14] = u.stun
		a[k + 15] = u.slow; a[k + 16] = u.wp_x; a[k + 17] = u.wp_y; a[k + 18] = u.wp_for; a[k + 19] = 1 if u.alive else 0
		a[k + 20] = u.dmg_dealt; a[k + 21] = u.dmg_taken; a[k + 22] = u.kills; a[k + 23] = u.id; a[k + 24] = u.team; a[k + 25] = u.type
		k += 26
	_hash.update(a.to_byte_array())

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
	_hash.update(PackedInt64Array([tick, w]).to_byte_array())
	fingerprint = _hash.finish().hex_encode()

func unit_by_id(id: int) -> Unit:
	for u in units:
		if u.id == id:
			return u
	return null

## 懸念指標（優化方案 B2）：用每 tick 的戰力差 Δ(t) 算。只在結束後呼叫。
## lead_changes：開戰 5 秒後 Δ 跨過 ±5%（以總預算計）的次數；
## lock_ratio：勝方從這一 tick 起領先再也不低於 20% 的時間點 ÷ 全場；
## max_swing：贏家曾經落後的最大幅度（%）。
func suspense() -> Dictionary:
	var total := budget * 1000
	var thr := total * 5 / 100
	var lock_thr := total * 20 / 100
	var changes := 0
	var side := 0
	for t in range(100, power_log.size()):
		var d: int = power_log[t]
		var s := 0
		if d > thr:
			s = 1
		elif d < -thr:
			s = -1
		if s != 0:
			if side != 0 and s != side:
				changes += 1
			side = s
	var lock_t := power_log.size()
	var swing := 0
	if winner >= 0:
		var sign := 1 if winner == 0 else -1
		lock_t = 0
		for t in power_log.size():
			var lead: int = power_log[t] * sign
			if lead < lock_thr:
				lock_t = t + 1
			if -lead > swing:
				swing = -lead
	var ratio := lock_t * 1000 / maxi(1, power_log.size())
	return {"lead_changes": changes, "lock_ratio_permille": ratio, "max_swing_pct": swing * 100 / total}
