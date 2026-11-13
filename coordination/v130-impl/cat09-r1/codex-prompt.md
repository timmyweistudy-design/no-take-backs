你是《落子無悔》(Godot 4.6.2) 1.3.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
這次一起審（差異 coordination/v130-impl/cat09-r1/diff.patch，相對上一個 commit）：
(1) 第 8 大類審查後的修正（你上一輪 cat08-r1/codex.md 的 3 條：獎盃架收進畫面、絲帶改從右緣夾出、obj_extent＋layout_rules「screen」邊緣規則＋測試）；
(2) 第 9 大類（規劃 coordination/v130-impl/cat09-plan.md）：battle_view hud_meta_visible、game_place _pin_note；
(3) 第 10 大類：sfx.gd place_of／play_place／reseed／棋館環境三層（RoomFar 匯流排、低通、room_gain）、tools/gen/room_ambience.py、game_place／free_place 落子音、battle_view 呼叫、tests/test_base.gd 假音效。
請檢查：①obj_extent 是否真的對應 _obj_deco 的幾何（會不會低估讓檢查放過）；②hud_meta_visible 在重播、觀戰、結果頁、手把切換、版面截圖時的行為，以及有沒有其他畫面依賴左上那兩行（測試、教學提示）；③便籤會不會壓到其他 HUD 元件、大字級換行；④音效：新匯流排在 _ensure_buses／音量設定、靜音、夜間模式、單聲道下是否正確；room 播放器在 headless／結束時；reseed 時機是否會讓變體在同一場內和以前不同（可接受）但跳轉後一致；place_of 的 22 種對應是否合理；環境檔響度；⑤其他。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
