extends RefCounted
## 1.3.0 R11 光學偏移登記表（docs/ui-layout-rules.md R11）：格子裡的字預設「墨跡中心＝格子面中心」；
## 視覺上需要刻意偏一點的（例如某些符號）才登記。格式：鍵＝"元件ID|字串"，值＝[dx, dy, 理由, 校準截圖, 審核]。
## 預設空：沒登記的一律 O＝0。禁止全域固定偏移、禁止逐張截圖調值；換字型要重校。
const O := {}

static func of(id: String, s: String) -> Vector2:
	var v = O.get(id + "|" + s, null)
	return Vector2(float(v[0]), float(v[1])) if v != null else Vector2.ZERO
