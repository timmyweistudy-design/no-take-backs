《落子無悔》V1.6.1 實作審查，第 2 輪（共三輪）。只讀檔、不改檔、不執行會改東西的指令。
第 1 輪你給了 12 條（coordination/v161-impl/r1-codex.md），修法與裁決在 coordination/v161-impl/ledger.md「實作審查第 1 輪」，對應 commit f1ec183。之後又改了：三考 20 組＋sol3／單組門檻（data/trio.json、tools/gen/trio_star_forge.gd、trio_stars.gd）、裂隙排除組合與 Rift.VER=2（v16_rift.gd）、eff_games、版本號 1.6.1。完整差異：git diff 694446c..HEAD。
完整統一檢查已過（4880 項、FINGERPRINT 不變）。
請：
1. 逐條確認第 1 輪 12 條是否真的修好（附檔名:行號），沒修好或修出新問題的指出。
2. 檢查第 1 輪之後新增的改動有沒有新錯（特別是 Rift.VER 升版對既有 rift_best 紀錄、練習場、規則碼；trio.json 單組門檻的 s2／s3 與 stars() 判定；eff_games 起點與清除）。
3. 最多 8 條必改，每條：檔名:行號、問題、重現、建議。
繁體中文，1500 字以內。最後一行：結論：可／有條件／不可。
