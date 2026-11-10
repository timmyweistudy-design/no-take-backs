### 一、第 1 輪審查意見修復確認

經比對 [ledger.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v160-impl/ledger.md) 與 HEAD 代碼，逐條確認結果如下：

1. **存檔欄位清洗**：[save.gd:310-388](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L310-L388) 的 `sanitize_v16` 已逐欄驗型限長，`seen` 為 null 時安全抹除並由 [game_screens.gd:20](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L20) 補回入口；`DEFAULT_SAVE` 未補欄位經 Ledger 裁決為區分新舊玩家，屬已知設計。**【已修好】**
2. **跨模式身分與旗標殘留**：[game_place.gd:35-38](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L35-L38) 與 [game_v16.gd:855-856](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L855-L856) 已在回標題與切換模式時補清 `daily_spec`、`challenge_army`、`ga_coop`、`rift_on`。**【已修好】**
3. **教練背景執行緒生命週期**：[game_v16.gd:50-57, 584-600](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L50-L57) 已補足防重入、過期鍵丟棄與 `_exit_tree()` 退出等待。**【已修好】**
4. **高手陣部署檢驗**：[game_v16.gd:844-853](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L844-L853) 的 `_daily_top_go` 已逐兵以 `place_xy` 重新吸附檢驗並確認 `has_combat()`。**【已修好】**
5. **教練快取鍵包含規則與題目**：[game_v16.gd:557](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L557) 快取鍵已納入題號、雙方陣雜湊與 `to_code()` 規則碼。**【已修好】**
6. **每日結算跨午夜**：[game_v16.gd:402](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L402) 已改用 `daily_spec.get("day", ...)` 鎖定開局日。**【已修好】**
7. **極速賽試玩版權限**：[game_menus.gd:1249](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L1249) 已加上 `not _demo()` 限制。**【已修好】**
8. **NTBR6 數值嚴格驗證**：[ruleset.gd:500](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L500) 已限定 `float(j[29]) == 1.0`。**【已修好】**
9. **實驗簿支援試煉**：[game_v16.gd:754-760](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L754-L760) 的 `_nb_key` 已支援試煉 `t%d` 鍵值與自由座標載入。**【已修好】**
10. **盾弓相鄰加成改為射速**：[adj_defs.gd:9, 35](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/adj_defs.gd#L9) 改為縮短攻擊間隔 `cd_base`，每次至少減少 1 tick。**【已修好】**
11. **相鄰陣法規則比對**：[ruleset.gd:404](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L404) 的 `equals()` 已補上 `and adj == o.adj`。**【已修好】**

---

### 二、新發現實質缺陷（依嚴重度排序）

1. **[嚴重] `save.gd:379, 326, 340` 容器超額判斷導致玩家存檔歷史整批洗白**
   - 檔案:行號：[save.gd:379](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L379)
   - 原因：`sanitize_v16` 中 `if d is Dictionary and d.size() <= 50:` 邏輯錯誤。若活躍玩家遊玩累積超過 50 週，條件不成立，`d2` 維持空字典，導致 `out["rift_best"] = {}` 將歷史週紀錄全部抹除；同檔 line 326 的 `seen`（超過 200 筆）與 line 340 的 `notebook`（超過 400 關）亦因超額判定導致全清空而非截斷。

2. **[嚴重] `game_v16.gd:705` `_start_mode` 的 `keep_rift` 條件外洩污染自訂對局**
   - 檔案:行號：[game_v16.gd:705](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L705)
   - 原因：`var keep_rift: bool = rift_on and m == Mode.VS_AI and rules != null and rules.preset == "custom"`。若玩家自裂隙中返回並開啟其他 custom 規則對局（如大廳自訂對局或每日高手陣），`rift_on` 被錯誤繼承為 `true`，打完獲勝會誤入 [game_v16.gd:672](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L672) 的 `_rift_settle()`，以普通自訂局成績篡改每週裂隙榜。

3. **[中度] `game_v16.gd:707` `_start_mode` 未清空 `tv_marks` 殘留標記**
   - 檔案:行號：[game_v16.gd:707](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L707)
   - 原因：`_start_mode` 僅重置了 `tv_mark_mode = false`，未重置 `tv_marks = []`。玩家在殘局切換下一題、極速賽換題（`_rush_load`）或試煉重試時，若新題在相同座標有單位，舊標記座標會直接帶入 [game_v16.gd:316](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L316) 生成幽靈追蹤標號。

4. **[中度] `game_v16.gd:66, 77` `_finish_battle` 覆寫順序導致一陣三考通關漏斗早發**
   - 檔案:行號：[game_v16.gd:60-78](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L60-L78)
   - 原因：`super._finish_battle()` 先於 `_trio_settle()` 執行，第一場打贏即產生 `report["goal_ok"] = true`，並在 line 78 觸發 `Funnel.mark("puzzle_clear")`。若後續第二、三場失敗，漏斗已提前虛報通關；若使用者在三考彈窗點返回，底層結果頁亦顯示為第 1 關通關。

5. **[中度] `workshop.gd:167-169` NTP3 出題台護送目標單兵解生成失敗**
   - 檔案:行號：[workshop.gd:167-169](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/workshop.gd#L167-L169)
   - 原因：解碼護送題時將被護送的固定兵自作者解過濾（`s = s.filter(...)`）。若作者解原僅有 1 隻兵，`s` 濾成空陣列 `[]`，隨後 [workshop.gd:174](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/workshop.gd#L174) 呼叫 `PZ.play(pz, [])` 以空額外部署開戰，單一固定兵直接戰敗導致 `ws_unsolved` 拒絕生成碼。

6. **[輕度] `ruleset.gd:404` `equals()` 遺漏 NTBR4/6 地圖參數比對**
   - 檔案:行號：[ruleset.gd:404](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L404)
   - 原因：`equals(o)` 比對依賴 `key_fields()`，但 `key_fields()` 未包含 `map_id`、`map_size` 與 `vents`。若兩組規則僅地圖設定不同，`equals()` 會誤判為相同規則，造成大廳快取與套用時忽略地圖變更。

有條件
