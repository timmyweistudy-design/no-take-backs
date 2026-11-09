extends RefCounted
## 展示緩衝（第二輪方案 R5、§3）：戰鬥畫面固定比模擬晚 DELAY 個 tick。
## 模擬先跑，每個 tick 存一份「畫面需要的狀態」快照＋事件；畫面依展示時鐘一格一格播。
## 這樣命中事件在畫面上發生前 DELAY 個 tick 就知道了，可以先演前搖；
## 血量、死亡、音效、HUD、跳字全部讀同一個延後的快照，所以一起延後，不會只有動作延後。
## 純演出：模擬本身的計算、結果、指紋完全不受影響。

const DELAY := 2            # 前搖長度（tick）；也是有手動軍令時的緩衝長度
const DELAY_LONG := 8       # V1.5：沒有手動軍令的對局緩衝 8 tick，讓遠程「出手→飛行→命中」都在命中前演完
var delay := DELAY

class VUnit:
	var hidden := false
	var link := -1
	var windup := 0
	var guard := 0
	var summon := false
	var id: int
	var team: int
	var type: int
	var x: int
	var y: int
	var hp: int
	var max_hp: int
	var alive: bool
	var stealth: int
	var stun: int
	var shield := 0
	var haste_t := 0
	var fx: int
	var fy: int
	var mx: int
	var my: int
	var charge: int
	var target: int
	var breach: int            # 第四輪：被破陣剩幾 tick
	var aura: int              # 第四輪：在鼓手光環內
	var bmode: int             # 第四輪：投彈兵模式
	var st := 0                # V1.4 #9 貼紙
	var ward := false
	var boss := false          # V1.4 #12 巨獸與部位
	var arm_hp := 0
	var plate_hp := 0

var units: Array = []          # 跟 sim.units 同順序
var tick := 0
var rally := [false, false]
var frenzy := false
var events: Array = []         # 這一格（畫面上剛發生）的事件
var finished := false          # 畫面已經播到模擬的最後一 tick
var budget := 100
var budgets := [100, 100]      # 第五輪：兩邊預算（讓子時不同；舊判定時兩格都＝藍方預算）
var max_ticks := 1800          # 第五輪：這一局的長度（一局時間可調）

func budget_of(t: int) -> int:
	return int(budgets[t])
var zones: Array = []
var _power := [0, 0]
var _alive := [0, 0]
var _by_id := {}
var queue: Array = []          # 還沒播的快照（模擬已經跑到、畫面還沒到）
var cmd_snap: Array = []       # V1.5.1：[cmd_left, cmd_ready]（畫面這一格當下）

## 把模擬當下的狀態存成一份快照。
static func capture(sim) -> Dictionary:
	var us: Array = []
	for u in sim.units:
		us.append([u.id, u.team, u.type, u.x, u.y, u.hp, u.max_hp, u.alive, u.stealth, u.stun, u.fx, u.fy, u.mx, u.my, u.charge, u.target, u.breach, u.aura, u.bmode, 1 if u.hidden else 0, u.link, u.windup, u.guard, u.summon, u.st, 1 if u.ward else 0, 1 if u.boss else 0, u.arm_hp, u.plate_hp, u.shield, u.haste_t])
	var cmd: Array = []
	if bool(sim.get("cmd_on")):
		cmd = [sim.cmd_left.duplicate(true), sim.cmd_ready.duplicate(true)]   # V1.5.1：軍令欄照畫面時間顯示（長緩衝時不提早跳）
	return {"cmd": cmd, "tick": sim.tick, "units": us, "events": sim.events.duplicate(true), "rally": sim.rally.duplicate(),
		"frenzy": sim.frenzy, "finished": sim.finished, "power": [sim.power(0), sim.power(1)],
		"alive": [sim.alive_count(0), sim.alive_count(1)], "zones": sim.zones.duplicate()}

func _init(sim = null) -> void:
	if sim != null:
		budget = sim.budget
		# 手動軍令要即時：維持短緩衝。V1.5.1 B1b：照紀錄施放（殘局第 12 章、軍令局重播）沒有即時輸入，用長緩衝讓遠程完整飛行
		delay = DELAY if (bool(sim.get("cmd_on")) and not bool(sim.get("cmd_scripted"))) else DELAY_LONG
		budgets = sim.budgets.duplicate()
		max_ticks = sim.max_ticks
		apply(capture(sim))
		events = []

func apply(fr: Dictionary) -> void:
	cmd_snap = fr.get("cmd", [])
	var us: Array = fr["units"]
	if units.size() != us.size():
		units.clear()
		_by_id.clear()
		for i in us.size():
			var v := VUnit.new()
			units.append(v)
	for i in us.size():
		var a: Array = us[i]
		var v: VUnit = units[i]
		v.id = a[0]; v.team = a[1]; v.type = a[2]; v.x = a[3]; v.y = a[4]; v.hp = a[5]; v.max_hp = a[6]
		v.shield = a[a.size() - 2]; v.haste_t = a[a.size() - 1]
		v.alive = a[7]; v.stealth = a[8]; v.stun = a[9]; v.fx = a[10]; v.fy = a[11]; v.mx = a[12]; v.my = a[13]
		v.charge = a[14]; v.target = a[15]
		v.breach = a[16] if a.size() > 16 else 0
		v.aura = a[17] if a.size() > 17 else 0
		v.bmode = a[18] if a.size() > 18 else 0
		v.hidden = a[19] == 1 if a.size() > 19 else false
		v.link = a[20] if a.size() > 20 else -1
		v.windup = a[21] if a.size() > 21 else 0
		v.guard = a[22] if a.size() > 22 else 0
		v.summon = a[23] if a.size() > 23 else false
		if a.size() > 30:
			v.st = a[24]; v.ward = a[25] == 1; v.boss = a[26] == 1; v.arm_hp = a[27]; v.plate_hp = a[28]
		_by_id[v.id] = v
	tick = fr["tick"]
	events = fr["events"]
	rally = fr["rally"]
	frenzy = fr["frenzy"]
	finished = fr["finished"]
	_power = fr["power"]
	_alive = fr["alive"]
	zones = fr.get("zones", [])

func power(t: int) -> int:
	return _power[t]

func alive_count(t: int) -> int:
	return _alive[t]

func unit_by_id(id: int):
	return _by_id.get(id)

## 模擬往前跑，直到緩衝裡有 DELAY 份還沒播的快照（或模擬結束）。回傳這次新加的快照，給前搖預告用。
func pump(sim) -> Array:
	var added: Array = []
	while queue.size() < delay and not sim.finished:
		sim.step()
		var fr := capture(sim)
		queue.append(fr)
		added.append(fr)
	return added

## 畫面前進一格；沒有可播的就回傳 false。
func advance() -> bool:
	if queue.is_empty():
		return false
	apply(queue.pop_front())
	return true
