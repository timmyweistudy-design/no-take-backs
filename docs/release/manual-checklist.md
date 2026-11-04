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
| Linux | 建好 GitHub repo 後看 CI 的 export job；或裝 Linux 匯出模板後跑 `tools/export_check.sh` | `"ok":true` |
| 最低規格機 | 舊筆電跑 `--perf=<json>` | 48 隻穩定 30fps 以上 |

## 第一次真人試玩量三件事
流程在 `docs/playtest/protocol.md`，彙整用 `python3 game/tools/playtest_report.py <資料夾>`。
1. 不提示下，60 秒內看不看得懂金幣與人數上限、擺得出第一排。
2. 打完問「為什麼贏／輸、哪種兵最關鍵」，答得出來嗎。
3. 第二局有沒有針對性換兵種或陣型，前 3 局用了幾種兵和工具。

## 存檔升降版演練（自動化已涵蓋，發佈前再跑一次）
`godot --headless --path game --script res://tests/run_tests.gd -- --only=save`：v1→v3 遷移、語法對型別錯、未來版鎖定不覆寫、壞主檔隔離、寫入失敗重試、重啟恢復。
