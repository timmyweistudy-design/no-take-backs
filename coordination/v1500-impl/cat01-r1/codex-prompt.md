你是《落子無悔》(Godot 4.6.2) 1.5.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 1 批（P0：驗收契約與基線＋1.4.0 先修）：規劃 coordination/v1500-impl/cat01-plan.md；方案 docs/2026-11-14-v1.5.0-plan.md §12、§13、§17；差異 coordination/v1500-impl/cat01-r1/diff.patch（含新檔 game/tools/art_baseline.py、game/tools/run_chain.sh；基線檔 docs/ui-art-baseline.json 是 1.3.0 在 LAYOUT_FIXED=1 下拍的）。
重點：①固定時鐘美感基線：art_baseline.py 的比對語意（逐畫面×組、新畫面不算失敗）是否會漏、layout_check.sh 結尾 RC 的改法有沒有吞掉原本的失敗碼；②1.4.0 退步的修法：茶漬／焦痕改成地面層 GROUND_FX（畫在兵之下）——簡化介面、跳轉、重播、截圖、擺陣是否誤畫或漏畫；③輸入閘門新增 _held（開頁前按住的輸入，轉場開始時列入要吃掉）與 _trans_skip_t（跳過那一幀的其他按下也吃）：會不會吃掉不該吃的（例如用 Enter 開頁的那顆鍵、按住拖曳音量木軌、長按觸控、手把連發）、失焦清除是否足夠；④100 組輸入矩陣測試 test_input_matrix_v150 的判準是否真的驗到「零穿透、零卡鎖」，有沒有假通過；⑤run_chain.sh：程序群、setsid、--stop 會殺所有 Windows Godot（含別的鏈）、run 檔競態。
附行號。最多 6 條必改，600 字內。最後一行「結論：可／有條件／不可」。
