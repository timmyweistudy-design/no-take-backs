extends RefCounted
## 兵種開放（第十一輪）：不靠場數解鎖，正式版一開始 20 種全部能用。
## 試玩版是版本內容的差異：舊 7 種＋爆爆羊。純函式。

const D = preload("res://scripts/core/unit_defs.gd")

const DEMO_MAX := 7
const DEMO_SHOWCASE := 11      # 試玩版多開爆爆羊當賣點（非連號，所以不能只看 DEMO_MAX）

## 這個版本能用的兵種遮罩。
static func mask(demo := false) -> int:
	if demo:
		return ((1 << DEMO_MAX) - 1) | (1 << DEMO_SHOWCASE)
	return (1 << D.total()) - 1

static func available(t: int, demo := false) -> bool:
	return (mask(demo) >> t) & 1 == 1

## 沒有規則的模式開放舊兵前幾種。classic＝設定成經典 5 種（教學、殘局由關卡決定，不看這個）。
static func ntypes_for(mode_kind: String, classic: bool, demo := false) -> int:
	if classic and (mode_kind == "duel" or mode_kind == "ai"):
		return D.CLASSIC
	return DEMO_MAX if demo else D.COUNT
