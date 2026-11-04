# 發售前手動驗收（第七輪 O6）

自動化做得到的都在 `tools/check_all.sh`、`tools/layout_check.sh`、`tools/export_check.sh`。下面這些要真人、真機或你的帳號。

## 只有你能做
| 項目 | 怎麼做 | 看什麼 |
|---|---|---|
| Spacewar 測試 | `! "<Godot 4.6.2 exe>" --path "C:\Users\timmy\projects\no-take-backs\game" -- --steam-test=480` | `STEAMTEST` 那一行 `ok:true`；沒開 Steam 要 exit 1 |
| 正式 App 測試 | 同上，把 480 換成 AppID | `missing_achievements` 要是空的 |
| 成就離線補送 | 拔網路達成一個成就 → 連網重開 | Steam 上有解鎖（程式端已用假 Steam 測過） |
| 雲端 | Auto-Cloud 設好後兩台電腦各開一次 | 進度同步；設定不跟著走 |
| Remote Play Together | 邀朋友玩雙人輪流落子 | 對方手把能操作；延遲可接受 |
| Steam Deck | 實機從標題玩到結算一局 | 不用改設定就能全手把操作；字看得清楚；代碼輸入會開鍵盤（`SteamApi.text_input` 還沒實機驗過） |
| Linux | CI 的 export job 已通過（repo 已建）；真機冒煙還沒做 | 開得起來、打完一場 |
| 最低規格機 | 舊筆電跑 `--perf=<json>` | 48 隻穩定 30fps 以上 |

## 第一次真人試玩量三件事
流程在 `docs/playtest/protocol.md`，彙整用 `python3 game/tools/playtest_report.py <資料夾>`。
1. 不提示下，60 秒內看不看得懂金幣與人數上限、擺得出第一排。
2. 打完問「為什麼贏／輸、哪種兵最關鍵」，答得出來嗎。
3. 第二局有沒有針對性換兵種或陣型，前 3 局用了幾種兵和工具。
4. 第八輪：奇幻兵（尤其巫毒、吸塵、沙漏）不看圖鑑看得懂嗎；混戰時巫毒連線、幽靈穿牆、骷髏站起來分得出是誰做的嗎；奇幻軍和王國軍打起來覺得公平嗎（AI 模擬 54.6%，真人手感沒測過）。

## 存檔升降版演練（自動化已涵蓋，發佈前再跑一次）
`godot --headless --path game --script res://tests/run_tests.gd -- --only=save`：v1→v3 遷移、語法對型別錯、未來版鎖定不覆寫、壞主檔隔離、寫入失敗重試、重啟恢復。

## V1.0 新增要真人看的
| 項目 | 看什麼 |
|---|---|
| 走路 | 實際播放時腳有沒有滑、跳步會不會太快或太吵 |
| 音效 | 介面音、腳步、環境音音量是否舒服（都還沒有人聽過） |
| 地圖 | 地形一眼懂不懂、尋路有沒有卡住或很怪 |
| 試煉 | 10 關難度曲線（只有 AI 數字，沒有實玩過） |
| 手把 | 新大廳、禁牌、獎勵頁用手把操作順不順 |
