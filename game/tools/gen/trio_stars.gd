extends SceneTree
## V1.6.1 A3：一陣三考每組的三星解 sol3（沒有就用作者解 sol）在現行判定（總和比、交叉相乘，不截斷）下拿幾星。
## --write：拿不到三星的組，把單組門檻設成 sol3 剛好達到的值（s2＝剩餘平均往下取整、s3＝花費% 往上取整），寫回 trio.json。
## 用法（game/ 下）：godot --headless --path . --script res://tools/gen/trio_stars.gd [-- --write]
const Trio = preload("res://scripts/game/v16_trio.gd")

func _init() -> void:
	var write := "--write" in OS.get_cmdline_user_args()
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/trio.json"))
	var changed := false
	for s in d["sets"]:
		var sol: Array = s.get("sol3", s["sol"])
		var res: Array = Trio.results(s, sol)
		var st: int = Trio.stars(s, res)
		var rsum := 0
		for r in res:
			rsum += int(r["rem"])
		var sp: int = int(res[0]["spent"])
		var bud: int = maxi(1, int(s["budget"]))
		print("TRIO %s stars=%d rem_sum=%d spent=%d/%d s2=%s s3=%s" % [s["id"], st, rsum, sp, bud, str(s.get("s2", "-")), str(s.get("s3", "-"))])
		if st >= 1 and st < 3 and write:
			if rsum < Trio.s2_of(s) * 3:
				s["s2"] = rsum / 3
			if sp * 100 > Trio.s3_of(s) * bud:
				s["s3"] = ceili(sp * 100.0 / bud)
			changed = true
	if write and changed:
		var f := FileAccess.open("res://data/trio.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d, "\t", false))
		f.close()
		print("TRIOSTARS wrote")
	print("TRIOSTARS done")
	quit(0)
