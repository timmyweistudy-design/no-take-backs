《落子無悔》V1.6.0 實作審查第 1 輪報告。

---

### 一、五大重點判定

1. **舊場次位元組與相鄰陣法**：`rules.adj` 關閉時不執行 `AdjDefs.apply` 且 `sim_digest()` 不追加欄位，完全維持舊路徑，指紋不變；`NTBR6` 強制要求第 30 欄為 `1`，滿足「一組規則只有一種代碼寫法」。但 `ruleset.gd` 的 `equals()` 遺漏了 `adj` 比較。
2. **狀態旗標生命週期**：**存在嚴重殘留與跨模式干擾**。`tv_mark_mode`、`challenge_army`、`ga_coop`、`rift_on` 在返回標題或切換模式時未清理，會直接癱瘓操作或污染對手。
3. **存檔驗證與相容**：`DEFAULT_SAVE` 遺漏了 V1.6 全部 9 個新欄位；`sanitize_v16` 未防護 `seen: null` 的情況，會引發運行時崩潰。`unpack_free` 缺乏「至少一隻戰鬥兵」檢驗。
4. **背景執行緒與介面按鈕**：`co_thread` 在每幀工作輪詢與 `_exit_tree()` 均有回收機制，安全無虞。結果頁按鈕收合至「分享」面板合理，未遺漏核心流程按鈕。
5. **企劃相符度**：主要玩法與系統均已落地，但存檔預設值與旗標重設存在漏項。

---

### 二、實質缺陷清單（依嚴重度排序）

#### 1. 戰術標記旗標未清空，導致後續所有模式無法擺兵
- **檔案:行號**：[game_place.gd:28](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L28) / [game_v16.gd:200](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L200)
- **觸發方式**：在擺陣畫面按 `T` 鍵或點旗幟開啟標記模式（`tv_mark_mode = true`），隨後按 Esc 離開或返回標題，再進入教學、殘局、雙人或對 AI。
- **影響**：[game_screens.gd:249](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L249) 的 `_v16_place_click()` 永遠攔截左鍵並返回 `true`，導致後續整局無法放置、選取或拖曳任何兵種，整個遊戲操作卡死；且 `tv_marks` 殘留座標會在重播與新局中誤標。
- **建議修法**：在 `game_place.gd` 的 `_go_title()` 及 `game_core.gd` 的 `_reset_place()` 中加入：
  ```gdscript
  set("tv_mark_mode", false)
  set("tv_marks", [])
  set("tv_range", false)
  ```

#### 2. 挑戰敵軍未清理，導致返回大廳後 AI 陣型被永久置換
- **檔案:行號**：[game_place.gd:28](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L28) / [game_core.gd:170](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_core.gd#L170)
- **觸發方式**：點擊「每日高手陣」（`_daily_top_go`）進入挑戰後返回標題，隨後從主選單進入對 AI 大廳開啟標準局。
- **影響**：`_daily_top_go` 設定了 `challenge_army`，但 `_go_title()` 從未將其歸零。`_build_ai()` 優先讀取 `challenge_army`，導致玩家之後打的所有一般 AI 局，敵軍永遠是剛才載入的高手陣型。
- **建議修法**：在 `_go_title()` 中加入 `set("challenge_army", null)`。

#### 3. 雙人接力遠征旗標未清理，單人遠征殘留換手彈窗
- **檔案:行號**：[game_place.gd:28](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L28) / [game_v16.gd:1048](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L1048)
- **觸發方式**：開啟雙人接力遠征（`_coop_go`），中途返回標題，再從首頁「遠征」按鈕開新局。
- **影響**：`ga_coop` 未被重設，單人遠征每關開始時仍會彈出「換玩家 2 接棒」的遮罩並顯示接力 HUD。
- **建議修法**：在 `_go_title()` 加入 `set("ga_coop", false)` 與 `set("coop_seen", 0)`；並在 `_enter_gauntlet_new()` 開頭明確設為 `false`。

#### 4. `DEFAULT_SAVE` 漏欄位與 `seen: null` 存檔遷移崩潰
- **檔案:行號**：[save.gd:20](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L20)、[save.gd:321](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L321)
- **觸發方式**：新玩家初次安裝建立存檔，或存檔損壞/被第三方注入 `"seen": null`。
- **影響**：
  1. `DEFAULT_SAVE` 完全缺少 `funnel`、`seen`、`mastery`、`notebook`、`daily_streak`、`daily_pend`、`rush_best`、`rift_best`、`trio_clear`。
  2. 若存檔中 `"seen": null`，`sanitize_v16` 判定 `sn != null` 為假而不處理，存檔保留 `seen = null`；之後進入 [v16_guide.gd:37](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/v16_guide.gd#L37) 呼叫 `is_new()` 或 `see()` 時，因對 `Nil` 強轉型/呼叫 `.has()` 導致崩潰。
- **建議修法**：
  1. 在 `save.gd` 的 `DEFAULT_SAVE` 補齊所有 V1.6 鍵值（預設空字典/空陣列/0）。
  2. `sanitize_v16` 改為：
     ```gdscript
     var s2: Array = []
     if sn is Array:
         for x in sn:
             if x is String and str(x).length() <= 32:
                 s2.append(x)
     out["seen"] = s2 if sn != null else Guide.OLD_ENTRIES.duplicate()
     ```

#### 5. 裂隙旗標跨模式滲漏至每日挑戰高手陣
- **檔案:行號**：[game_v16.gd:694](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L694)
- **觸發方式**：打完裂隙模式後，在結算分享面板點擊每日高手榜（`_daily_top_go`）開戰。
- **影響**：[game_v16.gd:694](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L694) 以 `rules.preset == "custom"` 作為保留裂隙旗標條件，而每日挑戰規則的 `preset` 恰好也是 `"custom"`，導致高手陣被誤判為裂隙對局，獲勝後誤將高手陣成績覆寫至 `Save.data["rift_best"]`。
- **建議修法**：在 `_daily_top_go()` 中明確設置 `rift_on = false`。

#### 6. 規則比較 `equals()` 漏比相鄰陣法 `adj`
- **檔案:行號**：[ruleset.gd:403](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L403)
- **觸發方式**：比較兩組僅有「相鄰陣法」開與關不同的規則（如大廳自訂預設判定）。
- **影響**：`equals()` 僅檢查 `key_fields()` 與 `cmd_*`，而 `key_fields()` 不含 `adj`，導致開與關陣法的兩組規則被誤判為完全相同。
- **建議修法**：在 `ruleset.gd:404` 結尾追加 `and adj == o.adj`。

#### 7. 排行榜解包 `unpack_free` 缺乏戰鬥兵防護
- **檔案:行號**：[steam.gd:191](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/steam.gd#L191) / [game_v16.gd:823](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd#L823)
- **觸發方式**：Steam 排行榜被上傳全由輔助兵（如純醫者）組成的敵陣。
- **影響**：`unpack_free` 與 `_daily_top_go` 僅檢查位置與花費，未檢驗 `e.has_combat()`。玩家載入高手陣後會面對無戰鬥兵的非法陣型。
- **建議修法**：在 `_daily_top_go()` 的迴圈後加上：
  ```gdscript
  if not e.has_combat() or e.count() == 0:
      _toast(L.t("dt_bad"), true)
      return
  ```

---

有條件
