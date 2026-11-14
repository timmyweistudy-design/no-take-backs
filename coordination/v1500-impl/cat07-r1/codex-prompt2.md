你是《落子無悔》(Godot 4.6.2) 1.5.0 實作的程式審查（第 2 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 7 批（戰場辨讀）。第 1 輪你的意見在 coordination/v1500-impl/cat07-r1/codex.md；新的完整差異 coordination/v1500-impl/cat07-r1/diff2.patch；裁決 coordination/v1500-impl/ledger.md「第 7 批」。
這輪改了：焦點改成逐 tick：`pick_focus(units, follow)`＝跟拍兵＋快照 `target`（索引）指到的敵方活兵；不看動畫時鐘（暫停、跳轉、固定時鐘一致）；血條透明度只看焦點與低血量；`is_num_text` 改成字元白名單（含全形、各負號、×、括號、%）；新截圖 v150_03f（找一隻 target 是敵方活兵的藍兵跟拍）。噪音：焦點最多 2 隻＋1 條線，和導播／放大鏡共用 follow_id。
請只看這些是否正確、有沒有新問題（例如 `target` 是索引不是 id、召喚物插入後索引是否穩定、view.units 和 sim.units 同序；被擋兵虛線底座和焦點外緣疊在一起）。附行號。最多 4 條必改、400 字內。最後一行「結論：可／有條件／不可」。
