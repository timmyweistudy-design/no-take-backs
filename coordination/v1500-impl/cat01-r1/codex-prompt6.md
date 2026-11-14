你是《落子無悔》1.5.0 實作的程式審查（第 6 輪）。只讀。專案根目錄＝目前資料夾。
第 1 批只剩 run_chain 的互斥問題（第 4 輪 coordination/v1500-impl/cat01-r1/codex5.md 兩條）。新版全文 coordination/v1500-impl/cat01-r1/run_chain.r6.sh：改用單一 flock（<名稱>.mutex）包住「啟動登記（看 active→開新輪→子程序登記程序群後才寫 active）」「停止（全程持有）」「子程序收尾（核對 active＝自己的 run ID 才清）」；不再有 mkdir 鎖與回收。
請確認兩條是否解決，並只列仍會造成同名雙開、誤停、誤報停妥的必改（最多 3 條、≤300 字）。最後一行「結論：可／有條件／不可」。
第 5 輪後：子程序登記程序群後等啟動者寫入 active＝自己的 run ID 才開始跑（10 秒內沒等到就不跑、記 aborted_unregistered）；收尾改呼叫 --finish（互斥內核對 active、等最多 10 秒確認程序群除了自己沒有別的程序、這輪開始後啟動的 Windows Godot 都已退出，查詢失敗算殘留；有殘留就記 leftover 並保留 active，要 --stop）；啟動時若上一輪程序群已不在，也先確認沒有殘留才回收。
