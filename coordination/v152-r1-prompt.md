你是《落子無悔》（Godot 4.6.2，全畫面用 _draw 自繪 UI，畫面 1280×800）V1.5.2 方案審查者，第 1 輪（共 3 輪）。只讀檔、不要改任何檔案。
初稿：coordination/v152-r0-draft.md。背景：docs/STATE.md、docs/history/2026-11-09-v1.5.1-plan.md、coordination/v151-impl/ledger.md。版面檢查器在 game/tools/dev_main.gd（_probe、PADWALK、檢查函式）與 game/tools/layout_check.sh。截圖在 build/tmp/lay151e/<語言_字級>/*.png（可讀圖）。
使用者抓到的低級錯誤：主畫面第二層卡片面板沒置中（game/scripts/ui/screens/game_menus.gd _draw_hub）、大廳模式分頁下的紅書籤沒有貼頂（game/scripts/ui/lobby_view.gd）。使用者要：完整方案、確認整體排版問題、不要再犯。
請：
1. 實際看程式與截圖，補充初稿 §1 漏掉的排版問題（每條給畫面檔名或檔案:行號、問題、建議規則），特別找：置中、貼齊、對稱、間距不一致、面板留白過多、文字在框內的垂直位置、標題緞帶與內容距離、四語／150% 下才出現的。
2. 評估 §2 偵測器設計：可行性（對照 dev_main.gd 的探測結構）、會不會誤報、還該量哪些規則。
3. 參考成熟遊戲／UI 規範（可查資料）給排版規則的具體數值建議。
4. 估人時、排優先。繁體中文，3000 字以內。
