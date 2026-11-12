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
# 第四輪新兵種
const BOMB := "bomb"           # 投彈兵丟彈主擊
const SPLASH := "splash"       # 爆炸波及
const BONK := "bonk"           # 投彈兵被貼身敲人
const PIKE_BRACE := "pike_brace"   # 長槍兵拒騎
const BREACH := "breach"       # 狂戰士破陣
# 只有標籤、不會單獨當 kind 的效果
const ALERT := "alert"
const HIDE := "hide"
const TRIP := "trip"
# 第十二輪手動技能
const CMD := "cmd"             # 施放（帶 team、skill、x、y）
const CMD_HIT := "cmd_hit"     # 隕石打中（帶 tgt、dmg）
# 非攻擊事件
const DEATH := "death"
const ATTRITION := "attrition"
const TAUNT := "taunt"
const REVEAL := "reveal"
const RALLY_ON := "rally_on"
const RALLY_OFF := "rally_off"
const RALLY := "rally"
const POISON := "poison"       # 第八輪：孢子菇毒傷
const BLAST := "blast"         # 爆爆羊
const BITE := "bite"           # 寶箱怪現身咬
const MIMIC_OPEN := "mimic_open"
const SPLIT := "split"         # 史萊姆分裂
const VOODOO := "voodoo"       # 巫毒轉移的傷害
const CAST := "cast"           # 大招前搖（src、skill）
const TIMESTOP := "timestop"
const RAISE := "raise"
const VACUUM := "vacuum"
const STOMP := "stomp"
const ROCK := "rock"
const FLANK := "flank"
const DRUM := "drum"           # 鼓手一拍（src＝鼓手、n＝鼓舞到幾隻；每秒一次）
const BEAT := "beat"           # 1.2.0 擴充 v1「接拍」：這一擊吃到拍點加成（標籤）
const EXT_FIRE := "ext_fire"   # 1.2.0 擴充 v1「火矢」：小火的傷害（標籤）
const RESCUE := "rescue"       # 1.2.0 擴充 v1「急救契約」：這筆補血是急救（標籤）
const EXT_GUARD := "ext_guard" # 1.2.0 擴充 v1「架盾」：這一發遠程被盾擋成 0（標籤）
const EXT_RIDE := "ext_ride"   # 1.2.0 擴充 v1「迴馬」：騎兵撤一格（事件）
const HEAL := "heal"           # 醫者補血（src＝醫者、tgt＝被補的、amt＝實際補量；沒有 dmg）

const KINDS := [HIT, BREAKER, ANTICAV, ARROW, BLOCKED, BRACED, CHARGE, BACKSTAB, COUNTER, BOMB, SPLASH, BONK, PIKE_BRACE, BREACH, HEAL, DRUM,
	DEATH, ATTRITION, TAUNT, REVEAL, RALLY_ON, RALLY_OFF, FLANK]
const TAGS := [HIT, BREAKER, ANTICAV, ARROW, BLOCKED, BRACED, CHARGE, BACKSTAB, COUNTER, BOMB, SPLASH, BONK, PIKE_BRACE, BREACH, HEAL, DRUM,
	ALERT, HIDE, TRIP, TAUNT, REVEAL, RALLY, FLANK, BEAT, EXT_FIRE, RESCUE, EXT_GUARD, EXT_RIDE]
