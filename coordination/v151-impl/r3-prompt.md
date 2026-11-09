《落子無悔》V1.5.1 實作審查第 3 輪（收尾）。只讀檔、不改檔。程式在 game/，最新 commit 76b5bce。
看 coordination/v151-impl/ledger.md（第 1、2 輪的處理與 Ruling）、docs/2026-11-09-v1.5.1-plan.md §I 進度。
1. 驗證第 2 輪「已修」各條確實修好、沒有新問題（battle_units.gd 轉身朝向、battle_view.gd 冷卻遮罩、replay_view.gd 倒地重建、game_screens.gd／free_place.gd 點一下拿掉、shaders/unit_bake.gdshader y_off 對圖集是否完全沒影響、codex_bake.gd、game_menus.gd 確認框回原頁）。
2. 必修：只列會讓玩家遇到錯誤、資料損失或畫面明顯錯的（最多 5 條，檔案:行號＋觸發＋後果）。
3. 對剩下的 Ruling（A4、挑戰局算連勝、C4 時間軸延後、C7）表態。
4. 結論一句：「同意收尾」或「不同意收尾：原因」。繁體中文，1500 字以內。
