《落子無悔》V1.5.2 排版品質 **實作審查第 1 輪**（共三輪）。只讀檔、不改檔、不執行會改東西的指令。
依據：docs/history/HANDOFF-v152.md（問題 L1～L11、規則 R1～R10、偵測器設計）、docs/history/2026-11-09-v1.5.2-plan.md、coordination/v152h/r3-final.md（交接優化定案）。
實作：`git diff 623d8f4..HEAD -- game docs`（重點檔：game/scripts/ui/layout_rules.gd 規則引擎、ui_base.gd 的 _h1／_h1_help／modal_rect／probe_*／btn_deco、lobby_view.gd 紅書籤與大廳列、screens/game_menus.gd、game_modes.gd、game_place.gd、replay_view.gd、codex_view.gd、tools/dev_main.gd、tools/layout_check.sh、tests/suites/ui.gd test_layout_rules_v152）。規則文件 docs/ui-layout-rules.md、例外 docs/ui-layout-exceptions.md。
驗證結果：統一檢查 48 步 4429 項全過、FINGERPRINT／數值摘要不變；版面 21 組 2919 張：違規 8（日文 125% 擺陣說明，已修，未重跑）、排版規則失敗 0、警告見 coordination/v152-impl/r1/full1_table.md（R7 已修正判斷）。
截圖接觸表（紅線 x=640、藍線 y=400）：coordination/v152-impl/r1/sheet_en150.png、sheet_ja150.png、sheet_l1l2.png（修前／修後並排）、bm_zoom.png（紅書籤 A 案放大）。
請：
1. 必改（最多 6 條，附 檔案:行號，要對照程式或截圖確認）：仍會讓使用者看到不置中、不貼齊、壓字、溢出的地方；或偵測器有漏洞（某種同類錯誤還會被放過）；或改動造成功能退步（點擊區、手把焦點、存檔、測試假通過）。
2. 交接定案項目有沒有漏做：L1～L11、R1～R10、漏登記守衛、反例測試、空／滿資料截圖、備份目錄跟前綴、確認框完整清單、紅書籤畫序（焦點框之前）與文字槽、例外清單。
3. 最後一行結論：「可」「有條件」或「不可」。繁體中文，1200 字以內。
