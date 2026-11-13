你是《落子無悔》(Godot 4.6.2) 1.4.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 5～7 大類：規劃 coordination/v140-impl/cat05-plan.md；方案 docs/2026-11-13-v1.4.0-plan.md §3、§5、§6；差異 coordination/v140-impl/cat05-r1/diff.patch（不含已 commit 的第 1～4 類）。
請檢查：①接觸陰影 canvas_item_add_triangle_array 在目前的 draw 變換（_cam）下座標是否正確、簡化介面、標題示範戰、擺陣、結果頁有沒有誤畫；②虛線底座 _occ_ids 快取跨場次、跳轉、單位死亡後殘留；③牛皮紙標籤：簡化介面路徑、對比；④即時配件與壓縮拉長：減少動態、巨獸、隱形、倒地、背面走路頁時；spring_angle 純函式是否真的和幀率無關；⑤噪音預算：FX_CLASS 淘汰「同類最舊」是否可能淘汰正在演的關鍵效果（stain 是範圍指示，方案說關鍵提示不可淘汰，但我放在 scar 類）；cmdseal 放在 high；⑥頓幀 _hitstop_weight 與既有 hitstop／present_debt 的互動、截圖可重現；⑦重播推近 _dir_hot 與鏡頭仲裁、精華三連；⑧效能取捨（ABBA 結果寫在規劃）。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
