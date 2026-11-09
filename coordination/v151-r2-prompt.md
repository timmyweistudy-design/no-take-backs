《落子無悔》V1.5.1 方案第 2 輪（共 3 輪）。只讀檔、不改檔。
修訂稿：coordination/v151-r1-plan.md。第 1 輪兩方意見：coordination/v151-r1-codex.md、coordination/v151-r1-agy.md。程式在 game/。
請專注在分歧與細節，不要重講同意的部分：
1. B1 手動軍令局遠程同步：(甲) 維持 2 tick 壓縮前搖讓出飛行段；(乙) 手動軍令局緩衝改 4 tick＋前搖 1／飛行 3＋軍令按下 0 毫秒預回饋。請對照 game/scripts/ui/view_buffer.gd、battle/battle_state.gd（proj_phase、atk_timing）、battle_view.gd 的軍令輸入（_cmd_press 附近）實際程式，說明各自的風險（軍令手感、時間軸、重播跳轉、殘局軍令連鎖第 12 章的時序顯示），選一個並給驗收條件。
2. A3 轉身攻擊烘 2 個中繼角：估算圖集多出的格數與記憶體（看 sprite_cache.gd 的頁、格大小、TURN_C、WT_C、攻擊格數），可不可行。
3. A5 近看細節「展開獨立畫布」放在圖鑑哪裡、怎麼不撞版（codex_view.gd 的 CX_LEFT、右欄）；給具體配置。
4. 人時：第 1 輪 Codex 估 178～269、Antigravity 估 21～26，差 10 倍。請依修訂稿逐項給你的估計並說明假設（Claude 的實際速度參考：V1.5.0 主要內容約一個工作日完成，但驗收、三方審查、版面修正占一半時間）。
5. 修訂稿還有哪裡不對或漏了（給檔案:行號）。
繁體中文，2500 字以內。
