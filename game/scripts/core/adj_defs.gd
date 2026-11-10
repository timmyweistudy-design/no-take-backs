extends RefCounted
## V1.6 #22 相鄰陣法（娛樂規則，rules.adj）：開戰當下，同隊兩隻距離 ≤ 1.05 格（格子模式＝上下左右相鄰）的指定組合，
## 前者拿小加成（整數百分比）。只看開戰位置，之後走位不影響；左右鏡像一樣。關的時候完全不跑（舊場次位元組不變）。
const D = preload("res://scripts/core/unit_defs.gd")
const RANGE := 1050
## [拿加成的兵種, 要相鄰的兵種, "atk"／"hp"／"cd", 百分比]（cd＝攻擊間隔縮短，即射速 +8%）
## 取整：加成量＝原值 ×8／100 無條件捨去，至少 1（攻擊、血量加；間隔減，間隔至少 1 tick）
const PAIRS := [
	[D.ARCHER, D.SHIELD, "cd", 108],     # 盾後弓手：射速 +8%（Codex v160-i1 #10：方案寫射速）
	[D.CAVALRY, D.PIKE, "atk", 108],     # 槍騎並進
	[D.SWORD, D.SHIELD, "hp", 108],      # 盾劍互護
	[D.BERSERKER, D.DRUMMER, "atk", 108],  # 鼓聲催狂
]

## units：模擬的兵（有 team、type、x、y、atk、hp、max_hp、summon）。回傳拿到加成的筆數。
static func apply(units: Array) -> int:
	var n := 0
	var r2 := RANGE * RANGE
	for u in units:
		for p in PAIRS:
			if u.type != int(p[0]):
				continue
			var near := false
			for v in units:
				if v != u and v.team == u.team and v.type == int(p[1]) and (v.x - u.x) * (v.x - u.x) + (v.y - u.y) * (v.y - u.y) <= r2:
					near = true
					break
			if not near:
				continue
			n += 1
			# 至少 +1（攻擊力小的兵 ×108% 取整會等於沒加）
			if str(p[2]) == "atk":
				u.atk += maxi(1, u.atk * (int(p[3]) - 100) / 100)
			elif str(p[2]) == "cd":
				u.cd_base = maxi(1, u.cd_base - maxi(1, u.cd_base * (int(p[3]) - 100) / 100))
			else:
				u.hp += maxi(1, u.hp * (int(p[3]) - 100) / 100)
				u.max_hp = u.hp
	return n
