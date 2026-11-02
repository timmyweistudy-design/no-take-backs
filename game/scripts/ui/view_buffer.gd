extends RefCounted
## 展示緩衝（第二輪方案 R5、§3）：戰鬥畫面固定比模擬晚 DELAY 個 tick。
## 模擬先跑，每個 tick 存一份「畫面需要的狀態」快照＋事件；畫面依展示時鐘一格一格播。
## 這樣命中事件在畫面上發生前 DELAY 個 tick 就知道了，可以先演前搖；
## 血量、死亡、音效、HUD、跳字全部讀同一個延後的快照，所以一起延後，不會只有動作延後。
## 純演出：模擬本身的計算、結果、指紋完全不受影響。

const DELAY := 2

class VUnit:
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
	var fx: int
	var fy: int
	var mx: int
	var my: int
	var charge: int
	var target: int
	var breach: int            # 第四輪：被破陣剩幾 tick
	var aura: int              # 第四輪：在鼓手光環內
	var bmode: int             # 第四輪：投彈兵模式

var units: Array = []          # 跟 sim.units 同順序
var tick := 0
var rally := [false, false]
var frenzy := false
var events: Array = []         # 這一格（畫面上剛發生）的事件
var finished := false          # 畫面已經播到模擬的最後一 tick
var budget := 100
var _power := [0, 0]
var _alive := [0, 0]
var _by_id := {}
var queue: Array = []          # 還沒播的快照（模擬已經跑到、畫面還沒到）

## 把模擬當下的狀態存成一份快照。
static func capture(sim) -> Dictionary:
	var us: Array = []
	for u in sim.units:
		us.append([u.id, u.team, u.type, u.x, u.y, u.hp, u.max_hp, u.alive, u.stealth, u.stun, u.fx, u.fy, u.mx, u.my, u.charge, u.target, u.breach, u.aura, u.bmode])
	return {"tick": sim.tick, "units": us, "events": sim.events.duplicate(true), "rally": sim.rally.duplicate(),
		"frenzy": sim.frenzy, "finished": sim.finished, "power": [sim.power(0), sim.power(1)],
		"alive": [sim.alive_count(0), sim.alive_count(1)]}

func _init(sim = null) -> void:
	if sim != null:
		budget = sim.budget
		apply(capture(sim))
		events = []

func apply(fr: Dictionary) -> void:
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
		v.alive = a[7]; v.stealth = a[8]; v.stun = a[9]; v.fx = a[10]; v.fy = a[11]; v.mx = a[12]; v.my = a[13]
		v.charge = a[14]; v.target = a[15]
		v.breach = a[16] if a.size() > 16 else 0
		v.aura = a[17] if a.size() > 17 else 0
		v.bmode = a[18] if a.size() > 18 else 0
		_by_id[v.id] = v
	tick = fr["tick"]
	events = fr["events"]
	rally = fr["rally"]
	frenzy = fr["frenzy"]
	finished = fr["finished"]
	_power = fr["power"]
	_alive = fr["alive"]

func power(t: int) -> int:
	return _power[t]

func alive_count(t: int) -> int:
	return _alive[t]

func unit_by_id(id: int):
	return _by_id.get(id)

## 模擬往前跑，直到緩衝裡有 DELAY 份還沒播的快照（或模擬結束）。回傳這次新加的快照，給前搖預告用。
func pump(sim) -> Array:
	var added: Array = []
	while queue.size() < DELAY and not sim.finished:
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
