extends RefCounted
## V1.4 #9 木座貼紙：貼在單隻兵木座底下的小能力。存在陣型資料 u["st"]（1～6），陣型代碼走 NTB6 每隻的第 4 個位元組。
## 沒貼紙的陣型完全照舊（舊對戰碼、重播、FINGERPRINT 不變）；有貼紙時模擬雜湊多一段 "st"。
const NONE := 0
const CHARGE := 1   # 開局衝鋒：開戰前 3 秒移速 +50%
const BLAST := 2    # 倒下自爆：倒下時對 1.3 格內的敵人造成傷害
const WARD := 3     # 護符：第一次受到的傷害無效
const FROST := 4    # 寒霜：攻擊會讓目標減速
const TOUGH := 5    # 鐵皮：生命 +20%
const SWIFT := 6    # 迅捷：攻擊間隔 −15%
const COUNT := 6

const CHARGE_TICKS := 60
const CHARGE_PCT := 150
const BLAST_R := 1300
const BLAST_DMG := 30
const TOUGH_PCT := 120
const SWIFT_PCT := 85

const ICONS := ["", "fast", "skull", "shield", "slow", "heart", "speed"]
const COLORS := ["#000000", "#e07a2c", "#b3261e", "#d4a017", "#4f9fd8", "#6a8f3a", "#8a5cc4"]

static func valid(st: int) -> bool:
	return st >= 1 and st <= COUNT
