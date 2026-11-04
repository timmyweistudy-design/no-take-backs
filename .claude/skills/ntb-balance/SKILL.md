---
name: ntb-balance
description: 落子無悔改了數值、地形或新增兵種後要驗平衡時用
---
1. 先複製快照：`cp -r game build/e1/`，在快照跑（評估中不能改 battle_sim）。
2. `SHARDS=14 tools/fantasy_eval.sh <army|cheese|core|repl> <輸出檔>`；替換實驗要 `--bases=24 --opp=14`（336 場；112 場雜訊會誤判）。
3. 門檻：替換勝率在舊兵最小 −0.03 到最大 +0.03 之內；怪陣單兵種 ≤0.60；奇幻對王國 45～55%。
4. 改數值後：`golden_v8 --make`、殘局驗證、改圖鑑文字，結果存 `docs/balance-runs/<名稱>`。
