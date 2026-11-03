extends RefCounted
## 戰鬥核心（純邏輯、全整數、確定性）。企劃 §2.3、§2.4、§3.3；優化方案 B1、L1。
## 每 tick 固定五步：①讀快照 ②選目標＋提出移動 ③統一解碰撞 ④產生攻擊 ⑤同時結算。
## 任何一步都只讀「這一步開始前」的狀態，所以不會因為誰先算就佔便宜。
## 禁止新增浮點運算（imath.isqrt 內的浮點估計之後一定用整數修正）。
## 指紋＝每 tick 完整狀態（固定欄位、int64 小端序）串接後的 SHA-256。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const EV = preload("res://scripts/core/events.gd")
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
	var wp_for := -1           # 這條繞翼路線是為了哪個目標（id）
	var nav := 0               # 繞翼導航：0 沒有／直衝、1 繞翼中、2 已完成（同一個目標不再繞）
	var chasing := false       # 騎兵追擊遲滯狀態
	var alive := true
	# ── 第四輪新兵種的狀態（舊 5 種永遠維持初值，tools/compat.gd 會檢查）──
	var hcd := 0               # 醫者補血冷卻（tick，不吃加速）
	var aura := 0              # 這一 tick 是否在鼓手光環內（1／0）
	var breach := 0            # 被狂戰士破陣的剩餘 tick（盾兵、長槍兵）
	var bmode := 0             # 投彈兵這一 tick 的模式：0 無、1 丟彈、2 敲人
	var heal_done := 0         # 醫者實際補進去的總量（結果頁用）
	var drum_cover := 0        # 鼓手：累計「鼓舞到的友軍 × tick」（結果頁用，不含自己）
	var follow := -1           # 支援兵這一 tick 跟隨的友軍索引（-1＝重心或沒有）
	var slot := 0              # 部署格（以自己隊伍視角：列×16＋欄），平手規則用，鏡像不變
	var dmg_dealt := 0
	var dmg_taken := 0
	var kills := 0

var units: Array[Unit] = []    # 依 id 排序
var tick := 0
var budget := 100
var budgets := [100, 100]      # 第五輪：兩邊各自的預算（judge 1 時兩格都等於 budget，畫面算比例才一致）
var judge := 1                 # 第五輪：1＝1.3.0 舊判定（只看藍方預算）；2＝讓子時的比例判定
var max_ticks := MAX_TICKS     # 第五輪：一局 tick 數、狂熱時間表改成每場參數（標準值＝1.3.0 常數）
var frenzy_at := FRENZY_TICK
var attr_step := 100
var rules = null               # 第五輪：這一場凍結的規則（null＝標準）
var free := false              # 第六輪：自由部署（起始座標不在格子上、編號依座標排序）
var power_log2: PackedInt64Array = PackedInt64Array()  # 第五輪：每 tick 兩方戰力（藍、紅交錯），戰力走勢圖用
# 第五輪沙盒（R3）：每場一份，存在這個實例上（不改全域常數，同時跑兩場不同規則不會互相污染）
var skill_off := {}            # 關掉的技能 → true
var atk_pct: Array = []        # 每種兵的攻擊倍率（％）：波及、敲人、補血這些獨立常數也照這個比例
var finished := false
var winner := -2               # -2 進行中；-1 平手；0／1 勝方
var reason := ""
var fingerprint := ""          # 結束時的 SHA-256（十六進位）
var events: Array = []         # 這一 tick 的事件（給畫面演出用，不影響計算）
var frenzy := false
var rally := [false, false]    # 這一 tick 哪一隊在「背水」（畫面提示用；計算用的是第④步當下的值）
var power_log: PackedInt64Array = PackedInt64Array()   # 每 tick 的（藍戰力−紅戰力），懸念指標用
var _hash := HashingContext.new()
var _last_rank := 99          # 上一次 _choose_target 選中目標的優先級（1＝嘲諷）
var _was_stealth := {}         # 刺客上一 tick 是否潛行（現形事件用）
var _was_rally := [false, false]          # 上一 tick 哪一隊在背水（背水開／關事件用）
var fast := false              # 平衡工具用：不算每 tick 指紋（結果完全一樣，只是沒有指紋）

## rules：第五輪 Ruleset（可省略）。省略或是舊路徑規則時，雜湊位元組、判定都和 1.3.0 完全相同。
func _init(army0, army1, p_rules = null) -> void:
	budget = army0.budget
	budgets = [budget, budget]
	var legacy: bool = p_rules == null or p_rules.sim_is_legacy()
	if not legacy:
		rules = p_rules.copy()
		max_ticks = rules.ticks
		frenzy_at = rules.frenzy_tick()
		attr_step = rules.attrition_step()
		judge = rules.judge()
		if judge == 2:
			budgets = [army0.budget, army1.budget]
		for k in rules.skills_off:
			skill_off[k] = true
	atk_pct.resize(D.COUNT)
	atk_pct.fill(100)
	if rules != null:
		for t in rules.stat_pct:
			atk_pct[int(t)] = int(rules.stat_pct[t][1])
	_hash.start(HashingContext.HASH_SHA256)
	var raw: Array = []
	# 第六輪：自由部署（§3.1、§3.8）——同隊依自己視角 (y, x) 排序，第 k 隻 id＝隊伍×1000＋k、slot＝k。
	# 格子部署走原本的 id（隊伍×1000＋列×16＋欄），雜湊位元組和 1.3.0 相同。
	free = str(army0.get("deploy")) == "free" or str(army1.get("deploy")) == "free"
	var mixed: bool = str(army0.get("deploy")) != str(army1.get("deploy"))
	for a in [army0, army1]:
		if free:
			var lst: Array = []
			for u in a.units:
				var pp: Vector2i = Army.pos_of(u)
				var ox: int = pp.x if a.team == 0 else W - pp.x
				lst.append([pp.y * 100000 + ox, u, pp])
			lst.sort_custom(func(p, q): return p[0] < q[0])
			for k in lst.size():
				raw.append([a.team * 1000 + k, a.team, lst[k][1], lst[k][2], k])
		else:
			for u in a.units:
				raw.append([a.team * 1000 + u["row"] * COLS + u["col"], a.team, u, Vector2i(u["col"] * CELL + CELL / 2, u["row"] * CELL + CELL / 2), -1])
	raw.sort_custom(func(p, q): return p[0] < q[0])
	for r in raw:
		var u = r[2]
		var s: Dictionary = D.STATS[u["type"]]
		var n := Unit.new()
		n.id = r[0]
		n.team = r[1]
		n.type = u["type"]
		n.x = r[3].x
		n.y = r[3].y
		n.hp = s["hp"]
		n.max_hp = s["hp"]
		n.cost = s["cost"]
		n.reach = s["reach"]
		n.speed = s["speed"]
		n.atk = s["atk"]
		n.cd_base = s["cd"]
		if rules != null and rules.stat_pct.has(n.type):
			# 沙盒倍率：血量、攻擊、速度（整數百分比，至少 1）
			var pc: Array = rules.stat_pct[n.type]
			n.hp = maxi(1, n.hp * int(pc[0]) / 100)
			n.max_hp = n.hp
			n.atk = maxi(1, n.atk * int(pc[1]) / 100)
			n.speed = maxi(1, n.speed * int(pc[2]) / 100)
		n.fx = 1000 if n.team == 0 else -1000
		if n.type == D.ASSASSIN and not skill_off.has("stealth"):
			n.stealth = D.STEALTH_TICKS
		if n.type == D.MEDIC:
			n.hcd = D.HEAL_FIRST
		n.slot = int(r[4]) if free else int(u["row"]) * COLS + (int(u["col"]) if n.team == 0 else COLS - 1 - int(u["col"]))
		units.append(n)
	var hdr := PackedInt64Array([D.RULES_VERSION_INT, budget, units.size()])
	_hash.update(hdr.to_byte_array())
	_hash.update(D.data_digest().to_utf8_buffer())
	if not legacy:
		_hash.update(rules.sim_digest().to_utf8_buffer())
	elif free:
		_hash.update("free".to_utf8_buffer())   # 自由陣型但沒給規則（工具）：仍和格子陣型區分
	if mixed:
		_finish(-1, "部署版本不一致")
	elif alive_count(0) == 0 or alive_count(1) == 0:
		_finish(-1, "有一方沒有兵")

func alive_count(team: int) -> int:
	var c := 0
	for u in units:
		if u.alive and u.team == team:
			c += 1
	return c

## 剩餘戰力＝Σ兵價×剩血×1000÷滿血（企劃 §2.4）。
func power(team: int) -> int:
	var p := 0
	for u in units:
		if u.alive and u.team == team:
			p += u.cost * u.hp * 1000 / u.max_hp
	return p

## 第五輪：這一隊的預算（judge 1 時兩隊都回傳藍方預算，和 1.3.0 畫面一致）。
func budget_of(team: int) -> int:
	return int(budgets[team])

## 剩餘戰力占自己預算的千分比（0～1000）。
func power_permille(team: int) -> int:
	return power(team) / maxi(1, budget_of(team))

## 第五輪：第 t 個 tick 的戰力差，換算成「每 1000 單位預算」的尺度（讓子時用各自預算的比例；畫面、時間軸用）。
func diff_permille(t: int) -> int:
	if judge == 2 and 2 * t + 1 < power_log2.size():
		return power_log2[2 * t] * 1000 / budgets[0] - power_log2[2 * t + 1] * 1000 / budgets[1]
	return power_log[t] * 1000 / maxi(1, budget) if t < power_log.size() else 0

func run_to_end() -> void:
	while not finished:
		step()

# ───────────────────────── 一個 tick ─────────────────────────
func step() -> void:
	if finished:
		return
	tick += 1
	frenzy = tick >= frenzy_at and not skill_off.has("frenzy")
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
	# 每隊還活著的戰鬥兵（非支援）數量：支援兵用來決定「支援模式」還是「自己打」（第四輪）
	var fighters := [0, 0]
	for i in n:
		if units[i].alive and not D.is_support(units[i].type):
			fighters[units[i].team] += 1

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
		u.follow = -1
		u.bmode = 0
		if D.is_support(u.type) and fighters[u.team] > 0:
			# 支援模式（第四輪 §2.3／§2.5）：不選敵人，跟隨友軍
			new_target[i] = -1
			if u.stun > 0:
				continue
			var fp := _support_point(i, sx, sy, sh)
			var bx := fp.x - D.SUPPORT_BACK if u.team == 0 else fp.x + D.SUPPORT_BACK
			var dest_sx := clampi(bx, EDGE, W - EDGE)
			var dest_sy := clampi(fp.y, EDGE, H - EDGE)
			var sdx := dest_sx - u.x
			var sdy := dest_sy - u.y
			var sl := M.isqrt(sdx * sdx + sdy * sdy)
			if sl > D.SUPPORT_STOP:
				var sstp := mini(u.speed, sl)
				u.mx = sdx * sstp / sl
				u.my = sdy * sstp / sl
				nx[i] = u.x + u.mx
				ny[i] = u.y + u.my
			var sf := M.unit1000(fp.x - u.x, fp.y - u.y)
			if sf != Vector2i.ZERO:
				new_fx[i] = sf.x
				new_fy[i] = sf.y
			continue
		var t := -1
		if u.type == D.BOMBER:
			# 投彈兵（第四輪 §2.2）：最近的「可見」敵人在 1.5 格內 → 這一 tick 敲人；否則只從 ≥1.5 格的敵人裡選丟彈目標
			var near2 := _nearest_visible_enemy_d2(i, sx, sy, st, sv)
			if near2 >= 0 and near2 < D.BOMB_MIN * D.BOMB_MIN:
				u.bmode = 2
				t = _choose_target(i, sx, sy, st, sk, sh, sv)
			elif near2 >= 0:
				u.bmode = 1
				t = _choose_target(i, sx, sy, st, sk, sh, sv, D.BOMB_MIN * D.BOMB_MIN)
		else:
			t = _choose_target(i, sx, sy, st, sk, sh, sv)
		new_target[i] = t
		# 技能事件（只給畫面與圖鑑用，不進指紋）：被盾兵嘲諷吸走
		if t != -1 and t != u.target and _last_rank == 1:
			events.append({"kind": EV.TAUNT, "src": units[t].id, "tgt": u.id, "tags": [EV.TAUNT]})
		if t == -1 or u.stun > 0:
			continue
		var tg := units[t]
		var reach := u.reach if u.bmode != 2 else D.BONK_REACH
		var d2 := M.dist2(u.x, u.y, tg.x, tg.y)
		var dest_x := tg.x
		var dest_y := tg.y
		var stop_at := reach - 50
		var flanking := false
		if u.type == D.ASSASSIN and u.stealth > 0:
			# 潛行中繞到目標背後（目的地夾在場內）
			dest_x = clampi(tg.x - tg.fx * D.BEHIND_DIST / 1000, EDGE, W - EDGE)
			dest_y = clampi(tg.y - tg.fy * D.BEHIND_DIST / 1000, EDGE, H - EDGE)
			stop_at = 0
		elif u.type == D.CAVALRY:
			var wp := _flank_waypoint(i, t)
			if wp.x >= 0:
				if d2 <= reach * reach:
					u.nav = 2            # 敵人已在射程內：結束繞翼直接開打，不卡在未完成狀態
				else:
					dest_x = wp.x
					dest_y = wp.y
					stop_at = 0
					flanking = true
		var need_move := d2 > reach * reach or (u.type == D.ASSASSIN and u.stealth > 0) or flanking
		if u.type == D.CAVALRY and not flanking:
			# 追擊遲滯：已經在追就追到 reach−CHASE_HYST 才停；停著的要超出 reach 才起步
			need_move = cav_chase(u.chasing, d2, reach)
			stop_at = reach - D.CHASE_HYST
			u.chasing = need_move
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
	if D.RALLY_RATIO_PCT > 0 and not skill_off.has("rally"):
		var pw := [power(0), power(1)] if judge == 1 else [power_permille(0), power_permille(1)]   # 讓子時比各自預算的比例
		for tm in 2:
			if pw[tm] * 100 < pw[1 - tm] * D.RALLY_RATIO_PCT:
				rally_bonus[tm] = D.RALLY_CD_BONUS
				rally[tm] = true
	for tm in 2:
		if rally[tm] != _was_rally[tm]:
			events.append({"kind": EV.RALLY_ON if rally[tm] else EV.RALLY_OFF, "team": tm, "tags": [EV.RALLY]})
			_was_rally[tm] = rally[tm]
	# 戰鼓（第四輪 §2.5）：用 ① 快照的位置；這一 tick 開始時活著、沒被暈的鼓手才算；先算完整陣列再扣冷卻；不疊加
	for i in n:
		units[i].aura = 0
	for di in n:
		var dr := units[di]
		if dr.type != D.DRUMMER or not dr.alive or dr.stun > 0 or skill_off.has("drum"):
			continue
		var cov := 0
		for j in n:
			if units[j].alive and st[j] == st[di] and M.dist2(sx[di], sy[di], sx[j], sy[j]) <= D.DRUM_RANGE * D.DRUM_RANGE:
				units[j].aura = 1
				if j != di:
					cov += 1
		dr.drum_cover += cov
		if cov > 0 and tick % 20 == 0:
			events.append({"kind": EV.DRUM, "src": dr.id, "n": cov, "tags": [EV.DRUM]})   # 每秒一拍（只給畫面與圖鑑）
	var breach_set := {}
	var heals: Array = []   # [醫者索引, 目標索引, 量]
	for i in n:
		var u := units[i]
		if not u.alive:
			continue
		if u.cd > 0:
			u.cd = maxi(0, u.cd - mini(D.DEC_CAP, dec + rally_bonus[u.team] + D.DRUM_BONUS * u.aura))
		if u.type == D.MEDIC and not skill_off.has("heal"):
			_try_heal(i, sh, heals)
		if u.stun > 0 or u.target == -1 or u.cd > 0:
			continue
		var tg := units[u.target]
		if u.type == D.BOMBER and u.bmode == 1:
			# 丟彈：④ 重新驗距離（③ 會移動位置），要在 1.5～4.5 格；不符合就取消，不臨時換模式
			var bd2 := M.dist2(u.x, u.y, tg.x, tg.y)
			if bd2 < D.BOMB_MIN * D.BOMB_MIN or bd2 > u.reach * u.reach:
				continue
			hits.append([i, u.target, _vuln(tg, u.atk * D.BOMB_SHIELD_NUM / D.BOMB_SHIELD_DEN if tg.type == D.SHIELD else u.atk), EV.BOMB, [EV.BOMB]])
			for j in ([] if skill_off.has("splash") else _splash_victims(u.target, st, sv)):
				var sj := units[j]
				var spd: int = D.SPLASH_DMG * atk_pct[D.BOMBER] / 100
				hits.append([i, j, _vuln(sj, spd * D.BOMB_SHIELD_NUM / D.BOMB_SHIELD_DEN if sj.type == D.SHIELD else spd), EV.SPLASH, [EV.SPLASH]])
			attacked[i] = 1
			u.cd += u.cd_base * 4
			continue
		if u.type == D.BOMBER and u.bmode == 2:
			if M.dist2(u.x, u.y, tg.x, tg.y) > D.BONK_REACH * D.BONK_REACH:
				continue
			hits.append([i, u.target, _vuln(tg, maxi(1, D.BONK_ATK * atk_pct[D.BOMBER] / 100)), EV.BONK, [EV.BONK]])
			attacked[i] = 1
			u.cd += D.BONK_CD * 4
			continue
		if M.dist2(u.x, u.y, tg.x, tg.y) > u.reach * u.reach:
			continue
		if u.type == D.ASSASSIN and u.stealth > 0 and not _is_behind(u, tg):
			continue
		var dmg := u.atk
		var kind: String = EV.HIT
		var tags: Array = []
		if u.type == D.SHIELD and tg.type == D.CAVALRY:
			dmg = dmg * D.ANTICAV_NUM / D.ANTICAV_DEN
			kind = EV.ANTICAV
			tags.append(EV.ANTICAV)
		elif u.type == D.PIKE and tg.type == D.CAVALRY and not skill_off.has("brace"):
			dmg = dmg * D.PIKE_ANTICAV_NUM / D.PIKE_ANTICAV_DEN
			kind = EV.ANTICAV
			tags.append(EV.ANTICAV)
		elif u.type == D.BERSERKER and (tg.type == D.SHIELD or tg.type == D.PIKE) and not skill_off.has("breach"):
			breach_set[u.target] = true
			# 破陣擴散：目標 ④ 位置 1 格內、同隊、活著的其他盾兵／長槍兵一起破陣（集合，與順序無關）
			for j in n:
				var o := units[j]
				if j != u.target and o.alive and o.team == tg.team and (o.type == D.SHIELD or o.type == D.PIKE) \
						and M.dist2(o.x, o.y, tg.x, tg.y) <= D.BREACH_SPREAD * D.BREACH_SPREAD:
					breach_set[j] = true
			tags.append(EV.BREACH)
			if tg.breach == 0:
				kind = EV.BREACH   # 只有「剛被破陣」那一下算破陣事件（跳字、戰報）；刷新時標籤照帶
		if u.type == D.SWORD:
			if tg.type == D.SHIELD:
				dmg = dmg * D.BREAKER_NUM / D.BREAKER_DEN
				kind = EV.BREAKER
				tags.append(EV.BREAKER)
		elif u.type == D.ARCHER:
			kind = EV.ARROW
			tags.append(EV.ARROW)
			if tg.type == D.ASSASSIN:
				dmg = dmg * D.ALERT_NUM / D.ALERT_DEN
				tags.append(EV.ALERT)
			if tg.type == D.SHIELD and tg.breach == 0 and not _is_behind(u, tg):
				dmg = dmg * D.BLOCK_NUM / D.BLOCK_DEN
				kind = EV.BLOCKED
				tags.append(EV.BLOCKED)
			elif tg.type == D.CAVALRY:
				dmg = dmg * D.HIDE_ARROW_NUM / D.HIDE_ARROW_DEN
				tags.append(EV.HIDE)
			elif tg.type == D.BERSERKER:
				dmg = dmg * D.BERSERK_ARROW_NUM / D.BERSERK_ARROW_DEN
		elif u.type == D.CAVALRY:
			if u.charge >= D.CHARGE_NEED and not skill_off.has("charge"):
				if tg.type == D.SHIELD and not _is_behind(u, tg):
					stun_set[i] = true
					kind = EV.BRACED
					tags.append(EV.BRACED)
				elif tg.type == D.PIKE and tg.breach == 0 and not _is_behind(u, tg) and not skill_off.has("brace"):
					# 拒騎（第四輪 §2.1）：正面衝到長槍兵，衝鋒倍率與擊退都不生效（衝鋒照樣消耗）
					kind = EV.PIKE_BRACE
					tags.append(EV.PIKE_BRACE)
				else:
					dmg = dmg * D.CHARGE_NUM / D.CHARGE_DEN
					kind = EV.CHARGE
					tags.append(EV.CHARGE)
					if tg.type != D.BERSERKER:   # 狂戰士不被擊退（第四輪 §2.4）
						knock.append([u.target, tg.x - u.x, tg.y - u.y])
		elif u.type == D.ASSASSIN:
			if _is_behind(u, tg) and not skill_off.has("backstab"):
				dmg = dmg * D.BACKSTAB_NUM / D.BACKSTAB_DEN
				kind = EV.BACKSTAB
				tags.append(EV.BACKSTAB)
			if tg.type == D.CAVALRY:
				slow_set[u.target] = true
				tags.append(EV.TRIP)
			reveal[i] = true
			if tg.type == D.SWORD:
				if not sword_hit_by.has(u.target):
					sword_hit_by[u.target] = []
				sword_hit_by[u.target].append(i)
		if tags.is_empty():
			tags.append(EV.HIT)
		hits.append([i, u.target, _vuln(tg, dmg), kind, tags])
		attacked[i] = 1
		u.cd += u.cd_base * 4
		if u.type == D.CAVALRY:
			u.charge = 0   # 任何一擊之後都要重新直行才能再衝
	# 劍士反擊（優化方案 B1）：這一 tick 打中它的刺客裡，挑「最近→列小→離自己底線近」的那一隻，每 tick 最多一次
	var swords := sword_hit_by.keys()
	swords.sort()
	for si in ([] if skill_off.has("counter") else swords):
		var sw := units[si]
		hits.append([si, pick_counter(si, sword_hit_by[si]), sw.atk * D.COUNTER_PCT / 100, EV.COUNTER, [EV.COUNTER]])

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
		events.append({"src": units[h[0]].id, "tgt": units[h[1]].id, "dmg": h[2], "kind": h[3], "tags": h[4]})
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
	if frenzy and (tick - frenzy_at) % attr_step == 0 and (tick - frenzy_at) / attr_step <= 5:
		var k := (tick - frenzy_at) / attr_step
		for i in n:
			if units[i].alive:
				dmg_in[i] += maxi(1, units[i].max_hp * (k + 1) * D.ATTRITION_STEP_PCT / 100)
		events.append({"kind": EV.ATTRITION, "k": k})
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
		if u.breach > 0:
			u.breach -= 1
		if breach_set.has(i):
			u.breach = D.BREACH_TICKS
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
		if u.type == D.ASSASSIN and u.stealth == 0 and _was_stealth.get(u.id, false):
			events.append({"kind": EV.REVEAL, "src": u.id, "tgt": u.id, "tags": [EV.REVEAL]})
		_was_stealth[u.id] = u.stealth > 0
		# 騎兵這一 tick 沒動也沒出手（被擋、等待）→ 衝鋒歸零
		if u.type == D.CAVALRY and u.mx == 0 and u.my == 0 and attacked[i] == 0:
			u.charge = 0
	_apply_heals(heals)
	for i in n:
		var u := units[i]
		if u.alive and u.hp <= 0:
			u.alive = false
			u.hp = 0
			if last_hit[i] != -1:
				units[last_hit[i]].kills += 1
			events.append({"kind": EV.DEATH, "id": u.id})

	power_log.append(power(0) - power(1))
	power_log2.append(power(0))
	power_log2.append(power(1))
	if not fast:
		_hash_state()
	_check_end()

# ───────────────────────── 規則細節 ─────────────────────────

## 選目標（企劃 §3.3）：排除潛行 → 弓手警覺 → 盾兵嘲諷（近戰）→ 兵種偏好 → 距離 → 剩血 → 列 → 深度 → 編號。
## 只讀快照陣列，比較全部用整數（不配置陣列）。
func _choose_target(i: int, sx: PackedInt64Array, sy: PackedInt64Array, st: PackedInt64Array,
		sk: PackedInt64Array, sh: PackedInt64Array, sv: PackedByteArray, min_d2 := 0) -> int:
	var my_team: int = st[i]
	var my_type: int = sk[i]
	var ux: int = sx[i]
	var uy: int = sy[i]
	var reach: int = units[i].reach
	var reach2 := reach * reach
	var taunt2 := -1 if skill_off.has("taunt") else D.TAUNT_RANGE * D.TAUNT_RANGE
	var melee := D.is_melee(my_type)
	var best := -1
	var b_rank := 99
	_last_rank = 99
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
		if d2 < min_d2:
			continue   # 投彈兵丟彈：最短射程內的不選（第四輪）
		var et: int = sk[j]
		var rank := 3
		if my_type == D.ARCHER and et == D.ASSASSIN and d2 <= reach2:
			rank = 0
		elif melee and et == D.SHIELD and d2 <= taunt2 and units[j].breach == 0:
			rank = 1   # 被破陣的盾兵不嘲諷（第四輪）
		elif my_type == D.CAVALRY and (et == D.ARCHER or et == D.MEDIC or et == D.BOMBER):
			rank = 2
		elif my_type == D.ASSASSIN and (et == D.SHIELD or et == D.CAVALRY or et == D.MEDIC):
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
	_last_rank = b_rank
	return best

## ───────────────────────── 第四輪新兵種 ─────────────────────────

## 平手鍵（鏡像不變、與輸入順序無關）：距離² → 列 → 離自己底線的深度 → 部署格。a 比 b 優先回傳 true。
func _tie_less(d2a: int, a: Unit, d2b: int, b: Unit) -> bool:
	if d2a != d2b:
		return d2a < d2b
	if a.y != b.y:
		return a.y < b.y
	var da: int = a.x if a.team == 0 else W - a.x
	var db: int = b.x if b.team == 0 else W - b.x
	if da != db:
		return da < db
	return a.slot < b.slot

## 最近的可見敵人距離²（沒有回傳 -1）。用 ① 快照。
func _nearest_visible_enemy_d2(i: int, sx: PackedInt64Array, sy: PackedInt64Array, st: PackedInt64Array, sv: PackedByteArray) -> int:
	var best := -1
	for j in sx.size():
		if sv[j] == 0 or st[j] == st[i]:
			continue
		var d2 := M.dist2(sx[i], sy[i], sx[j], sy[j])
		if best < 0 or d2 < best:
			best = d2
	return best

## 支援兵的跟隨點（第四輪 §2.3）：
## 醫者先找 3 格內沒滿血、血比例最低的戰鬥兵友軍（交叉相乘比較）；沒有就（鼓手一律）用戰鬥兵友軍重心。
## 只用 ① 快照的位置與血量；成員只算活著的非支援兵。
func _support_point(i: int, sx: PackedInt64Array, sy: PackedInt64Array, sh: PackedInt64Array) -> Vector2i:
	var u := units[i]
	if u.type == D.MEDIC:
		var best := -1
		var bd2 := 0
		for j in units.size():
			var a := units[j]
			if j == i or not a.alive or a.team != u.team or D.is_support(a.type) or sh[j] >= a.max_hp:
				continue
			var d2 := M.dist2(sx[i], sy[i], sx[j], sy[j])
			if d2 > D.HEAL_RANGE * D.HEAL_RANGE:
				continue
			if best == -1 or _ratio_less(sh[j], a.max_hp, d2, a, sh[best], units[best].max_hp, bd2, units[best]):
				best = j
				bd2 = d2
		if best != -1:
			u.follow = best
			return Vector2i(sx[best], sy[best])
	# 重心：x 先換成「離自己底線的深度」再平均（鏡像不變），y 直接平均；都是非負整數，截斷方向一致
	var sd := 0
	var sy2 := 0
	var cnt := 0
	for j in units.size():
		var a := units[j]
		if not a.alive or a.team != u.team or D.is_support(a.type):
			continue
		sd += sx[j] if u.team == 0 else W - sx[j]
		sy2 += sy[j]
		cnt += 1
	if cnt == 0:
		return Vector2i(sx[i], sy[i])
	var dep := sd / cnt
	return Vector2i(dep if u.team == 0 else W - dep, sy2 / cnt)

## 血比例比較：hp_a/max_a < hp_b/max_b（交叉相乘，不用浮點）；同比例再比平手鍵。
func _ratio_less(hpa: int, ma: int, d2a: int, a: Unit, hpb: int, mb: int, d2b: int, b: Unit) -> bool:
	var l := hpa * mb
	var r := hpb * ma
	if l != r:
		return l < r
	return _tie_less(d2a, a, d2b, b)

## 醫者補血（④）：冷卻每 tick 倒數；到 0 時選 3 格內（④ 位置）、沒滿血、不是自己的活著友軍裡血比例最低的（血量用 ① 快照）。
## 沒有可補的對象就不消耗冷卻；被暈不補。所有醫者從同一份快照選，彼此不影響。
func _try_heal(i: int, sh: PackedInt64Array, heals: Array) -> void:
	var u := units[i]
	# 先扣再判斷（Codex 實作審查 #4：原本扣到 0 的那 tick 直接返回，每次都多等 1 tick）
	if u.hcd > 0:
		u.hcd -= 1
	if u.hcd > 0 or u.stun > 0:
		return
	var best := -1
	var bd2 := 0
	for j in units.size():
		var a := units[j]
		if j == i or not a.alive or a.team != u.team or sh[j] >= a.max_hp:
			continue
		var d2 := M.dist2(u.x, u.y, a.x, a.y)
		if d2 > D.HEAL_RANGE * D.HEAL_RANGE:
			continue
		if best == -1 or _ratio_less(sh[j], a.max_hp, d2, a, sh[best], units[best].max_hp, bd2, units[best]):
			best = j
			bd2 = d2
	if best == -1:
		return
	var ha: int = maxi(1, D.HEAL_AMT * atk_pct[D.MEDIC] / 100)   # 沙盒：醫者攻擊倍率也套在補血量
	var amt := ha if not frenzy else ha / 2
	# 平手鍵在 ④ 就存好（距離、列、深度、部署格），⑤ 的擊退不會改到記功歸屬（Codex 實作審查 #5）
	heals.append([i, best, amt, bd2, u.y, u.x if u.team == 0 else W - u.x, u.slot])
	u.hcd = D.HEAL_CD

## ⑤ 補血：傷害已經扣完；血 ≤0 的照死不補。同一隻被多個醫者選中只吃最大的一筆，記功給（量大→平手鍵）的那個醫者。
## 這一 tick 死掉的醫者，已經發出的補血仍然有效（同時結算）。
func _apply_heals(heals: Array) -> void:
	var by_t := {}
	for h in heals:
		var t: int = h[1]
		if not by_t.has(t):
			by_t[t] = h
			continue
		var cur: Array = by_t[t]
		if h[2] > cur[2] or (h[2] == cur[2] and _heal_key_less(h, cur)):
			by_t[t] = h
	var ts := by_t.keys()
	ts.sort()
	for t in ts:
		var h: Array = by_t[t]
		var tg := units[t]
		if not tg.alive or tg.hp <= 0:
			continue
		var real := mini(int(h[2]), tg.max_hp - tg.hp)
		if real <= 0:
			continue
		tg.hp += real
		units[h[0]].heal_done += real
		events.append({"kind": EV.HEAL, "src": units[h[0]].id, "tgt": tg.id, "amt": real, "tags": [EV.HEAL]})

## 破陣中受到的傷害 ×BREACH_VULN（用 ④ 當下的破陣狀態；這一 tick 才被破陣的，下一 tick 起才吃加成）。
static func _vuln(tg, dmg: int) -> int:
	return dmg * D.BREACH_VULN_NUM / D.BREACH_VULN_DEN if tg.breach > 0 else dmg

## 補血記功的平手：距離² → 列 → 深度 → 部署格（都是 ④ 存下來的值）。
static func _heal_key_less(a: Array, b: Array) -> bool:
	for k in [3, 4, 5, 6]:
		if a[k] != b[k]:
			return a[k] < b[k]
	return false

## 爆炸波及：主目標 ④ 位置 0.9 格內、① 快照可見、活著的其他敵人，依平手鍵取前 SPLASH_MAX 隻。
func _splash_victims(ti: int, st: PackedInt64Array, sv: PackedByteArray) -> Array:
	var c := units[ti]
	var cand: Array = []
	for j in units.size():
		if j == ti or sv[j] == 0 or st[j] != st[ti] or not units[j].alive:
			continue
		var d2 := M.dist2(c.x, c.y, units[j].x, units[j].y)
		if d2 <= D.SPLASH_R * D.SPLASH_R:
			cand.append([d2, j])
	cand.sort_custom(func(p, q): return _tie_less(p[0], units[p[1]], q[0], units[q[1]]))
	var out: Array = []
	for k in mini(D.SPLASH_MAX, cand.size()):
		out.append(cand[k][1])
	return out

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
## 騎兵追擊遲滯（第二輪方案 R1）：停著的要超出 reach 才起步；已經在追就追到 reach−CHASE_HYST 才停。
static func cav_chase(chasing: bool, d2: int, reach: int) -> bool:
	var inner := reach - D.CHASE_HYST
	return d2 > reach * reach or (chasing and d2 > inner * inner)

func _flank_waypoint(i: int, t: int) -> Vector2i:
	var u := units[i]
	var tg := units[t]
	if tg.type != D.ARCHER and tg.type != D.MEDIC and tg.type != D.BOMBER:   # 第四輪：繞翼也用在醫者、投彈兵
		u.wp_for = -1
		u.nav = 0
		u.wp_x = -1
		u.wp_y = -1
		return Vector2i(-1, -1)
	if u.wp_for == tg.id:
		# 同一個目標：照狀態走，不會因為離開途經點而回頭（第二輪方案 R1 根因 A）
		if u.nav == 1:
			if M.dist2(u.x, u.y, u.wp_x, u.wp_y) <= D.WP_REACHED * D.WP_REACHED:
				u.nav = 2
				return Vector2i(-1, -1)
			return Vector2i(u.wp_x, u.wp_y)
		return Vector2i(-1, -1)
	# 新目標：重新規劃一次
	u.wp_for = tg.id
	u.nav = 2
	u.wp_x = -1
	u.wp_y = -1
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
	# 上下兩個候選點都先夾在離邊界有餘裕的範圍；夾完之後如果離直線不到 FLANK_DETECT（沒有真的繞開）就不採用
	var lo := EDGE + D.FLANK_EDGE_MARGIN
	var hi := H - EDGE - D.FLANK_EDGE_MARGIN
	var mid_x := u.x + (tg.x - u.x) / 2   # 用差值往 0 截斷，左右鏡像才對稱
	var line_y := u.y + (tg.y - u.y) / 2
	var up_y := clampi(mini(u.y, tg.y) - D.FLANK_OFFSET, lo, hi)
	var dn_y := clampi(maxi(u.y, tg.y) + D.FLANK_OFFSET, lo, hi)
	# 用叉積算候選點到「騎兵→目標」直線的垂直距離（不是只比 y 差），近乎垂直的路線也判得對（Codex R1 審查 #2）
	var cu: int = (mid_x - u.x) * dy - (up_y - u.y) * dx
	var cd: int = (mid_x - u.x) * dy - (dn_y - u.y) * dx
	var need: int = D.FLANK_DETECT * D.FLANK_DETECT * l2
	var up_ok := up_y < line_y and cu * cu >= need
	var dn_ok := dn_y > line_y and cd * cd >= need
	var wy := -1
	if up_ok and (not dn_ok or above <= below):
		wy = up_y
	elif dn_ok:
		wy = dn_y
	if wy < 0:
		return Vector2i(-1, -1)   # 兩側都沒有空間繞：直接追
	u.nav = 1
	events.append({"kind": EV.FLANK, "src": u.id, "tgt": tg.id, "tags": [EV.FLANK]})
	u.wp_x = mid_x
	u.wp_y = wy
	return Vector2i(u.wp_x, u.wp_y)

## 完整狀態指紋：每 tick 依 id 順序寫入固定 35 個 int64 欄位（第四輪加 7 個）。
func _hash_state() -> void:
	var a := PackedInt64Array()
	a.resize(units.size() * 35 + 1)
	a[0] = tick
	var k := 1
	for u in units:
		a[k] = u.x; a[k + 1] = u.y; a[k + 2] = u.hp; a[k + 3] = u.cd; a[k + 4] = u.target
		a[k + 5] = u.fx; a[k + 6] = u.fy; a[k + 7] = u.face_lock; a[k + 8] = u.mx; a[k + 9] = u.my
		a[k + 10] = u.cdx; a[k + 11] = u.cdy; a[k + 12] = u.stealth; a[k + 13] = u.charge; a[k + 14] = u.stun
		a[k + 15] = u.slow; a[k + 16] = u.wp_x; a[k + 17] = u.wp_y; a[k + 18] = u.wp_for; a[k + 19] = 1 if u.alive else 0
		a[k + 20] = u.dmg_dealt; a[k + 21] = u.dmg_taken; a[k + 22] = u.kills; a[k + 23] = u.id; a[k + 24] = u.team; a[k + 25] = u.type
		a[k + 26] = u.nav; a[k + 27] = 1 if u.chasing else 0
		a[k + 28] = u.hcd; a[k + 29] = u.aura; a[k + 30] = u.breach; a[k + 31] = u.bmode; a[k + 32] = u.heal_done; a[k + 33] = u.follow
		a[k + 34] = u.drum_cover
		k += 35
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
	elif tick >= max_ticks:
		var p0 := power(0)
		var p1 := power(1)
		if judge == 2:
			# 讓子：比「剩餘戰力占自己預算」；整數交叉相乘避免截斷（Codex 第一輪）
			var b0: int = budgets[0]
			var b1: int = budgets[1]
			var dlt: int = p0 * b1 - p1 * b0
			if 100 * absi(dlt) < 3 * 1000 * b0 * b1:
				_finish(-1, "時間到・戰力相當")
			elif dlt > 0:
				_finish(0, "時間到・剩餘戰力較高")
			else:
				_finish(1, "時間到・剩餘戰力較高")
		elif absi(p0 - p1) < budget * 30:
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
	var lg: PackedInt64Array = power_log
	if judge == 2:
		# 讓子：用「占自己預算的比例」差，換算到 1000×1000 的尺度
		total = 1000 * 1000
		lg = PackedInt64Array()
		for t in power_log2.size() / 2:
			lg.append(power_log2[2 * t] * 1000 / budgets[0] - power_log2[2 * t + 1] * 1000 / budgets[1])
	var thr := total * 5 / 100
	var lock_thr := total * 20 / 100
	var changes := 0
	var side := 0
	for t in range(100, lg.size()):
		var d: int = lg[t]
		var s := 0
		if d > thr:
			s = 1
		elif d < -thr:
			s = -1
		if s != 0:
			if side != 0 and s != side:
				changes += 1
			side = s
	var lock_t := lg.size()
	var swing := 0
	if winner >= 0:
		var sign := 1 if winner == 0 else -1
		lock_t = 0
		for t in lg.size():
			var lead: int = lg[t] * sign
			if lead < lock_thr:
				lock_t = t + 1
			if -lead > swing:
				swing = -lead
	var ratio := lock_t * 1000 / maxi(1, lg.size())
	return {"lead_changes": changes, "lock_ratio_permille": ratio, "max_swing_pct": swing * 100 / total}
