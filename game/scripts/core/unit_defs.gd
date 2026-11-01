extends RefCounted
## 五兵種數值（原型版，全部整數）。
## 單位：距離＝千分之一格（1000＝一格）；時間＝tick（1/20 秒）；速度＝千分之一格／tick。
## 數值照企劃 §3.2 草案，之後由平衡工具調整。

enum { SWORD, SHIELD, ARCHER, CAVALRY, ASSASSIN }

const COUNT := 5
const NAMES := ["劍士", "盾兵", "弓箭手", "騎兵", "刺客"]
const BLURB := [
	"破盾、被刺客打會反擊",
	"正面擋箭、頂住衝鋒、嘲諷近戰",
	"遠程拋射、優先射現形刺客",
	"直衝 3 格後重擊、繞過盾兵找弓手",
	"開場潛行、背刺×2、絆馬",
]

# reach＝攻擊距離（中心到中心）
const STATS := [
	{"cost": 4, "hp": 100, "atk": 12, "cd": 20, "reach": 700, "speed": 60},   # 劍士
	{"cost": 5, "hp": 180, "atk": 6, "cd": 24, "reach": 700, "speed": 45},    # 盾兵
	{"cost": 4, "hp": 60, "atk": 10, "cd": 28, "reach": 6000, "speed": 50},   # 弓箭手
	{"cost": 7, "hp": 140, "atk": 14, "cd": 22, "reach": 750, "speed": 120},  # 騎兵
	{"cost": 6, "hp": 70, "atk": 20, "cd": 16, "reach": 700, "speed": 90},    # 刺客
]

const STEALTH_TICKS := 60      # 刺客開場潛行
const CHARGE_NEED := 3000      # 騎兵直行 3 格才算衝鋒
const STUN_TICKS := 20
const SLOW_TICKS := 20
const TAUNT_RANGE := 2000      # 盾兵嘲諷 2 格內近戰
const KNOCKBACK := 500

static func cost(t: int) -> int:
	return STATS[t]["cost"]

static func is_melee(t: int) -> bool:
	return t != ARCHER

static func cheapest() -> int:
	var c := 999
	for s in STATS:
		c = mini(c, s["cost"])
	return c
