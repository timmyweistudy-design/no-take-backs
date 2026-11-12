extends RefCounted
## 1.2.0 §11.11 模式收藏與最近遊玩：記最近點過的主畫面卡片（hub 名、卡片字串鍵），新的在前、去重、最多 MAX。純資料。
const MAX := 3

static func push(list, hub: String, key: String) -> Array:
	var out: Array = [{"h": hub, "k": key}]
	for e in (list if list is Array else []):
		if e is Dictionary and not (str(e.get("h", "")) == hub and str(e.get("k", "")) == key):
			out.append({"h": str(e.get("h", "")), "k": str(e.get("k", ""))})
	return out.slice(0, MAX)

## 只留認得的 hub、型別正確的（存檔壞掉或舊版沒有的卡片不顯示）
static func valid(list, hubs: Array) -> Array:
	var out: Array = []
	for e in (list if list is Array else []):
		if e is Dictionary and e.get("h") is String and e.get("k") is String and str(e["h"]) in hubs and out.size() < MAX:
			out.append(e)
	return out
