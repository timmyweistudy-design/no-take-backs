# 平衡報表 2.0
- 數值摘要 `8601039f8888757b`、共 6058 筆、耗時 897 秒

## ① 剋制矩陣（各 60 金；列兵種對行兵種：勝/平/負，括號＝勝方剩餘%）

| | 劍士 | 盾兵 | 弓箭手 | 騎兵 | 刺客 |
|---|---|---|---|---|---|
| 劍士 | — | 2/0/0 (27) | 0/0/2 (15) | 0/0/2 (11) | 2/0/0 (22) |
| 盾兵 | 0/0/2 (27) | — | 2/0/0 (40) | 2/0/0 (20) | 0/0/2 (24) |
| 弓箭手 | 2/0/0 (15) | 0/0/2 (40) | — | 0/0/2 (29) | 2/0/0 (25) |
| 騎兵 | 2/0/0 (11) | 0/0/2 (20) | 2/0/0 (29) | — | 0/0/2 (15) |
| 刺客 | 0/0/2 (22) | 2/0/0 (24) | 0/0/2 (25) | 2/0/0 (15) | — |

剋制成立 **10/10**

## ② 陣型聯賽（訓練池 200 套 × 12 對手 × 交換左右 = 4800 場）

| 指標 | 數值 | 目標 |
|---|---|---|
| 勝方剩餘戰力中位數 | 28.0% | ≤30% |
| 接近局（勝方剩 ≤30%） | 53% | — |
| 碾壓局（勝方剩 >50%） | 17% | <20% |
| 戰鬥秒數中位數 | 37.5 | 35～75 |
| 鎖定時間比中位數 | 0.72 | ≥0.65 理想、<0.4 警示 |
| 有領先交換的場次 | 14% | — |
| 翻盤局（贏家曾落後 ≥15%） | 5% | — |
| 平手 | 1% | — |
| 時間到 | 0% | — |

**競技池**（聯賽勝率前 50% 的陣型彼此對打，1182 場）：勝方剩餘中位數 23.0%、碾壓 9%、秒數中位數 42.1、鎖定時間比 0.91、有領先交換 14%、翻盤局 3%

兵種（依陣中金額比例加權）勝率：劍士 48%、盾兵 60%、弓箭手 51%、騎兵 46%、刺客 45%
訓練池勝率前 5：#67 100%、#88 100%、#165 100%、#11 92%、#50 92%

## ③ 先後手（cap10，400 場，雙方同一個會讀對方的 AI）
先手勝率 **36%**、藍方（左邊）勝率 50%（不含平手 0 場）；每局換人次數中位數 22.0；每方平均花 99 金

## ③ 先後手（snake5，400 場，雙方同一個會讀對方的 AI）
先手勝率 **38%**、藍方（左邊）勝率 50%（不含平手 0 場）；每局換人次數中位數 5.0；每方平均花 96 金

## ③ 先後手（snake5c，400 場，雙方同一個會讀對方的 AI）
先手勝率 **44%**、藍方（左邊）勝率 50%（不含平手 0 場）；每局換人次數中位數 5.0；每方平均花 99 金

## ④ 萬用陣搜尋（16 條爬山，各對 24 個保留陣演化，再對整個保留池 50 套驗證）
| 名次 | 保留池勝率 | 組成（劍/盾/弓/騎/刺 金額） | 代碼 |
|---|---|---|---|
| 1 | 90% | [5, 45, 36, 0, 12] | `NTB1.ARUVBCAEIAMVAxUFIAUlBiAGFQcVABUIFAQUBRQCJAEgAUIEIAcgAkIDBQI.51d7` |
| 2 | 88% | [25, 20, 28, 21, 6] | `NTB1.ARQVBAUDFQUzBCAEFAIgAyAFIAJCBBUHBQAzAyAGMwUgASAHBQIFCAUG.2220` |
| 3 | 86% | [0, 20, 24, 49, 6] | `NTB1.ARIVABUIIAAgCDMIMwQzAjMGFQQgBDMBIAIzByEAIAEVAjMDQgQ.969d` |
| 4 | 82% | [0, 30, 24, 28, 18] | `NTB1.ARMjAxIAMgQhBBEFIAEzADAEEQA0AxUIIAVFAUQEEwQhAxUHQgcgAw.94c2` |
| 5 | 82% | [20, 10, 16, 42, 12] | `NTB1.ARIzACAEMwgzATMGFQQzAiADIAUFAgUGMwMFASAGFQNCB0IEBQU.c274` |

「沒搜到」只代表在這個搜尋預算內沒找到，不等於證明不存在。

## ④-2 反制搜尋（針對搜尋第一名，16 條爬山）
能贏它 ≥60% 的反制陣：**2** 類（依用到的兵種分類）
- 100%　組成 [5, 30, 4, 56, 0]　`NTB1.ARAyAzMBFQAVATMDFQIzBBUDMwUVBBUFMwYzBzMIIAQFBg.95aa`
- 100%　組成 [25, 25, 4, 21, 18]　`NTB1.ARFCAAUEMwAFBhUBBQcCCEIEFABCAhQIFAIFAjMBIAQzCBUD.7d4c`
- 100%　組成 [25, 15, 20, 14, 24]　`NTB1.ARMCBwUDAQUgByABJQJCAhAFMQYVB0IEFAQgCAUFMwFCAyAEQgUFBA.9f5d`
→ 至少兩類反制存在，不算萬用陣（剋制循環成立）。

## ⑤ 離線反制庫
| 原型 | 最佳反制勝率 | 代碼 |
|---|---|---|
| 均衡軍 | 100% | `NTB1.ARMzAEIABQAFAQUCBQMVBAUFIAAzATMCBQYzAxUHBQggASACBAAgAw.7b65` |
| 鐵壁弓陣 | 100% | `NTB1.ARIFBBUDFQUVAhUGFQEVByAEMwQgAxUAMwMzBTMCIAUVCDMGBAQ.3c9b` |
| 鐵騎突擊 | 100% | `NTB1.ARZCBEIDIAQgAyAFIAIgBkIFIAEFBCAHIAAgCCEEQgIhAyEFQgYhAgUDIQYhAQ.4693` |
| 暗影刺殺 | 100% | `NTB1.ARZCBEIDIAQgAyAFIAIgBkIFIAEFBCAHIAAgCCEEQgIhAyEFQgYhAgUDIQYhAQ.4693` |
| 劍海 | 100% | `NTB1.ARIFBBUDFQUVAhUGFQEVByAEMwQgAxUAMwMzBTMCIAUVCDMGBAQ.3c9b` |
| 騎射混編 | 100% | `NTB1.ARIFBBUDFQUVAhUGFQEVByAEMwQgAxUAMwMzBTMCIAUVCDMGBAQ.3c9b` |

## 紅線
- ✓ 全過

## 警示（列入調查）
- ⚠ cap10 先手勝率 36%（>55% 或 <45% 列入調查）
- ⚠ snake5 先手勝率 38%（>55% 或 <45% 列入調查）
- ⚠ snake5c 先手勝率 44%（>55% 或 <45% 列入調查）
