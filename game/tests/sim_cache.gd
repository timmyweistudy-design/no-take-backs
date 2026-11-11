extends RefCounted
## 1.2.0 §14.3：「重算作者解」類測試的模擬快取（只給測試用；遊戲本身不用）。
## 鍵＝check.py 算好的核心雜湊（NTB_SIM_KEY：scripts/core/**、puzzles.gd、引擎版本）＋這一場的完整輸入（關卡資料、擺法、軍令）。
## 值＝結果摘要。防漏：
##  ・確定性與金標準測試不用這個（永遠實算）；
##  ・每次命中隨機 5% 重算比對（每次跑抽到的不同，累積起來每個鍵都會被驗到），不一致 → 回傳 {"cache_mismatch": true}，呼叫端要判失敗；
##  ・沒設 NTB_SIM_CACHE_DIR、或 NTB_SIM_CACHE=0（check.py --no-cache／發版）就完全不用快取。

static func _dir() -> String:
	if OS.get_environment("NTB_SIM_CACHE") == "0":
		return ""
	return OS.get_environment("NTB_SIM_CACHE_DIR")

static func _key(kind: String, payload: Variant) -> String:
	return (OS.get_environment("NTB_SIM_KEY") + "|v" + str(FORMAT) + "|" + kind + "|" + JSON.stringify(payload)).sha256_text()

const FORMAT := 1   # 快取內容格式版本（改了值的內容就加一，舊檔自動失效；Codex cat01 #4）
static var _rng: RandomNumberGenerator = null

static var hits := 0
static var misses := 0
static var verified := 0

## 通用：fn 是實算的函式（回傳可 JSON 化的 Dictionary）。
static func cached(kind: String, payload: Variant, fn: Callable) -> Dictionary:
	var d := _dir()
	if d == "" or OS.get_environment("NTB_SIM_KEY") == "":
		return fn.call()
	var k := _key(kind, payload)
	var path := d.path_join(k + ".json")
	if FileAccess.file_exists(path):
		var got = JSON.parse_string(FileAccess.get_file_as_string(path))
		if got is Dictionary:
			hits += 1
			if _rng == null:
				_rng = RandomNumberGenerator.new()
				_rng.randomize()   # 每次命中隨機抽 5%（不是固定的那 1/20 個鍵；Codex cat01 #4）
			if _rng.randf() < 0.05:
				verified += 1
				var fresh: Dictionary = fn.call()
				if JSON.stringify(JSON.parse_string(JSON.stringify(fresh))) != JSON.stringify(got):   # 走一次 JSON 再比（整數讀回來是 float）
					return {"cache_mismatch": true, "fresh": fresh, "cached": got}
				return fresh
			return got
	misses += 1
	var res: Dictionary = fn.call()
	DirAccess.make_dir_recursive_absolute(d)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(res))
		f.close()
	return res

## PZ.play 的快取版（三星解驗證）。
static func pz_play(PZ, pz: Dictionary, units: Array, plan: Array) -> Dictionary:
	return cached("pz_play", [pz, units, plan], func():
		var r: Dictionary = PZ.play(pz, units, plan)
		var out := {}
		for k in r:
			if r[k] is int or r[k] is float or r[k] is String or r[k] is bool:
				out[k] = r[k]
		return out)
