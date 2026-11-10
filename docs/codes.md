# 代碼相容表（V1.0.0 M16）

玩家能複製、貼上的代碼都是 `前綴.內容.檢查碼`。**舊前綴永遠要能解**（鐵則：舊場次位元組不變）；新機制一律開新前綴，不改舊格式。「代碼」頁一鍵貼上靠 `game_menus.gd` 的 `code_kind` 辨識；測試 `test_code_table_v100` 釘住下表。

| 前綴 | 種類（`code_kind`） | 內容 | 什麼時候產生 | 解碼位置 |
|---|---|---|---|---|
| NTB1 | army | 格子陣型（舊 10 種） | V1.0 起 | `core/army.gd` |
| NTB5 | army | 陣型＋新兵（第四輪） | 用到新兵時 | `core/army.gd` |
| NTB6 | army | 陣型＋奇幻兵／貼紙（第 4 位元組）／巨獸位元 | 用到奇幻兵、遠征貼紙時 | `core/army.gd` |
| NTB2 | battle | 對戰（兩軍＋種子） | 第一版重播碼 | `game/battle_code.gd` |
| NTB3 | battle | 對戰＋規則 | 自訂規則局 | `game/battle_code.gd` |
| NTB4 | battle | 對戰（新兵；可帶規則） | 用到新兵時 | `game/battle_code.gd` |
| NTB7 | battle | 對戰＋手動技能施放紀錄（`c`） | 開手動技能時 | `game/battle_code.gd` |
| NTBR1～NTBR6 | rules | 規則碼：1 基本、2 部署（間距、縱深、全場）、3 新兵卡池、4 地圖、5 手動技能、6 相鄰陣法 | 依用到的規則欄位選最舊能表達的版本 | `core/ruleset.gd` |
| NTC1 | challenge | 挑戰碼（陣型丟給朋友打，全場規則不適用） | V9 | `game_menus.gd` |
| NTP1 | workshop | 工坊殘局碼（作者解＋敵陣） | V1.1 | `game/workshop.gd` |
| NTP2 | workshop | 接力殘局（改兩隻敵兵傳回去，帶棒次 `n`） | V1.4 | `game/workshop.gd` |
| NTP3 | workshop | 出題台（目標：打贏／斬首／撐住／求和／大勝／護送／完美） | V1.6 | `game/workshop.gd` |
| NTP4 | workshop | 出題台指定目標（`t`）、一陣三考（`g=trio`、`e3`） | V1.6.1 | `game/workshop.gd` |
| NTS1 | settings | 設定碼（匯入前先預覽） | V1.5 | `game_menus.gd` |
| NTQ1 | solution | 殘局最佳解（關卡 id＋玩家擺的兵；排序同實驗簿：星→剩餘→花費） | 1.1.0（分享頁「複製我的最佳解碼」） | `game/solution_code.gd` |
| NTW1 | waves | 車輪戰整場（三波的對戰碼） | V1.5.1 | `game_playroom.gd` |

## 匯入時的共同規則
- 先驗長度上限、前綴、檢查碼，再解 base64／JSON，再逐欄驗型別與範圍；任何一欄不對整個碼不收。
- 工坊類（NTP*）匯入時重跑作者解，有運算期限（`workshop.gd` `SOLVE_MS`，V1.0.0 M15），超過回「作者解跑太久」。
- 試玩版只收試玩版範圍內的兵種與地圖（`_demo_ok`）。
- 網路來的陣型（排行榜下載）另有自己的打包格式：格子陣版本 1、自由座標陣版本 2（`steam.gd` `pack_army`／`pack_free`），不是玩家看得到的代碼。
