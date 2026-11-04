extends RefCounted
## V9 地圖資料（純資料＋整數）：左半邊的矩形清單，右半邊自動鏡像，所以公平性由建構保證。
## 座標用千分比（x：0＝左邊界、1000＝中線；y：0＝上、1000＝下），依大小換算到 0.5 格的格點。
const Terrain = preload("res://scripts/core/terrain.gd")

const FREE := 0
const BLOCK := 1
const SLOW := 2
const FAST := 3

const SIZES := [[12, 7], [16, 9], [18, 10]]   # 格數：小、中（標準）、大
const STD_SIZE := 1
const SIZE_SUGGEST := [[60, 16, 1200], [100, 24, 1800], [130, 30, 2400]]   # 建議 金、人數、tick

const PLAIN := 0
const RIVER := 1
const FOREST := 2
const ICE := 3
const LAVA := 4
const CANYON := 5

## 後面的矩形蓋掉前面。名稱鍵在 strings.csv：map_<key>。biome 給畫面用。
const MAPS := [
	{"key": "plain", "biome": "grass", "rects": []},
	# 雙橋河谷：中央河流＋上下兩座橋（橋寬 18%）
	{"key": "river", "biome": "river", "rects": [
		[BLOCK, 880, 0, 1000, 170], [BLOCK, 880, 400, 1000, 600], [BLOCK, 880, 830, 1000, 1000],
	]},
	# 林間小徑：零散樹叢分出多條路，中間泥塘
	{"key": "forest", "biome": "forest", "rects_small": [
		[SLOW, 640, 380, 860, 620],
		[BLOCK, 760, 130, 840, 260], [BLOCK, 760, 740, 840, 870], [BLOCK, 920, 430, 1000, 570],
	], "rects": [
		[SLOW, 640, 380, 860, 620],
		[BLOCK, 760, 90, 840, 250], [BLOCK, 920, 280, 1000, 420], [BLOCK, 760, 750, 840, 910], [BLOCK, 920, 580, 1000, 720],
	]},
	# 冰湖雪原：中央冰面快、上下雪地慢；冰面靠我方一端有碎冰，逼人繞行匯流
	{"key": "ice", "biome": "ice", "rects": [
		[SLOW, 460, 0, 1000, 240], [SLOW, 460, 760, 1000, 1000],
		[FAST, 640, 240, 1000, 760],
		[BLOCK, 780, 410, 860, 590],
	]},
	# 熔岩裂谷：岩塊與熔岩分割，中央灰燼減速
	{"key": "lava", "biome": "lava", "rects_small": [
		[SLOW, 800, 320, 1000, 680],
		[BLOCK, 800, 0, 900, 210], [BLOCK, 800, 790, 900, 1000], [BLOCK, 920, 430, 1000, 570],
	], "rects": [
		[SLOW, 800, 320, 1000, 680],
		[BLOCK, 800, 0, 900, 300], [BLOCK, 800, 700, 900, 1000], [BLOCK, 920, 430, 1000, 570],
	]},
	# 古道峽谷：兩座大崖把三線隔開，上下石道長而快，中央沙地短而慢
	{"key": "canyon", "biome": "canyon", "rects": [
		[FAST, 620, 0, 1000, 260], [FAST, 620, 740, 1000, 1000],
		[SLOW, 620, 380, 1000, 620],
		[BLOCK, 720, 260, 1000, 380], [BLOCK, 720, 620, 1000, 740],
	]},
]

static var _cache := {}

static func width(size: int) -> int:
	return int(SIZES[size][0]) * 1000

static func height(size: int) -> int:
	return int(SIZES[size][1]) * 1000

## 回傳 Terrain；平原回 null（平原的場地大小不需要地形）。
static func terrain(map_id: int, size: int):
	if map_id == PLAIN:
		return null
	var k := map_id * 10 + size
	if not _cache.has(k):
		var mp: Dictionary = MAPS[map_id]
		_cache[k] = Terrain.new(mp.get("rects_small", mp["rects"]) if size == 0 else mp["rects"], width(size), height(size))   # 小地圖通道要另外留寬
	return _cache[k]

## 進規則摘要：地形內容一變，舊代碼就會回報不一致。
static func digest(map_id: int, size: int) -> String:
	var t = terrain(map_id, size)
	return "plain" if t == null else t.digest()
