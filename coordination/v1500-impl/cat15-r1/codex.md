必改 2 項（路徑皆在 game/scripts/ui/）：

- P1：replay_view.gd:144 清空 first_fall，但 :158–168 快轉直接跑 sim.step，未重建；:228–229 只補最後數 tick。跳過首次陣亡會漏記或誤記後死者，須在快轉事件迴圈同步收集。
- P1：replay_view.gd:267–268、:288–300 未保存／還原 first_fall。點敗因直達後立即返回，紀錄仍為空，結果頁按鈕消失；須納入快照。

其餘：team 隨完整快照保留，召喚／復活／潛行不影響查找（view_buffer.gd:71–73、:103–117）；follow_id 在重設後設定，跳轉不再清除（game_result.gd:285；replay_view.gd:304–306）；雙人／觀戰由 game_result.gd:671 排除。

結論：有條件
