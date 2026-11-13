extends SceneTree
## 1.3.0 第 2 大類：路線 A（淺 3D 桌面＋Sprite3D 立牌）切片的量測（開發用，不進遊戲）。
## 一張 16×9 盤面（平面＋牆塊方塊）、桌面、一盞方向光（陰影開）、三隻 Sprite3D 立牌，正交鏡頭偏離俯視 20°。
## 量：每幀時間（p50／p95／p99／>33ms 比例）、貼圖與靜態記憶體、建場時間；和「同一個視窗只畫 2D 盤面」的基準比。
## 用法（game/ 下）：$GODOT --path . --resolution 1280x800 -s tools/cam_slice.gd -- --mode=3d|2d --out=<絕對路徑.json>
const FRAMES := 900

var mode := "3d"
var out := ""
var t0 := 0
var times: Array = []
var last := 0
var n := 0
var build_ms := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
	DisplayServer.window_set_position(Vector2i(-3000, 40))   # 移到畫面外，不搶焦點
	var t := Time.get_ticks_msec()
	if mode == "3d":
		_build_3d()
	else:
		_build_2d()
	build_ms = Time.get_ticks_msec() - t
	last = Time.get_ticks_usec()

func _build_2d() -> void:
	var n2 := Node2D.new()
	n2.set_script(preload("res://tools/cam_slice_2d.gd"))
	root.add_child(n2)

func _build_3d() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 800)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tr := TextureRect.new()
	tr.size = Vector2(1280, 800)
	root.add_child(vp)
	root.add_child(tr)
	tr.texture = vp.get_texture()
	var w := Node3D.new()
	vp.add_child(w)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.0
	cam.rotation_degrees = Vector3(-70.0, 0.0, 0.0)   # 偏離俯視 20°
	cam.position = Vector3(8.0, 12.0, 4.5 + 12.0 * tan(deg_to_rad(20.0)))
	w.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -45.0, 0.0)   # 左上 45°
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.86, 0.68)   # 約 3200K
	w.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.4, 0.36)
	w.add_child(env)
	var desk := MeshInstance3D.new()
	desk.mesh = PlaneMesh.new()
	(desk.mesh as PlaneMesh).size = Vector2(30, 20)
	desk.position = Vector3(8, -0.3, 4.5)
	desk.material_override = _mat(Color(0.36, 0.24, 0.15))
	w.add_child(desk)
	var board := MeshInstance3D.new()
	board.mesh = BoxMesh.new()
	(board.mesh as BoxMesh).size = Vector3(16.6, 0.3, 9.6)
	board.position = Vector3(8, -0.15, 4.5)
	board.material_override = _mat(Color(0.45, 0.62, 0.3))
	w.add_child(board)
	for i in 14:   # 牆塊：中線兩側兩排（約一張峽谷圖的擋路格數）
		var b := MeshInstance3D.new()
		b.mesh = BoxMesh.new()
		(b.mesh as BoxMesh).size = Vector3(0.96, 0.35, 0.96)
		b.position = Vector3(6.5 + (i % 2) * 3.0, 0.175, 0.5 + float(i / 2))
		b.material_override = _mat(Color(0.42, 0.26, 0.16))
		w.add_child(b)
	var ic: Texture2D = load("res://icon.svg")
	for k in 3:
		var s := Sprite3D.new()
		s.texture = ic
		s.pixel_size = 0.006
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.shaded = false
		s.position = Vector3(3.0 + k * 4.0, 0.4, 4.5)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		w.add_child(s)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func _process(_d: float) -> bool:
	var now := Time.get_ticks_usec()
	if n > 60:   # 暖機 60 幀不算
		times.append((now - last) / 1000.0)
	last = now
	n += 1
	if n >= FRAMES + 60:
		times.sort()
		var q := func(p: float) -> float: return times[clampi(int(p * times.size()), 0, times.size() - 1)]
		var slow := times.filter(func(x): return x > 33.33).size()
		var r := {"mode": mode, "frames": times.size(), "p50": q.call(0.5), "p95": q.call(0.95), "p99": q.call(0.99), "over33_pct": 100.0 * slow / times.size(),
			"tex_mib": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, "static_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			"build_ms": build_ms, "gpu": RenderingServer.get_video_adapter_name()}
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(r))
		f.close()
		print("CAMSLICE ", JSON.stringify(r))
		quit(0)
	return false
