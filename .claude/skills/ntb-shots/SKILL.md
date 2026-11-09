---
name: ntb-shots
description: 落子無悔要截圖、看版面或把畫面送審時用
---
1. `LAYOUT_QUICK=1 tools/layout_check.sh "<exe>" build/tmp/layout`：快速 5 組；里程碑跑全部 21 組（四語三字級＋狀態）；`LAYOUT_COMBOS="en:150 ja:150"` 只跑指定組。背景跑時用快照（`build/cg*/game`）。
2. 結論看 `LAYOUT 截圖 N 張、違規 M` 與 `LAYOUT 排版警告 W、宣告例外 E`。排版規則（R1～R10、G）全表：`python3 tools/layout_table.py <輸出夾> --md <檔>`；規則與怎麼寫才會過看 `docs/ui-layout-rules.md`，例外看 `docs/ui-layout-exceptions.md`。收尾驗收加 `LAYOUT_STRICT_WARN=1`。
3. 檢查器不懂美感、不管卡片基準線（R5）：用 `python3 tools/layout_sheet.py <輸出夾> <圖.png> --shots "22_lobby*,59b*" --combos "zh_TW_100,en_150"` 拼接觸表（自動畫 x=640 紅線、y=400 藍線；`--before <舊夾>` 修前修後並排、`--commit <雜湊>` 標在圖上），用「找錯」的眼光看置中、貼齊、間距；英文 150% 一定要看。
4. 空／滿資料的截圖名帶 `@`（例：`59b_nemeses@full.png`），dev_main 裡要寫字面字串（layout_check 用 grep 抓畫面集合）。
5. 回報不能用「0 違規」代表排版正確，要寫清楚檢查器管什麼、不管什麼。
6. 角色：`tools/atlas_check.gd`、動畫：`tools/anim_lint.py`。
