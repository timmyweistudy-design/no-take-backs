extends RefCounted
## 步態（V9 P2）：Q 版微跳步。相位由真實位移決定（battle_state._gait_tick），腳踩地時不滑。
## 全部是畫面，不進模擬。走路相位 walk：0＝沒走；POSE_DRAG／POSE_DAZE＝拖行、暈眩兩個專屬姿勢。

const POSE_DRAG := -100.0
const POSE_DAZE := -200.0

enum {BIPED, PAIR, HOP, FLOAT, STOMP, ROOT}

# 兵種 → [步態, 半步長 px（腳在身體座標走多遠）, 上半身起伏 px, 傾身幅度, 手與武器擺幅, 整隻離地 px, 抬腳 px]
const T := {
	0: [BIPED, 17.0, 2.5, 0.06, 0.22, 0.0, 5.0],   # 劍士
	1: [BIPED, 12.0, 1.8, 0.03, 0.08, 0.0, 3.0],   # 盾兵：短步、盾壓前
	2: [BIPED, 15.0, 2.8, 0.06, 0.14, 0.0, 5.0],   # 弓箭手
	3: [PAIR, 24.0, 2.5, 0.09, 0.10, 2.0, 6.0],    # 騎兵：木馬步
	4: [BIPED, 20.0, 1.2, 0.08, 0.25, 0.0, 3.5],   # 刺客：低身快步
	5: [BIPED, 13.0, 1.2, 0.03, 0.08, 0.0, 3.0],   # 長槍兵：壓低重心
	6: [BIPED, 14.0, 3.0, 0.07, 0.20, 0.0, 5.0],   # 投彈兵：小跑
	7: [BIPED, 11.0, 2.0, 0.04, 0.10, 0.0, 2.5],   # 醫者：提袍碎步
	8: [BIPED, 12.0, 3.2, 0.03, 0.10, 0.0, 7.0],   # 鼓手：高抬腿
	9: [BIPED, 20.0, 3.0, 0.09, 0.30, 0.0, 6.0],   # 狂戰士：大步
	10: [ROOT, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],      # 孢子菇
	11: [PAIR, 22.0, 2.0, 0.10, 0.10, 6.0, 5.0],   # 爆爆羊：跳奔
	12: [HOP, 16.0, 0.0, 0.07, 0.0, 7.0, 0.0],     # 寶箱怪：閉蓋貼地跳
	13: [HOP, 14.0, 0.0, 0.0, 0.0, 3.5, 0.0],      # 史萊姆：擠壓彈跳
	14: [FLOAT, 20.0, 0.0, 0.12, 0.20, 5.0, 0.0],  # 幽靈
	15: [BIPED, 11.0, 2.0, 0.14, 0.18, 0.0, 3.5],  # 巫毒娃娃：歪斜搖擺
	16: [FLOAT, 16.0, 0.0, 0.14, 0.10, 5.0, 0.0],  # 沙漏精靈
	17: [BIPED, 11.0, 1.4, 0.05, 0.10, 0.0, 2.5],  # 骷髏法師：拖步
	18: [BIPED, 14.0, 3.0, 0.06, 0.14, 0.0, 5.0],  # 吸塵貓
	19: [STOMP, 18.0, 2.2, 0.09, 0.10, 0.0, 6.0],  # 小石魔：左右重踏
	20: [HOP, 11.0, 0.0, 0.0, 0.0, 2.5, 0.0],      # 小史萊姆
	21: [BIPED, 13.0, 2.5, 0.10, 0.30, 0.0, 4.0],  # 骷髏：喀喀搖擺
}

static func kind(t: int) -> int:
	return int(T[t][0])

static func stride(t: int) -> float:
	return float(T[t][1])

## 真的走路相位；待機與專屬姿勢回 0。
static func ph(walk: float) -> float:
	return walk if walk > -50.0 else 0.0

## 一步週期走多少螢幕 px，用來把位移換成相位。
static func cycle_px(t: int, scale: float) -> float:
	return 2.0 * stride(t) * scale

## 相位（累積世界位移，1000＝1 格；cs＝每格 px）。
static func phase_of(t: int, world: float, cs: float, scale: float, id: int) -> float:
	return world * cs / 1000.0 / cycle_px(t, scale) * TAU + 0.0001 + id * 0.37

## 腳的位移：[遠腳 x, 遠腳抬起, 近腳 x, 近腳抬起]。踩地段往後等速走（抵銷身體前進），騰空段弧線往前。
static func feet(t: int, walk: float) -> Array:
	if walk <= POSE_DAZE + 1.0:
		return [1.0, 0.0, -1.0, 0.0]
	if walk <= POSE_DRAG + 1.0:
		return [7.0, 0.0, 10.0, 0.0]   # 腳在身前被拖著
	if walk == 0.0:
		return [0.0, 0.0, 0.0, 0.0]
	var a := _foot(t, walk)
	var b := _foot(t, walk + PI)
	return [a[0], a[1], b[0], b[1]]

static func _foot(t: int, walk: float) -> Array:
	var u := fposmod(walk, TAU) / TAU
	var s := stride(t)
	var lift := float(T[t][6])
	if u < 0.5:
		return [s * 0.5 - s * (u * 2.0), 0.0]               # 踩地：+s/2 → −s/2
	var v := (u - 0.5) * 2.0
	return [-s * 0.5 + s * v, sin(v * PI) * lift]           # 騰空

static func planted(t: int, walk: float) -> bool:
	return fposmod(walk, TAU) / TAU < 0.5

## 上半身相對腳的轉換：起伏與傾身（腳不跟著動）。
static func body_xf(t: int, walk: float) -> Transform2D:
	if walk <= POSE_DAZE + 1.0:
		return Transform2D(0.10, Vector2(0, 1.5))
	if walk <= POSE_DRAG + 1.0:
		return Transform2D(-0.30, Vector2(2.0, 1.0))
	if walk == 0.0:
		return Transform2D.IDENTITY
	var r: Array = T[t]
	var k: int = r[0]
	if k == HOP or k == FLOAT or k == ROOT:
		return Transform2D(float(r[3]) * sin(walk), Vector2.ZERO)
	var dy := -absf(sin(walk)) * float(r[2]) * 1.3
	var tilt := float(r[3]) * sin(walk)
	if k != STOMP:
		tilt += float(r[3]) * 0.5     # 走路時微微前傾
	return Transform2D(tilt, Vector2(0, dy))

## 整隻離地（跳步、飄浮）。
static func air(t: int, walk: float) -> float:
	if walk == 0.0 or walk < -50.0:
		return 0.0
	var r: Array = T[t]
	if r[0] == FLOAT:
		return float(r[5]) * (0.5 + 0.5 * sin(walk))
	return absf(sin(walk)) * float(r[5])

## 手與武器的擺動（弧度感的比例，−1～1 × 擺幅）。
static func swing(t: int, walk: float) -> float:
	if walk == 0.0 or walk < -50.0:
		return 0.0
	return cos(walk) * float(T[t][4])

## 沒有實際位移資料時（圖鑑小劇場）的相位速度。speed＝每 tick 世界單位。
static func nominal_rate(t: int, speed: float, cs: float, scale: float) -> float:
	var s := speed * 20.0 * cs / 1000.0
	return s / cycle_px(t, scale) * TAU
