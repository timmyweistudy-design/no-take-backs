extends RefCounted
## V1.4 #12 多格巨型頭目「巨獸」：只在遠征終點出現。用石魔（F8.GOLEM）當底子，陣型資料 u["boss"]＝1 就變巨獸
## （不新增兵種，所以兵種數值表、奇幻軍的數值摘要都不變）。陣型代碼：NTB6 每隻第 4 個位元組的最高位元。
const HP_MUL := 2          # 生命 ×2（石魔本來就 820）
const ATK_MUL := 1         # 攻擊不加（靠橫掃）
const REACH_ADD := 300
const SPEED_PCT := 80
const SEP_EXTRA := 700     # 碰撞半徑多 0.7 格（以大半徑近似 2×2）
const PART_PCT := 20       # 背甲部位血量＝最大生命 20%
const ARM_PCT := 8         # 前臂部位血量＝最大生命 8%（只有近戰打得到，給小一點才看得到斷臂）
const PLATE_ABSORB := 35   # 背甲還在：每次受傷有 35% 打在背甲上
const ARM_SHARE := 50      # 前臂還在：近戰打來的一半打在前臂上
const SWEEP_R := 2100      # 橫掃半徑（石魔拍地 1.5 格 → 巨獸 2.1 格）
const SWEEP_MUL := 2       # 橫掃傷害 ×2
const DRAW_SCALE := 1.75   # 畫面放大倍率
const BUDGET_CUT := 42     # 有巨獸的那一站敵方少 42 金（取代首領 +20，再扣 22）：試算 16 場隨機陣勝 4（沒巨獸、150 金時勝 7）
