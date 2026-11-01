唯讀複查結果：1～3 的主要修正成立，但 Steam 自測與假綠燈仍有缺口。

- **嚴重｜自測流程不是唯讀。** `main.gd:113–117` 先載入玩家存檔，再呼叫 `SteamApi.init()`；`steam.gd:36–40` 隨即補送成就並執行 `storeStats()`，空成就清單也會呼叫。`self_test()` 本體雖未設定成就，`steam.gd:73` 還會執行 `inputInit()`。應讓測試初始化明確禁止補送，並移除輸入初始化，才能宣稱唯讀。

- **中｜初始化參數順序有版本相容風險。** `steam.gd:32` 使用 `steamInitEx(false, app_id)`；[官方原始碼](https://raw.githubusercontent.com/GodotSteam/GodotSteam/9a3480ff1bdbc5064f5a53dda8341b5263ea5c09/godotsteam.cpp) 的綁定順序是 `(app_id, embed_callbacks)`。依此介面，480 並未傳入 App ID。須核對隨附擴充版本的實際綁定，不能把尚未跑過的 480 測試視為已可用。

- **中｜Steam 自測會假綠燈。** `main.gd:117–118` 只印結果就以 0 結束；沒有 singleton、初始化失敗、App ID 錯誤或成就讀取失敗，都不會使測試失敗。`steam.gd:71` 的 `our_id_rejected` 也只是字串標籤，沒有判定預期結果。

- **中｜報表摘要驗證仍有漏網。** `balance_report.py:85–87` 只檢查摘要集合大小；所有資料都缺少 `digest` 時，集合是 `{None}`，照樣通過。本輪以全記憶體模擬重現 exit 0。新增的模式白名單、分片檔集合檢查（`:48–56`）本身正確，但完整性尚不能結案。

- **低｜膠囊輸出失敗仍報成功。** `main.gd:1026–1028` 忽略 `save_png()` 回傳值；路徑不存在或無寫入權限時，仍印出 `CAPSULE` 並正常退出。

鏡頭修正正確：`art.gd:32、41` 使用 `base * local` 並恢復 base，`main.gd:943、956` 正確設定／重設。`unit_defs.gd:95–101` 先轉 String 再排序，解決頂層名稱排序問題；目前常數內容未見新增確定性風險。`main.gd:920–921` 的偏移僅作用於畫面。

沒有 singleton，或初始化回傳非零 status 字典時，`steam.gd:30–35、50–59、76–78` 可安全走本機成就與空回呼路徑。判詞與單兵 MVP 口徑亦一致。

本環境 Godot 啟動即 signal 11，未能重現 51/51；未啟動 Spacewar，未修改檔案。既有核心測試也未涵蓋上述 Steam 流程。

這批可否結案：不可。