extends RefCounted
## V1.6 #11 AI 對手人設：6 種性格（ai_style 0～5）各有名號、代表兵種（頭像）、開場／AI 贏／AI 輸三句台詞。
## 只是畫面文字，不影響 AI 怎麼擺。字串鍵：ps_name_N、ps_open_N、ps_win_N、ps_lose_N。
const FACE := [0, 1, 2, 4, 13, 11]   # 劍士、盾兵、弓箭手、刺客、史萊姆、爆爆羊

static func face(style: int) -> int:
	return FACE[clampi(style, 0, FACE.size() - 1)]

## 台詞鍵。moment：open＝開場、win＝AI 贏了、lose＝AI 輸了
static func line_key(style: int, moment: String) -> String:
	return "ps_%s_%d" % [moment, clampi(style, 0, FACE.size() - 1)]
