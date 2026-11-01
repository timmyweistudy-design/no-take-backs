extends RefCounted
## 事件名稱表（第三輪 A4）：模擬送出的事件種類（kind）與效果標籤（tags）只能用這裡的常數。
## 打錯字原本不會報錯（只是畫面少演一段）；現在測試會檢查每個送出的事件都在表裡。
## 事件只給畫面、圖鑑、統計用，不進指紋。

# 攻擊類（帶 src、tgt、dmg）
const HIT := "hit"
const BREAKER := "breaker"
const ANTICAV := "anticav"
const ARROW := "arrow"
const BLOCKED := "blocked"
const BRACED := "braced"
const CHARGE := "charge"
const BACKSTAB := "backstab"
const COUNTER := "counter"
# 只有標籤、不會單獨當 kind 的效果
const ALERT := "alert"
const HIDE := "hide"
const TRIP := "trip"
# 非攻擊事件
const DEATH := "death"
const ATTRITION := "attrition"
const TAUNT := "taunt"
const REVEAL := "reveal"
const RALLY_ON := "rally_on"
const RALLY_OFF := "rally_off"
const RALLY := "rally"
const FLANK := "flank"

const KINDS := [HIT, BREAKER, ANTICAV, ARROW, BLOCKED, BRACED, CHARGE, BACKSTAB, COUNTER,
	DEATH, ATTRITION, TAUNT, REVEAL, RALLY_ON, RALLY_OFF, FLANK]
const TAGS := [HIT, BREAKER, ANTICAV, ARROW, BLOCKED, BRACED, CHARGE, BACKSTAB, COUNTER,
	ALERT, HIDE, TRIP, TAUNT, REVEAL, RALLY, FLANK]
