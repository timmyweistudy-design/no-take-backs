extends RefCounted
## 戰鬥核心（純邏輯、全整數、確定性）。企劃 §2.3、§2.4、§3.3；優化方案 B1、L1。
## 每 tick 固定五步：①讀快照 ②選目標＋提出移動 ③統一解碰撞 ④產生攻擊 ⑤同時結算。
## 任何一步都只讀「這一步開始前」的狀態，所以不會因為誰先算就佔便宜。
## 禁止新增浮點運算（imath.isqrt 內的浮點估計之後一定用整數修正）。
## 指紋＝每 tick 完整狀態（固定欄位、int64 小端序）串接後的 SHA-256。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const EV = preload("res://scripts/core/events.gd")
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const M = preload("res://scripts/core/imath.gd")
const CMD = preload("res://scripts/core/cmd_defs.gd")

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
	# ── 第八輪（舊場次維持初值，也不進舊指紋）
	var dormant := false       # 還沒生出來的預留單位
	var summon := false        # 戰鬥中生出來的
	var parent := -1           # 預留給誰（索引）
	var sub := 0               # 第幾個子單位
	var raised := false        # 屍體已被復活
	var hidden := false        # 寶箱怪偽裝中
	# ── 第十二輪手動技能（沒開技能時維持初值，也不進指紋）
	var shield := 0
	var shield_t := 0
	var haste_t := 0
	var bite := false          # 下一擊是現身咬
	var exploded := false      # 爆爆羊炸過了
	var link := -1             # 巫毒綁定的目標（索引）
	var link_wait := 0         # 重綁倒數
	var skill_cd := 0          # 大招冷卻（tick）
	var windup := 0            # 大招前搖（tick）
	var used := false          # 每場一次的大招用掉了
	var guard := 0             # 時停減傷剩餘 tick
	var zone := 100            # 這一 tick 的移速百分比（毒圈、碎石區）
	var pull_x := 0            # 被吸塵貓拉的每 tick 位移
	var pull_y := 0
	var pull_t := 0

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
var v8 := false                # 這一場用到第八輪新兵
var fw := W                    # V9：場地大小（標準＝舊常數，舊場次完全相同）
var fh := H
var terrain = null             # V9：地形（null＝平原，舊路徑不碰）
var _nav_wp := {}              # V9：單位索引 → 導航途經點（每 4 tick 重算）
var zones: Array = []          # 碎石區：[x, y, 到期 tick]
var _pending_blast: Array = [] # 半路被打死、下一 tick 才炸的爆爆羊（索引）
var fast := false              # 平衡工具用：不算每 tick 指紋（結果完全一樣，只是沒有指紋）

## rules：第五輪 Ruleset（可省略）。省略或是舊路徑規則時，雜湊位元組、判定都和 1.3.0 完全相同。
# ── 第十二輪手動技能 ──
var cmd_on := false
var cmd_mask := [0, 0]
var cmd_cd := 0
var cmd_power := 100
var cmd_left := [[], []]         # 每隊每種還能用幾次
var cmd_ready := [[], []]        # 每隊每種第幾 tick 起能再用
var cmd_pending: Array = []      # 玩家按了、下一 tick 生效：[隊, 技能]
var cmd_log: Array = []          # 實際施放：[tick, 隊, 技能]；重播靠它
var cmd_script := {}             # 重播用：tick → [[隊, 技能]…]
var cmd_scripted := false
var cmd_auto := [false, false]   # 哪一隊由 AI 決定
var cmd_ai_every := 20
var _cmd_dmg := PackedInt64Array()

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
		fw = rules.field_w()
		fh = rules.field_h()
		terrain = rules.terrain()
		if rules.cmd_on():
			cmd_on = true
			cmd_mask = rules.cmd_mask.duplicate()
			cmd_cd = rules.cmd_cd
			cmd_power = rules.cmd_power
			cmd_ai_every = [40, 20, 10][clampi(rules.ai_level, 0, 2)]
			for tm in 2:
				for i in CMD.COUNT:
					cmd_left[tm].append(rules.cmd_uses if (cmd_mask[tm] >> i) & 1 == 1 else 0)
					cmd_ready[tm].append(CMD.START_TICKS)
	atk_pct.resize(F8.DRAW_TOTAL)
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
				var ox: int = pp.x if a.team == 0 else fw - pp.x
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
		var s: Dictionary = D.stat(u["type"])
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
	for u0 in units:
		if u0.type >= D.COUNT:
			v8 = true
			break
	if v8:
		_v8_setup()
	var hdr := PackedInt64Array([10400 if v8 else D.RULES_VERSION_INT, budget, units.size()])
	_hash.update(hdr.to_byte_array())
	_hash.update((D.digest_v8() if v8 else D.data_digest()).to_utf8_buffer())
	if not legacy:
		_hash.update(rules.sim_digest().to_utf8_buffer())
	elif free:
		_hash.update("free".to_utf8_buffer())   # 自由陣型但沒給規則（工具）：仍和格子陣型區分
	var cmb := [0, 0]
	for u in units:
		if u.alive and D.is_combat(u.type):
			cmb[u.team] += 1
	if mixed:
		_finish(-1, "部署版本不一致")
	elif rules != null and free and rules.fullfield == 1 and (cmb[0] == 0 or cmb[1] == 0):
		# 第六輪 §3.8：雙人全場被封鎖到擺完卻有一方沒有戰鬥兵——不開打；有戰鬥兵的一方勝，雙方都沒有＝和局
		if cmb[0] == 0 and cmb[1] == 0:
			_finish(-1, "雙方都沒有戰鬥兵")
		else:
			_finish(0 if cmb[0] > 0 else 1, "對方沒有戰鬥兵")
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
	if cmd_on:
		_cmd_tick(n)

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
	var sc := sv        # 碰撞用（舊場次就是 sv）
	var sa := sv        # 範圍傷害用（舊場次就是 sv）
	if v8:
		sa = sv.duplicate()
		_v8_pre_tick(n, sx, sy, st, sv)
		sc = sv.duplicate()
		for i in n:
			if units[i].alive and units[i].type == F8.GHOST and not skill_off.has("ghost"):
				sc[i] = 0      # 幽靈穿過所有兵
				sa[i] = 0      # 火罐波及打不到幽靈
	if terrain != null:
		if not v8:
			for u0 in units:
				u0.zone = 100
		_t_pre_tick(n)
	# 每隊還活著的戰鬥兵（非支援）數量：支援兵用來決定「支援模式」還是「自己打」（第四輪）
	var fighters := [0, 0]
	for i in n:
		if units[i].alive and D.is_combat(units[i].type):
			fighters[units[i].team] += 1

	# ② 選目標＋提出移動
	# V1.1 E4：每隊「可被選的敵人」索引先列好（遞增順序，和原本逐一掃描跳過的結果完全一樣），選目標只掃這份
	_foes = [PackedInt32Array(), PackedInt32Array()]
	for j0 in n:
		if sv[j0] != 0:
			_foes[1 - st[j0]].append(j0)
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
			var dest_sx := clampi(bx, EDGE, fw - EDGE)
			var dest_sy := clampi(fp.y, EDGE, fh - EDGE)
			if terrain != null:
				var sw := _t_nav(i, u, dest_sx, dest_sy)
				dest_sx = sw.x
				dest_sy = sw.y
			var sdx := dest_sx - u.x
			var sdy := dest_sy - u.y
			var sl := M.isqrt(sdx * sdx + sdy * sdy)
			if sl > D.SUPPORT_STOP:
				var sstp := mini(u.speed * u.zone / 100, sl)
				u.mx = sdx * sstp / sl
				u.my = sdy * sstp / sl
				nx[i] = u.x + u.mx
				ny[i] = u.y + u.my
			var sf := M.unit1000(fp.x - u.x, fp.y - u.y)
			if sf != Vector2i.ZERO:
				new_fx[i] = sf.x
				new_fy[i] = sf.y
			continue
		if v8 and (u.type == F8.SPORE or u.hidden):
			new_target[i] = -1   # 孢子菇不動；寶箱怪偽裝中不動
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
			dest_x = clampi(tg.x - tg.fx * D.BEHIND_DIST / 1000, EDGE, fw - EDGE)
			dest_y = clampi(tg.y - tg.fy * D.BEHIND_DIST / 1000, EDGE, fh - EDGE)
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
			if terrain != null and (u.type != F8.GHOST or skill_off.has("ghost")):
				var nw := _t_nav(i, u, dest_x, dest_y)
				if nw.x != dest_x or nw.y != dest_y:
					dest_x = nw.x
					dest_y = nw.y
					stop_at = 0
			var dx := dest_x - u.x
			var dy := dest_y - u.y
			var l := M.isqrt(dx * dx + dy * dy)
			var spd := u.speed
			if u.slow > 0:
				spd = spd * D.SLOW_NUM / D.SLOW_DEN
			spd = spd * u.zone / 100
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

	if v8:
		_v8_apply_pull(n, nx, ny)
	# ③ 統一解碰撞（固定兩輪，所有推力加總後一次套用）
	# V1.1 E4：參與碰撞的索引先列好（遞增；配對順序與原本相同，推力是整數加總，結果位元相同）
	var act := PackedInt32Array()
	for i0 in n:
		if sc[i0] != 0:
			act.append(i0)
	var na := act.size()
	for _pass in 2:
		var px := PackedInt64Array()
		var py := PackedInt64Array()
		px.resize(n)
		py.resize(n)
		for a in na:
			var i: int = act[a]
			var xi := nx[i]
			var yi := ny[i]
			for b in range(a + 1, na):
				var j: int = act[b]
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
			nx[i] = clampi(nx[i] + px[i], EDGE, fw - EDGE)
			ny[i] = clampi(ny[i] + py[i], EDGE, fh - EDGE)
	if terrain != null:
		_t_resolve(n, sx, sy, nx, ny)

	if v8:
		for i in n:
			if units[i].type == F8.SPORE:
				nx[i] = sx[i]      # 不會被推動
				ny[i] = sy[i]
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
	var long_stun := {}     # 第八輪：時停（取較大值，不覆寫）
	var knock2: Array = []  # 第八輪：石魔拍地
	var raises: Array = []  # 第八輪：[法師索引, 屍體索引]
	if v8:
		_v8_skills(n, hits, heals, long_stun, knock2, raises, sa)
	for i in n:
		var u := units[i]
		if not u.alive:
			continue
		if u.cd > 0:
			u.cd = maxi(0, u.cd - mini(D.DEC_CAP, dec + rally_bonus[u.team] + D.DRUM_BONUS * u.aura + (CMD.WAR_BONUS if u.haste_t > 0 else 0)))
		if u.type == D.MEDIC and not skill_off.has("heal"):
			_try_heal(i, sh, heals)
		if u.stun > 0 or u.target == -1 or u.cd > 0:
			continue
		var tg := units[u.target]
		if v8 and u.type == F8.SHEEP:
			if M.dist2(u.x, u.y, tg.x, tg.y) <= u.reach * u.reach and not u.exploded:
				_v8_blast(i, false, hits)
			continue
		if u.type == D.BOMBER and u.bmode == 1:
			# 丟彈：④ 重新驗距離（③ 會移動位置），要在 1.5～4.5 格；不符合就取消，不臨時換模式
			var bd2 := M.dist2(u.x, u.y, tg.x, tg.y)
			if bd2 < D.BOMB_MIN * D.BOMB_MIN or bd2 > u.reach * u.reach:
				continue
			hits.append([i, u.target, _vuln(tg, u.atk * D.BOMB_SHIELD_NUM / D.BOMB_SHIELD_DEN if tg.type == D.SHIELD else u.atk), EV.BOMB, [EV.BOMB]])
			for j in ([] if skill_off.has("splash") else _splash_victims(u.target, st, sa)):
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
		if v8:
			if u.bite and not skill_off.has("bite"):
				dmg = F8.BITE_DMG * atk_pct[F8.MIMIC] / 100
				kind = EV.BITE
				tags.append(EV.BITE)
				heals.append([i, i, F8.BITE_HEAL])
			u.bite = false
			if tg.type == F8.GHOST and D.is_melee(u.type) and not skill_off.has("ghost"):
				dmg = dmg * F8.GHOST_MELEE_NUM / F8.GHOST_MELEE_DEN
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
	var voodoo: Array = []
	if v8:
		_v8_voodoo(n, hits, voodoo)
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
			var da: int = a.x if a.team == 0 else fw - a.x
			var db: int = b.x if b.team == 0 else fw - b.x
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
	if cmd_on:
		for i in n:
			if _cmd_dmg[i] > 0:
				dmg_in[i] += _cmd_dmg[i]
				units[i].dmg_taken += _cmd_dmg[i]
				events.append({"kind": EV.CMD_HIT, "tgt": units[i].id, "dmg": _cmd_dmg[i], "tags": [EV.CMD_HIT]})
	if v8:
		# 第八輪：同一 tick 的擊退先加總再夾邊。逐筆夾邊跟順序有關，兩隻石魔把敵人推過邊界時鏡像會歪（Codex 第 3 輪）
		var kx := {}
		var ky := {}
		for kb2 in knock2:
			var v2 := M.unit1000(kb2[1], kb2[2])
			kx[kb2[0]] = int(kx.get(kb2[0], 0)) + v2.x * F8.GOLEM_KNOCK / 1000
			ky[kb2[0]] = int(ky.get(kb2[0], 0)) + v2.y * F8.GOLEM_KNOCK / 1000
		for kb in knock:
			var v3 := M.unit1000(kb[1], kb[2])
			kx[kb[0]] = int(kx.get(kb[0], 0)) + v3.x * D.KNOCKBACK / 1000
			ky[kb[0]] = int(ky.get(kb[0], 0)) + v3.y * D.KNOCKBACK / 1000
		for i in n:
			if kx.has(i):
				var kx0: int = units[i].x
				var ky0: int = units[i].y
				units[i].x = clampi(units[i].x + int(kx[i]), EDGE, fw - EDGE)
				units[i].y = clampi(units[i].y + int(ky[i]), EDGE, fh - EDGE)
				if terrain != null:
					var kp := _t_back(units[i], kx0, ky0, units[i].x, units[i].y)
					units[i].x = kp.x
					units[i].y = kp.y
		knock.clear()
	for kb in knock:
		var v := M.unit1000(kb[1], kb[2])
		var t: Unit = units[kb[0]]
		var tx0: int = t.x
		var ty0: int = t.y
		t.x = clampi(t.x + v.x * D.KNOCKBACK / 1000, EDGE, fw - EDGE)
		t.y = clampi(t.y + v.y * D.KNOCKBACK / 1000, EDGE, fh - EDGE)
		if terrain != null:
			var tp := _t_back(t, tx0, ty0, t.x, t.y)
			t.x = tp.x
			t.y = tp.y
	for i in n:
		var u := units[i]
		if not u.alive:
			continue
		if u.shield > 0:
			var absorbed: int = mini(u.shield, dmg_in[i])
			u.shield -= absorbed
			dmg_in[i] -= absorbed
			u.dmg_taken -= absorbed     # 戰報的承傷只算真的扣血（Codex v12-r1 #4）
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
		if long_stun.has(i):
			u.stun = maxi(u.stun, F8.SPRITE_STUN)
			u.charge = 0
		if u.guard > 0:
			u.guard -= 1
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
			if v8:
				_v8_on_death(i, last_hit[i])
	if v8:
		_v8_post_tick(raises)

	power_log.append(power(0) - power(1))
	power_log2.append(power(0))
	power_log2.append(power(1))
	if not fast:
		_hash_state()
		if v8:
			_hash_v8()
		if cmd_on:
			_hash_cmd()
	_check_end()

# ───────────────────────── 規則細節 ─────────────────────────

## 選目標（企劃 §3.3）：排除潛行 → 弓手警覺 → 盾兵嘲諷（近戰）→ 兵種偏好 → 距離 → 剩血 → 列 → 深度 → 編號。
## 只讀快照陣列，比較全部用整數（不配置陣列）。
var _foes: Array = [PackedInt32Array(), PackedInt32Array()]   # V1.1 E4：這一 tick 每隊可選的敵人（只在 step 的 ② 有效）

func _choose_target(i: int, sx: PackedInt64Array, sy: PackedInt64Array, st: PackedInt64Array,
		sk: PackedInt64Array, sh: PackedInt64Array, sv: PackedByteArray, min_d2 := 0) -> int:
	var my_team: int = st[i]
	var my_type: int = sk[i]
	var ux: int = sx[i]
	var uy: int = sy[i]
	var reach: int = units[i].reach
	var reach2 := reach * reach
	var taunt2 := -1 if skill_off.has("taunt") else D.TAUNT_RANGE * D.TAUNT_RANGE
	var melee := D.is_melee(my_type) and my_type != F8.GHOST   # 幽靈不受嘲諷
	var no_ghost: bool = v8 and (my_type == D.ARCHER or my_type == D.BOMBER) and not skill_off.has("ghost")   # 箭、火罐打不到幽靈
	var best := -1
	var b_rank := 99
	_last_rank = 99
	var b_d2 := 0
	var b_hp := 0
	var b_y := 0
	var b_dep := 0
	var foes: PackedInt32Array = _foes[my_team]
	# V1.1 E4：這種攻擊者最好能給到的優先級。目前最佳已經是這一級時，比它遠的敵人不可能勝出（優先級只會 ≥、距離又較遠），直接跳過
	var min_r := 3
	if my_type == D.ARCHER:
		min_r = 0
	elif melee and taunt2 >= 0:
		min_r = 1
	elif my_type == F8.GHOST or my_type == D.CAVALRY or my_type == D.ASSASSIN:
		min_r = 2
	for j in foes:
		var dx: int = sx[j] - ux
		var dy: int = sy[j] - uy
		var d2 := dx * dx + dy * dy
		if best != -1 and b_rank <= min_r and d2 > b_d2:
			continue
		if d2 < min_d2:
			continue   # 投彈兵丟彈：最短射程內的不選（第四輪）
		var et: int = sk[j]
		if no_ghost and et == F8.GHOST:
			continue
		var rank := 3
		if my_type == F8.GHOST and (et == D.ARCHER or et == D.BOMBER or et == F8.BONE or D.is_support(et)):
			rank = 2   # 幽靈優先打遠程與支援
		if my_type == D.ARCHER and et == D.ASSASSIN and d2 <= reach2:
			rank = 0
		elif rank == 2:
			pass
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
							var dep: int = sx[j] if st[j] == 0 else fw - sx[j]
							if dep >= b_dep:
								continue
		best = j
		b_rank = rank
		b_d2 = d2
		b_hp = sh[j]
		b_y = sy[j]
		b_dep = sx[j] if st[j] == 0 else fw - sx[j]
	_last_rank = b_rank
	return best

## ───────────────────────── 第四輪新兵種 ─────────────────────────

## ───────────────────────── 第八輪新兵 ─────────────────────────

## 開戰前：預留生出來的兵（alive=false、不佔位置、不被選），索引和指紋欄位數固定；生兵絕不會因為沒位置失敗。
func _v8_setup() -> void:
	var base := units.size()
	for i in base:
		var p := units[i]
		var kids := 0
		var kt := -1
		if p.type == F8.SLIME and not skill_off.has("split"):
			kids = F8.SLIME_KIDS
			kt = F8.MINI_SLIME
		elif p.type == F8.BONE and not skill_off.has("raise"):
			kids = F8.BONE_KIDS
			kt = F8.SKELETON
		for k in kids:
			var c := Unit.new()
			var st: Dictionary = D.stat(kt)
			c.id = p.team * 1000 + 600 + i * 4 + k
			c.team = p.team
			c.type = kt
			c.x = p.x
			c.y = p.y
			c.hp = st["hp"]
			c.max_hp = st["hp"]
			c.cost = 0
			c.reach = st["reach"]
			c.speed = st["speed"]
			c.atk = st["atk"]
			c.cd_base = st["cd"]
			c.fx = p.fx
			c.alive = false
			c.dormant = true
			c.summon = true
			c.parent = i
			c.sub = k
			c.slot = p.slot * 8 + k + 1000
			units.append(c)
		if p.type == F8.MIMIC and not skill_off.has("bite"):
			p.hidden = true
		if p.type == F8.BONE or p.type == F8.CAT or p.type == F8.GOLEM:
			p.skill_cd = F8.FIRST_CD
		if p.type == F8.DOLL:
			p.link_wait = 1

## ① 之後：寶箱怪偽裝、現身，毒圈與碎石區的移速，巫毒綁定。只讀快照。
func _v8_pre_tick(n: int, sx: PackedInt64Array, sy: PackedInt64Array, st: PackedInt64Array, sv: PackedByteArray) -> void:
	# 誰還能打（寶箱怪判斷要不要自動現身）：活著、不是孢子菇、不是偽裝中
	var able := [0, 0]
	for i in n:
		var u := units[i]
		if u.alive and u.type != F8.SPORE and not u.hidden:
			able[u.team] += 1
	# 先用這一 tick 開始的狀態決定誰現身，再一起套用（一隻現身不會連帶觸發別隻，鏡像才對稱）
	var opening: Array = []
	for i in n:
		var u := units[i]
		if not u.alive or not u.hidden:
			continue
		var open: bool = able[u.team] == 0
		if not open:
			for j in n:
				if sv[j] == 1 and st[j] != st[i] and not units[j].hidden and M.dist2(sx[i], sy[i], sx[j], sy[j]) <= F8.MIMIC_TRIGGER * F8.MIMIC_TRIGGER:
					open = true
					break
		if open:
			opening.append(i)
		else:
			sv[i] = 0
	for i in opening:
		var u := units[i]
		u.hidden = false
		u.bite = true
		events.append({"kind": EV.MIMIC_OPEN, "src": u.id, "tgt": u.id, "tags": [EV.MIMIC_OPEN]})
	# 先列出活著的孢子菇：沒有菇的場次這段就是空迴圈（最壞情況 100 隻，不能每隻都掃一遍）
	var spores: Array = []
	if not skill_off.has("poison"):
		for j in n:
			if units[j].type == F8.SPORE and units[j].alive:
				spores.append(units[j])
	for i in n:
		var u := units[i]
		u.zone = 100
		if not u.alive:
			continue
		var pct := 100
		for s in spores:
			if s.team != u.team and M.dist2(s.x, s.y, u.x, u.y) <= s.reach * s.reach:
				pct = F8.SPORE_SLOW_PCT
				break
		for z in zones:
			if int(z[3]) != u.team and M.dist2(int(z[0]), int(z[1]), u.x, u.y) <= F8.ROCK_R * F8.ROCK_R:
				pct = mini(pct, F8.ROCK_SLOW_PCT)
				if u.type == D.CAVALRY:
					u.charge = 0
				break
		u.zone = pct
	if skill_off.has("voodoo"):
		return
	for i in n:
		var u := units[i]
		if u.type != F8.DOLL or not u.alive:
			continue
		if u.link >= 0 and not units[u.link].alive:
			u.link = -1
			u.link_wait = F8.DOLL_REBIND
		if u.link < 0:
			if u.link_wait > 0:
				u.link_wait -= 1
			if u.link_wait <= 0:
				u.link = _v8_doll_target(i, sx, sy, st, sv)

## 巫毒綁誰：隊伍前向半平面、同列走廊內最近；同距比 y、再比離自己底線的深度（鏡像不變）；走廊沒人就全場最近。
func _v8_doll_target(i: int, sx: PackedInt64Array, sy: PackedInt64Array, st: PackedInt64Array, sv: PackedByteArray) -> int:
	var dir := 1 if st[i] == 0 else -1
	var best := -1
	var best_lane := false
	var bd := 0
	for j in sx.size():
		if sv[j] == 0 or st[j] == st[i]:
			continue
		var d2 := M.dist2(sx[i], sy[i], sx[j], sy[j])
		var lane: bool = (sx[j] - sx[i]) * dir >= 0 and absi(sy[j] - sy[i]) <= F8.DOLL_LANE
		var better := best == -1
		if not better and lane != best_lane:
			better = lane
		elif not better and lane == best_lane:
			better = _tie_less(d2, units[j], bd, units[best])
		if better:
			best = j
			best_lane = lane
			bd = d2
	return best

## ② 之後：被吸塵貓拉的位移併進移動意圖，再統一解碰撞。
func _v8_apply_pull(n: int, nx: PackedInt64Array, ny: PackedInt64Array) -> void:
	for i in n:
		var u := units[i]
		if u.alive and u.pull_t > 0:
			nx[i] += u.pull_x
			ny[i] += u.pull_y
			u.pull_t -= 1

## ④ 開頭：大招、毒圈、待爆的羊。
func _v8_skills(n: int, hits: Array, heals: Array, long_stun: Dictionary, knock2: Array, raises: Array, sa: PackedByteArray) -> void:
	# 半路被打死的羊，這一 tick 爆
	var pend := _pending_blast
	_pending_blast = []
	for pi in pend:
		_v8_blast(pi[0], true, hits, pi[1])
	# 毒：一隻敵兵一秒只吃一次（算最近那朵菇的）
	if tick % F8.STATS[0]["cd"] == 0 and not skill_off.has("poison"):
		var spi: Array = []
		for i in n:
			if units[i].type == F8.SPORE and units[i].alive:
				spi.append(i)
		if not spi.is_empty():
			for j in n:
				var e := units[j]
				if not e.alive:
					continue
				var best := -1
				var bd := 0
				for i in spi:
					var s := units[i]
					if s.team != e.team:
						var d2 := M.dist2(s.x, s.y, e.x, e.y)
						if d2 <= s.reach * s.reach and (best == -1 or _tie_less(d2, s, bd, units[best])):
							best = i
							bd = d2
				if best != -1:
					hits.append([best, j, units[best].atk, EV.POISON, [EV.POISON]])
	var cats: Array = []
	for i in n:
		var u := units[i]
		if not u.alive:
			continue
		if u.skill_cd > 0:
			u.skill_cd -= 1
		if u.stun > 0:
			u.windup = 0       # 被暈就取消前搖，冷卻不退
			continue
		if u.windup > 0:
			u.windup -= 1
			if u.windup == 0:
				if u.type == F8.CAT:
					cats.append(i)
				else:
					_v8_fire(i, n, long_stun, knock2, raises, hits)
			continue
		match u.type:
			F8.SPRITE:
				if u.used or skill_off.has("timestop"):
					continue
				var low := 0
				for j in n:
					var a := units[j]
					if a.alive and a.team == u.team and a.hp * 100 < a.max_hp * F8.SPRITE_LOW_PCT and M.dist2(u.x, u.y, a.x, a.y) <= F8.SPRITE_R * F8.SPRITE_R:
						low += 1
				if low >= F8.SPRITE_NEED:
					_v8_cast(u, EV.TIMESTOP)   # 前搖被打斷不算用掉
			F8.BONE:
				if u.skill_cd == 0 and not skill_off.has("raise") and _v8_free_kid(i) != -1 and _v8_corpse(i, n) != -1:
					u.skill_cd = F8.BONE_CD
					_v8_cast(u, EV.RAISE)
			F8.CAT:
				if u.skill_cd == 0 and not skill_off.has("vacuum") and _v8_enemy_in(i, n, F8.CAT_R):
					u.skill_cd = F8.CAT_CD
					_v8_cast(u, EV.VACUUM)
			F8.GOLEM:
				if u.skill_cd == 0 and not skill_off.has("stomp") and _v8_enemy_in(i, n, F8.GOLEM_R):
					u.skill_cd = F8.GOLEM_CD
					_v8_cast(u, EV.STOMP)
	if not cats.is_empty():
		_v8_vacuum(n, cats)

func _v8_cast(u: Unit, skill: String) -> void:
	u.windup = F8.WINDUP
	events.append({"kind": EV.CAST, "src": u.id, "skill": skill, "tags": [EV.CAST]})

func _v8_enemy_in(i: int, n: int, r: int) -> bool:
	var u := units[i]
	for j in n:
		var e := units[j]
		if e.alive and e.team != u.team and not e.hidden and e.stealth == 0 and M.dist2(u.x, u.y, e.x, e.y) <= r * r:
			return true
	return false

func _v8_free_kid(i: int) -> int:
	for j in range(i + 1, units.size()):
		var c := units[j]
		if c.parent == i and c.dormant:
			return j
	return -1

## 3 格內最近的我方屍體；生出來的兵、已被復活的、還沒生出來的都不算。
func _v8_corpse(i: int, n: int) -> int:
	var u := units[i]
	var best := -1
	var bd := 0
	for j in n:
		var c := units[j]
		if c.alive or c.dormant or c.summon or c.raised or c.team != u.team:
			continue
		var d2 := M.dist2(u.x, u.y, c.x, c.y)
		if d2 <= F8.BONE_R * F8.BONE_R and (best == -1 or _tie_less(d2, c, bd, units[best])):
			best = j
			bd = d2
	return best

## 前搖結束，放招。
func _v8_fire(i: int, n: int, long_stun: Dictionary, knock2: Array, raises: Array, hits: Array) -> void:
	var u := units[i]
	match u.type:
		F8.SPRITE:
			u.used = true
			for j in n:
				var o := units[j]
				if not o.alive or M.dist2(u.x, u.y, o.x, o.y) > F8.SPRITE_R * F8.SPRITE_R:
					continue
				if o.team == u.team:
					o.guard = F8.SPRITE_GUARD
				elif not o.hidden:
					long_stun[j] = true
			events.append({"kind": EV.TIMESTOP, "src": u.id, "tags": [EV.TIMESTOP]})
		F8.BONE:
			var c := _v8_corpse(i, n)
			if c != -1:
				raises.append([i, c])
		F8.GOLEM:
			for j in n:
				var e2 := units[j]
				if not e2.alive or e2.team == u.team or e2.hidden or M.dist2(u.x, u.y, e2.x, e2.y) > F8.GOLEM_R * F8.GOLEM_R:
					continue
				hits.append([i, j, F8.GOLEM_STOMP * atk_pct[F8.GOLEM] / 100, EV.SPLASH, [EV.SPLASH]])   # 第十二輪：拍地有傷害
				if e2.type != F8.GOLEM and e2.type != F8.SPORE:
					knock2.append([j, e2.x - u.x, e2.y - u.y])
			events.append({"kind": EV.STOMP, "src": u.id, "tags": [EV.STOMP]})

## 這一 tick 放招的吸塵貓：每隻敵兵只被最近的那隻拉（平手鍵鏡像不變，和貓的順序無關）。孢子菇、偽裝中不拉。
func _v8_vacuum(n: int, cats: Array) -> void:
	for c in cats:
		events.append({"kind": EV.VACUUM, "src": units[c].id, "tags": [EV.VACUUM]})
	for j in n:
		var e := units[j]
		if not e.alive or e.hidden or e.type == F8.SPORE or e.pull_t > 0:
			continue
		var best := -1
		var bd := 0
		for c in cats:
			var u := units[c]
			if u.team == e.team or not u.alive:
				continue
			var d2 := M.dist2(u.x, u.y, e.x, e.y)
			if d2 <= F8.CAT_R * F8.CAT_R and (best == -1 or _tie_less(d2, u, bd, units[best])):
				best = c
				bd = d2
		if best == -1:
			continue
		var cat := units[best]
		var dx: int = cat.x - e.x
		var dy: int = cat.y - e.y
		var l := M.isqrt(dx * dx + dy * dy)
		if l <= F8.CAT_STOP:
			continue      # 已經貼身：不拉、不定身，也不會被推開
		var amt := mini(l - F8.CAT_STOP, F8.CAT_PULL)
		if e.type == D.CAVALRY or e.type == F8.GOLEM:
			amt /= 2
		e.pull_t = F8.CAT_PULL_TICKS
		e.stun = maxi(e.stun, F8.CAT_PULL_TICKS + 1)   # 被吸的時候不能出手（放招當 tick 會先扣 1）
		e.pull_x = dx * amt / l / F8.CAT_PULL_TICKS
		e.pull_y = dy * amt / l / F8.CAT_PULL_TICKS

## 爆爆羊爆炸。died＝半路被打死（小範圍、友敵都傷）。同一隻單位一 tick 最多吃 BLAST_CAP 次，敵方的羊優先、再比位置，順序鏡像不變。
func _v8_blast(i: int, died: bool, hits: Array, credit := -1) -> void:
	var u := units[i]
	if u.exploded or skill_off.has("blast"):
		return
	u.exploded = true
	if not died:
		u.hp = 0   # 撞上就沒了（⑤ 判定死亡）
	var r: int = F8.DEATH_BLAST_R if died else F8.BLAST_R
	var dmg: int = u.atk / 2 if died else u.atk
	events.append({"kind": EV.BLAST, "src": u.id, "tgt": u.id, "tags": [EV.BLAST], "small": died})
	for j in units.size():
		var e := units[j]
		if j == i or not e.alive or (not died and e.team == u.team):
			continue
		if M.dist2(u.x, u.y, e.x, e.y) > r * r:
			continue
		var hurt: int = dmg / 2 if e.team == u.team else dmg     # 第十二輪：半路被打死傷友軍減半
		hits.append([credit if credit >= 0 else i, j, hurt, EV.BLAST, [EV.BLAST]])   # 半路被打死的爆炸，傷害與擊殺記給打死它的那一方

## 羊爆上限：把這一 tick 的羊爆整理成每隻最多 BLAST_CAP 次。
func _v8_cap_blasts(hits: Array) -> Array:
	var by_tgt := {}
	var out: Array = []
	for h in hits:
		if h[3] == EV.BLAST:
			if not by_tgt.has(h[1]):
				by_tgt[h[1]] = []
			by_tgt[h[1]].append(h)
		else:
			out.append(h)
	var keys := by_tgt.keys()
	keys.sort()
	for t in keys:
		var lst: Array = by_tgt[t]
		var tt: int = units[t].team
		lst.sort_custom(func(a, b):
			var ua := units[a[0]]
			var ub := units[b[0]]
			var ea: bool = ua.team != tt
			var eb: bool = ub.team != tt
			if ea != eb:
				return ea
			return _tie_less(0, ua, 0, ub))
		for k in mini(F8.BLAST_CAP, lst.size()):
			out.append(lst[k])
	return out

## 巫毒轉傷：娃娃受的傷一半轉給綁定的敵人；轉過去的不再轉、不吃舉盾。時停減傷先算。
func _v8_voodoo(n: int, hits: Array, voodoo: Array) -> void:
	var capped := _v8_cap_blasts(hits)
	hits.clear()
	hits.append_array(capped)
	var incoming := PackedInt64Array()
	incoming.resize(n)
	for h in hits:
		incoming[h[1]] += h[2]
	for i in n:
		var u := units[i]
		if u.guard > 0:
			for h in hits:
				if h[1] == i:
					h[2] = h[2] / 2
	if skill_off.has("voodoo"):
		return
	var extra: Array = []
	for i in n:
		var u := units[i]
		if u.type != F8.DOLL or not u.alive or u.link < 0 or not units[u.link].alive:
			continue
		var total := 0
		for h in hits:
			if h[1] == i:
				var part: int = h[2] / 2
				h[2] -= part
				total += part
		if total > 0:
			extra.append([i, u.link, total, EV.VOODOO, [EV.VOODOO]])
	hits.append_array(extra)

## 單位倒下：史萊姆分裂、石魔留碎石、羊排到下一 tick 爆。
func _v8_on_death(i: int, killer: int) -> void:
	var u := units[i]
	if u.type == F8.SHEEP and not u.exploded:
		_pending_blast.append([i, killer])
	elif u.type == F8.SLIME and not skill_off.has("split"):
		for j in range(i + 1, units.size()):
			var c := units[j]
			if c.parent == i and c.dormant:
				c.dormant = false
				c.alive = true
				c.x = u.x
				c.y = clampi(u.y + (F8.SLIME_OFFSET if c.sub == 0 else -F8.SLIME_OFFSET), EDGE, fh - EDGE)
				if terrain != null and terrain.blocked(c.x, c.y, c.team):
					c.y = u.y     # 裂到牆裡：留在母體位置，碰撞會把它們推開
				c.cd = c.cd_base * 4
				events.append({"kind": EV.SPLIT, "src": c.id, "tgt": c.id, "tags": [EV.SPLIT]})
	elif u.type == F8.GOLEM and not skill_off.has("stomp"):
		zones.append([u.x, u.y, tick + F8.ROCK_TICKS, u.team])
		events.append({"kind": EV.ROCK, "src": u.id, "tgt": u.id, "tags": [EV.ROCK]})

## ⑤ 之後、判定結束之前：骷髏站起來（下一 tick 才行動）、碎石區到期。
func _v8_post_tick(raises: Array) -> void:
	raises.sort_custom(func(a, b): return _tie_less(0, units[a[0]], 0, units[b[0]]))
	for r in raises:
		var m := units[r[0]]
		var c := units[r[1]]
		if not m.alive or c.raised or c.alive:
			continue
		var k := _v8_free_kid(r[0])
		if k == -1:
			continue
		var s := units[k]
		c.raised = true
		s.dormant = false
		s.alive = true
		s.x = c.x
		s.y = c.y
		if terrain != null and terrain.blocked(s.x, s.y, s.team):
			var sf: Vector2i = terrain.free_near(s.x, s.y, s.team)   # 幽靈死在牆裡
			s.x = sf.x
			s.y = sf.y
		s.max_hp = mini(c.max_hp * F8.BONE_HP_PCT / 100, F8.BONE_HP_CAP)
		s.hp = s.max_hp
		s.cd = s.cd_base * 4
		events.append({"kind": EV.RAISE, "src": s.id, "tgt": s.id, "by": m.id, "tags": [EV.RAISE]})
	var live: Array = []
	for z in zones:
		if int(z[2]) > tick:
			live.append(z)
	zones = live

## 新欄位的指紋（只有用到新兵的場次才有）。
## ── 第十二輪手動技能 ──
## 這一隊現在能不能用這一招。
func cmd_can(team: int, s: int) -> bool:
	return cmd_on and not finished and s >= 0 and s < CMD.COUNT and int(cmd_left[team][s]) > 0 and tick >= int(cmd_ready[team][s])

## 玩家按下：下一 tick 生效。重播時不接受。
func cast(team: int, s: int) -> bool:
	if cmd_scripted or not cmd_can(team, s):
		return false
	for p in cmd_pending:
		if p[0] == team and p[1] == s:
			return false
	cmd_pending.append([team, s])
	return true

## 重播：照紀錄在同一 tick 施放，AI 不再自己決定。
func cmd_play(log: Array) -> void:
	cmd_scripted = true
	cmd_script = {}
	for e in log:
		var t := int(e[0])
		if not cmd_script.has(t):
			cmd_script[t] = []
		cmd_script[t].append([int(e[1]), int(e[2])])

func _cmd_tick(n: int) -> void:
	_cmd_dmg.resize(n)
	_cmd_dmg.fill(0)
	for u in units:
		if u.shield_t > 0:
			u.shield_t -= 1
			if u.shield_t == 0:
				u.shield = 0
		if u.haste_t > 0:
			u.haste_t -= 1
	var casts: Array = []
	if cmd_scripted:
		casts = cmd_script.get(tick, [])
	else:
		casts = cmd_pending.duplicate()
		cmd_pending.clear()
		if tick % cmd_ai_every == 0:
			for tm in 2:   # 都先讀這一 tick 開始前的狀態才決定，誰先算不佔便宜
				if cmd_auto[tm]:
					var want := _cmd_ai_pick(tm)
					if want >= 0:
						casts.append([tm, want])
	for c in casts:
		if cmd_can(int(c[0]), int(c[1])):
			_cmd_apply(int(c[0]), int(c[1]))

func _cmd_apply(team: int, s: int) -> void:
	cmd_left[team][s] = int(cmd_left[team][s]) - 1
	cmd_ready[team][s] = tick + cmd_cd
	cmd_log.append([tick, team, s])
	var ev := {"kind": EV.CMD, "team": team, "skill": s}
	match s:
		CMD.AEGIS:
			for u in units:
				if u.alive and u.team == team:
					u.shield = maxi(u.shield, u.max_hp * CMD.scaled(CMD.AEGIS_PCT, cmd_power) / 100)
					u.shield_t = CMD.AEGIS_TICKS
		CMD.WARCRY:
			for u in units:
				if u.alive and u.team == team:
					u.haste_t = CMD.scaled(CMD.WAR_TICKS, cmd_power)
		CMD.HEAL:
			for u in units:
				if u.alive and u.team == team:
					u.hp = mini(u.max_hp, u.hp + u.max_hp * CMD.scaled(CMD.HEAL_PCT, cmd_power) / 100)
		CMD.METEOR:
			var c: Array = _cmd_cluster(team)
			if int(c[0]) > 0:
				ev["x"] = c[1]
				ev["y"] = c[2]
				var r2: int = CMD.METEOR_R * CMD.METEOR_R
				for i in units.size():
					var v := units[i]
					if v.alive and v.team != team and (v.x - c[1]) * (v.x - c[1]) + (v.y - c[2]) * (v.y - c[2]) <= r2:
						_cmd_dmg[i] += CMD.scaled(CMD.METEOR_DMG, cmd_power)
		CMD.FREEZE:
			for u in units:
				if u.alive and u.team != team:
					u.stun = maxi(u.stun, CMD.scaled(CMD.FREEZE_TICKS, cmd_power))
					u.charge = 0
	events.append(ev)

## 敵人最密的位置：[範圍內幾隻, x, y]。平手用鏡像不變的鍵（列小、離自己底線近）。
func _cmd_cluster(team: int) -> Array:
	var best := [0, 0, 0]
	var best_d := 0
	var r2: int = CMD.METEOR_R * CMD.METEOR_R
	for a in units:
		if not a.alive or a.team == team:
			continue
		var cnt := 0
		for b in units:
			if b.alive and b.team != team and (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) <= r2:
				cnt += 1
		var d: int = a.x if team == 0 else fw - a.x
		if cnt > int(best[0]) or (cnt == int(best[0]) and (a.y < int(best[2]) or (a.y == int(best[2]) and d < best_d))):
			best = [cnt, a.x, a.y]
			best_d = d
	return best

## AI 這一 tick 要放哪一招（-1＝不放）。只看戰況，沒有亂數；左右對稱。
func _cmd_ai_pick(team: int) -> int:
	for s in CMD.list_of(int(cmd_mask[team])):
		if cmd_can(team, s) and _cmd_ai_wants(team, s):
			return s
	return -1

func _cmd_ai_wants(team: int, s: int) -> bool:
	var mine := 0
	var contact := 0
	var missing := 0
	var total := 0
	var g2 := 2000 * 2000
	for u in units:
		if not u.alive or u.team != team:
			continue
		mine += 1
		missing += u.max_hp - u.hp
		total += u.max_hp
		for e in units:
			if e.alive and e.team != team and (u.x - e.x) * (u.x - e.x) + (u.y - e.y) * (u.y - e.y) <= g2:
				contact += 1
				break
	if mine == 0:
		return false
	match s:
		CMD.AEGIS, CMD.WARCRY, CMD.FREEZE:
			return contact >= 3 and contact * 2 >= mine
		CMD.HEAL:
			return missing * 100 >= total * 30
		CMD.METEOR:
			return int(_cmd_cluster(team)[0]) >= 4
	return false

func _hash_cmd() -> void:
	var a := PackedInt64Array()
	for u in units:
		a.append_array(PackedInt64Array([u.shield, u.shield_t, u.haste_t]))
	for e in cmd_log:
		a.append_array(PackedInt64Array([int(e[0]), int(e[1]), int(e[2])]))
	_hash.update(a.to_byte_array())

func _hash_v8() -> void:
	var a := PackedInt64Array()
	for u in units:
		a.append_array(PackedInt64Array([1 if u.dormant else 0, 1 if u.raised else 0, 1 if u.hidden else 0, 1 if u.bite else 0, 1 if u.exploded else 0,
			u.link, u.link_wait, u.skill_cd, u.windup, 1 if u.used else 0, u.guard, u.zone, u.pull_x, u.pull_y, u.pull_t, u.max_hp]))
	for z in zones:
		a.append_array(PackedInt64Array([z[0], z[1], z[2], z[3]]))
	_hash.update(a.to_byte_array())

## 平手鍵（鏡像不變、與輸入順序無關）：距離² → 列 → 離自己底線的深度 → 部署格。a 比 b 優先回傳 true。
func _tie_less(d2a: int, a: Unit, d2b: int, b: Unit) -> bool:
	if d2a != d2b:
		return d2a < d2b
	if a.y != b.y:
		return a.y < b.y
	var da: int = a.x if a.team == 0 else fw - a.x
	var db: int = b.x if b.team == 0 else fw - b.x
	if da != db:
		return da < db
	return a.slot < b.slot

## 最近的可見敵人距離²（沒有回傳 -1）。用 ① 快照。
func _nearest_visible_enemy_d2(i: int, sx: PackedInt64Array, sy: PackedInt64Array, st: PackedInt64Array, sv: PackedByteArray) -> int:
	var best := -1
	for j in _foes[st[i]]:
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
		sd += sx[j] if u.team == 0 else fw - sx[j]
		sy2 += sy[j]
		cnt += 1
	if cnt == 0:
		return Vector2i(sx[i], sy[i])
	var dep := sd / cnt
	return Vector2i(dep if u.team == 0 else fw - dep, sy2 / cnt)

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
	heals.append([i, best, amt, bd2, u.y, u.x if u.team == 0 else fw - u.x, u.slot])
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
		var dep: int = a.x if a.team == 0 else fw - a.x
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
	var hi := fh - EDGE - D.FLANK_EDGE_MARGIN
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
	if v8 and not _pending_blast.is_empty() and tick < max_ticks:
		return   # 第八輪：還有羊在下一 tick 才爆，先別判勝負（Codex 第八輪 r1）
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

# ── V9 地形 ──
## 導航：直線走得到就走直線；否則朝導航場的下一點。每 4 tick 重算（不依單位索引錯開，鏡像才一致）。
func _t_nav(i: int, u: Unit, dx: int, dy: int) -> Vector2i:
	if not terrain.has_block:
		return Vector2i(dx, dy)
	if tick % 4 == 1 or not _nav_wp.has(i):
		_nav_wp[i] = terrain.nav_step(u.team, u.x, u.y, dx, dy)
	var w: Vector2i = _nav_wp[i]
	if w.x < 0:
		return Vector2i(dx, dy)
	return w

## 移動結果撞牆：能沿牆滑就滑，不然留在原地。幽靈可穿，但停下時要出牆。
func _t_resolve(n: int, sx: PackedInt64Array, sy: PackedInt64Array, nx: PackedInt64Array, ny: PackedInt64Array) -> void:
	for i in n:
		var u := units[i]
		if not u.alive or u.dormant:
			continue
		if u.type == F8.GHOST and not skill_off.has("ghost"):
			if terrain.blocked(int(nx[i]), int(ny[i]), u.team) and u.mx == 0 and u.my == 0 and u.stun <= 0:
				var f: Vector2i = terrain.free_near(int(nx[i]), int(ny[i]), u.team)
				var ex: int = f.x - int(nx[i])
				var ey: int = f.y - int(ny[i])
				var el := M.isqrt(ex * ex + ey * ey)
				if el > 0:
					nx[i] += ex * mini(u.speed, el) / el
					ny[i] += ey * mini(u.speed, el) / el
			continue
		if terrain.blocked(int(nx[i]), int(ny[i]), u.team):
			if not terrain.blocked(int(nx[i]), int(sy[i]), u.team):
				ny[i] = sy[i]
			elif not terrain.blocked(int(sx[i]), int(ny[i]), u.team):
				nx[i] = sx[i]
			else:
				nx[i] = sx[i]
				ny[i] = sy[i]

## 瞬間位移（擊退）撞牆：從終點往起點退到第一個能站的位置。
func _t_back(u: Unit, x0: int, y0: int, x1: int, y1: int) -> Vector2i:
	if terrain == null or (u.type == F8.GHOST and not skill_off.has("ghost")) or not terrain.blocked(x1, y1, u.team):
		return Vector2i(x1, y1)
	for k in range(1, 5):
		var x: int = x1 + (x0 - x1) * k / 4
		var y: int = y1 + (y0 - y1) * k / 4
		if not terrain.blocked(x, y, u.team):
			return Vector2i(x, y)
	return Vector2i(x0, y0)

## 每 tick 依腳底取樣地形速度：u.zone＝min(地形％, 技能％)；完全沒減速才吃加速。
func _t_pre_tick(n: int) -> void:
	for i in n:
		var u := units[i]
		if not u.alive or u.dormant or u.type == F8.GHOST or u.type == F8.SPRITE:
			continue
		var pct: int = terrain.speed_pct(u.x, u.y, u.team)
		if pct < 100:
			u.zone = mini(u.zone, pct)
		elif pct > 100 and u.zone == 100:
			u.zone = pct
