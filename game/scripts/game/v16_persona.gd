extends RefCounted
## V1.6 #11 AI 對手人設：6 種性格（ai_style 0～5）各有名號、代表兵種（頭像）、開場／AI 贏／AI 輸三句台詞。
## 字串鍵：ps_name_N、ps_open_N、ps_win_N、ps_lose_N。
## V1.6.1 A11：招牌陣——普通難度的一般對 AI，每種性格有兩套愛用的 AI 模板，SIG_PCT% 的機率用（用另一顆亂數，不動原本的抽籤順序）。
## 每日、試煉、裂隙、挑戰碼、困難、簡單都不套。卡池用不了那套就照舊。
const FACE := [0, 1, 2, 4, 13, 11]   # 劍士、盾兵、弓箭手、刺客、史萊姆、爆爆羊

static func face(style: int) -> int:
	return FACE[clampi(style, 0, FACE.size() - 1)]

## 台詞鍵。moment：open＝開場、win＝AI 贏了、lose＝AI 輸了
static func line_key(style: int, moment: String) -> String:
	return "ps_%s_%d" % [moment, clampi(style, 0, FACE.size() - 1)]

const SIG := [[4, 0], [6, 8], [1, 5], [3, 10], [11, 13], [14, 7]]   # 劍海／均衡、槍盾方陣／醫療鐵壁、鐵壁弓陣／騎射、暗影刺殺／破陣、黏黏／亡靈、吸塵爆破／砲擊
const SIG_PCT := 40

## 這一場要不要用招牌陣：回傳模板編號或 -1。seed＝這場 AI 用的種子（決定性，可重現）。
static func signature(style: int, seed: int, ok_fn: Callable) -> int:
	var g := RandomNumberGenerator.new()
	g.seed = seed ^ 0x5151
	if g.randi_range(0, 99) >= SIG_PCT:
		return -1
	var lst: Array = SIG[clampi(style, 0, SIG.size() - 1)]
	var t := int(lst[g.randi_range(0, lst.size() - 1)])
	return t if ok_fn.call(t) else -1

static func fav(style: int) -> int:
	return int(SIG[clampi(style, 0, SIG.size() - 1)][0])
