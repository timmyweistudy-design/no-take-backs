extends SceneTree
## 載入檢查（第三輪 T1）：res://scripts、res://tools、res://tests 底下每一個 .gd 都要能載入、能編譯。
## 有任何一個失敗就 exit 1。腳本有語法錯誤時，相依它的測試可能會「靜靜略過」，所以要先單獨檢查。
func _init() -> void:
	var bad: Array = []
	var n := 0
	for root in ["res://scripts", "res://tools", "res://tests"]:
		for path in _walk(root):
			n += 1
			var sc = load(path)
			if sc == null or not (sc is Script) or not sc.can_instantiate():
				bad.append(path)
	print("LOADALL %d 個腳本，失敗 %d：%s" % [n, bad.size(), bad])
	quit(0 if bad.is_empty() and n > 10 else 1)

func _walk(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_walk(dir.path_join(sub)))
	return out
