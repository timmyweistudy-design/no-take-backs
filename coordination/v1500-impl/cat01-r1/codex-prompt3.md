你是《落子無悔》1.5.0 實作的程式審查（第 3 輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 1 批。前兩輪 codex.md、codex2.md（都不可）。新差異 coordination/v1500-impl/cat01-r1/diff3.patch（含新檔 art_baseline.py、run_chain.sh 全文）。
改法：①art_baseline check：空輸出失敗；這輪有拍到的畫面×組、基線有棋子卻沒有美感資料＝「探針消失」失敗；②失焦呼叫 _trans_reset_input（清 _held、_rstick、trans_eat、兩個搖桿鎖）；拔手把同時清 _held 的該裝置與右搖桿鎖；③右搖桿：轉場中推過死區＝跳過並鎖到回中（trans_rstick_eat）；開頁前就推著（_rstick 平常也記）在 _trans_begin 鎖；④矩陣測試：副作用改量命令佇列＋圖鑑捲動＋觸控手指；拔手把不補放開；轉場後要真的有效果（按住跨轉場除外，設計如此）；每種來源下一幀再操作一次要有效果；⑤run_chain：mkdir 原子鎖＋鎖內 owner PID（拿到鎖立刻寫）、每輪獨立紀錄夾、--stop 只停 Linux 程序群與「這條鏈開始之後啟動的」Windows Godot 並確認退出。
請逐條確認，只列仍未解決的必改（最多 5 條、≤500 字）。最後一行「結論：可／有條件／不可」。
第 2 輪後：右搖桿記兩軸、兩軸都回中才解鎖；拔手把清 _rstick；矩陣測試在按下當下量副作用（含觸控手指）、轉場中也核對手指、只豁免 hold；run_chain 回收舊鎖用 reclaim 鎖序列化、沒有 owner 的鎖要 ≥10 秒才算舊、Windows 起點用精確 ISO 時間（不倒退）、查詢失敗（含 powershell 錯誤）即報錯不當成已退出。
