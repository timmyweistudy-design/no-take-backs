extends SceneTree
## V1.6.1 A3：一陣三考每組的作者解 sol 在預設門檻下拿幾星；拿不到三星就印出要覆寫的 s2／s3（寫回 trio.json 由 --write）。
## 用法（game/ 下）：godot --headless --path . --script res://tools/gen/trio_stars.gd [-- --write]
const Trio = preload("res://scripts/game/v16_trio.gd")

func _init() -> void:
	var write := "--write" in OS.get_cmdline_user_args()
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/trio.json"))
	var changed := false
	for s in d["sets"]:
		s.erase("s2")
		s.erase("s3")
		var res: Array = Trio.results(s, s["sol"])
		var st: int = Trio.stars(s, res)
		var ra: int = Trio.rem_avg(res)
		var sp: int = Trio.spent_pct(s, res)
		print("TRIO %s stars=%d rem_avg=%d spent_pct=%d" % [s["id"], st, ra, sp])
		if st < 3 and st >= 1:
			if ra < Trio.S2:
				s["s2"] = ra
			if sp > Trio.S3:
				s["s3"] = sp
			changed = true
	if write and changed:
		var f := FileAccess.open("res://data/trio.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d, "\t", false))
		print("TRIOSTARS wrote")
	print("TRIOSTARS done")
	quit(0)
