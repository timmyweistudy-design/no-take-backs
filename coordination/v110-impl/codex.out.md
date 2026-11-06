唯讀審查完成，未改檔、未跑 Godot；FINGERPRINT 未實測。

- **Important｜game/scripts/ui/screens/game_modes.gd:355**  
  募兵用 `gauntlet_prev` 排除離隊兵種，但它是進入本戰時的陣型，並非剛打完的 `last_armies[0]`。首戰勝利時甚至是空陣，可能換掉本戰已部署的兵種；下一戰又把那些兵複製回來，形成卡池外兵。應以本戰實際陣型決定可離隊兵種。

- **Important｜game/scripts/ui/screens/game_core.gd:89**  
  敵軍先以 100 金、24 隻上限組好，才套減益，沒有移除超額兵。例如單劍士卡池首戰後選敵方減 10 金，第二戰預算為 95，卻仍保留已買好的 20 隻、100 金敵軍；複製對戰碼也可能因超支無法讀回。應先套限制再生成。

- **Important｜game/tools/check.py:97**  
  快取相依掃描只追 `load/preload`，漏掉 `extends`。唯讀檢查確認 `t_stateful` 的相依集合不含 `game_core.gd`、`game_modes.gd`、`battle_units.gd`。已有快取後只修改這些檔案，相關行為測試仍可能直接沿用通過結果；應追蹤繼承鏈。

- **Important｜game/scripts/ui/lobby_view.gd:1**  
  改為繼承 `unit_brief.gd`，但指定的 `diff.patch` 沒有加入該新檔；目前它仍是未追蹤檔。將此 patch 套至 `4fd9939`，會因缺少父腳本而載入失敗。交付差異須包含新檔及 UID。

- **Minor｜game/scripts/game/save.gd:184**  
  每日紀錄只驗鍵長，`"999999999-v1": [100, 0]`、任意短字串都會保留。前者會在依日數排序時擠掉有效紀錄，且只在勝利寫紀錄時才裁切。應驗證日數與版本格式，載入時清除無效／過期鍵。

- **Minor｜game/scripts/ui/battle_view.gd:278**  
  `last_blast_t` 在開戰及跳轉時都未重置，且用畫面時間判連環爆。爆炸後立即跳到另一顆孤立爆炸前恢復播放，可能誤觸頓格；快轉也會把原本相隔超過 0.4 秒的爆炸判成連鎖。應以事件 tick 判定並於跳轉重建。

結論：修完 Critical/Important 後可出貨
