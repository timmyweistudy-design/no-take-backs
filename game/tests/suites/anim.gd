extends "res://tests/test_base.gd"
## 角色動畫（V9 P2）：腳踩地不滑、被推與被吸的姿勢正確。
const Gait = preload("res://scripts/ui/units/gait.gd")

class _U:
	var id := 1
	var type := 0
	var team := 0
	var alive := true
	var x := 1000
	var y := 1000
	var stun := 0
	var fx := 1000
	var mx := 0
	var my := 0

class _V:
	var units: Array = []
	var finished := false

## 踩地的腳在世界座標不動：腳往後的速度要剛好抵銷身體往前。
func test_gait_v9() -> void:
	var scale := 0.92
	var worst := 0.0
	var who := -1
	var wide: Array = []
	for t in Gait.T:
		var k: int = Gait.kind(t)
		if k == Gait.ROOT or k == Gait.HOP or k == Gait.FLOAT:
			continue
		var cyc: float = Gait.cycle_px(t, scale)
		var n := 200
		var prev := 0.0
		var has := false
		for i in n:
			var ph := 0.0001 + i * TAU / n
			var ft: Array = Gait.feet(t, ph)
			if Gait.planted(t, ph):
				var body := ph / TAU * cyc
				var world: float = body + float(ft[0]) * scale
				if has:
					var r := absf(world - prev) / (cyc / n)
					if r > worst:
						worst = r
						who = t
				prev = world
				has = true
			else:
				has = false
		if float(Gait.T[t][1]) < 8.0:
			wide.append(t)
	ok(worst <= 0.1, "腳滑比：踩地時腳的世界速度 ÷ 身體速度 ≤ 0.1（最差 %.3f，兵種 %d）" % [worst, who])
	ok(wide.is_empty(), "每種會走路的兵步長都夠大", str(wide))
	# 上半身起伏不影響腳；踩地的腳高度是 0
	var low := true
	for t2 in [0, 1, 19, 21]:
		for i2 in 16:
			var ph2 := 0.0001 + i2 * TAU / 16
			if Gait.planted(t2, ph2) and absf(float(Gait.feet(t2, ph2)[1])) > 0.001:
				low = false
	ok(low, "踩地的腳貼地，沒有浮空")
	# 羊、寶箱怪才會整隻跳；走路的兵不離地
	ok(Gait.air(0, 1.3) == 0.0 and Gait.air(11, 1.3) > 0.0 and Gait.air(12, 1.3) > 0.0, "只有跳奔的兵整隻離地")
	ok(Gait.air(13, 0.0001) < 0.01, "史萊姆落地那一格貼地")
	# 專屬姿勢
	ok(Gait.ph(Gait.POSE_DRAG) == 0.0 and Gait.feet(0, Gait.POSE_DRAG)[0] > 0.0, "拖行姿勢腳在身前")
	ok(Gait.body_xf(0, Gait.POSE_DRAG).get_rotation() < -0.1, "拖行姿勢身體後仰")
	ok(Gait.T.size() == 22, "22 種都有步態資料")

## 驅動：實際位移才走路；被擊退、暈眩不算走路；停步會收腳。
func test_gait_driver_v9() -> void:
	var bv = BV.new()
	var v := _V.new()
	var u := _U.new()
	v.units = [u]
	bv.view = v
	bv._gait_reset()
	bv.prev_pos[u.id] = Vector2(1000, 1000)
	bv._gait_tick(false)
	ok(bv._walk_of(u, 1.0) == 0.0, "沒有位移就是站著")
	for i in 3:
		bv.prev_pos[u.id] = Vector2(u.x, u.y)
		u.x += 60
		bv._gait_tick(false)
	var w0: float = bv._walk_of(u, 1.0)
	ok(w0 > 0.0, "有位移才走路")
	bv.prev_pos[u.id] = Vector2(u.x, u.y)
	u.x += 60
	bv._gait_tick(false)
	ok(absf(bv._walk_of(u, 1.0) - w0 - 60.0 * 64.0 / 1000.0 / Gait.cycle_px(0, 0.92) * TAU) < 0.001, "相位前進量正比於位移")
	# 被推（mx＝0 但有位移）也算小碎步
	ok(u.mx == 0 and bv._walk_of(u, 1.0) > 0.0, "被推開時也有腳步（不會站姿平移）")
	# 擊退
	bv.prev_pos[u.id] = Vector2(u.x, u.y)
	u.x -= 800
	bv._gait_tick(false)
	ok(bv._walk_of(u, 1.0) == Gait.POSE_DRAG, "被擊退切拖行姿勢")
	bv._gait_frame(0.5)
	ok(bv._walk_of(u, 1.0) != Gait.POSE_DRAG, "拖行姿勢會結束")
	# 暈眩
	u.stun = 10
	ok(bv._walk_of(u, 1.0) == Gait.POSE_DAZE, "暈眩有專屬姿勢")
	u.stun = 0
	# 停步：最多收腳 3 tick
	bv.gait_on[u.id] = true
	bv.gait_land[u.id] = 3
	for k in 5:
		bv.prev_pos[u.id] = Vector2(u.x, u.y)
		bv._gait_tick(false)
	ok(not bv.gait_on[u.id], "停步後幾 tick 內站定")
	# 轉身有過場
	u.fx = -1000
	bv.face_now[u.id] = 1.0
	bv._gait_frame(0.05)
	var f1: float = bv._face_of(u)
	ok(f1 < 1.0 and f1 > -1.0, "轉身不是瞬間翻面")
	bv.free()
