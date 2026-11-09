### 一、第 2 輪修正與背面實作驗證

1. **Ledger「第 2 輪」12 項修正核對**
   - **已落實且正確（11 項）**：
     - [`save.gd:451-458`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L451-L458) `restorable()` 嚴格檢查 `version`（`1..SAVE_VERSION`）、`stats`、`achievements` 型別。
     - [`game_menus.gd:719-724`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L719-L724) `_progress_backup()` 同秒備份自動加 `_2`、`_3` 序號，不覆蓋既有備份。
     - [`game_modes.gd:1734-1735`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1734-L1735) `GHOST_ALL` 移出「首次擊敗」分支，舊存檔已全破玩家再贏一場即可補解鎖。
     - [`game_menus.gd:784`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L784) `CLEAR_KEYS` 已補齊 `custom_stats`、`unit_games`、`streak`、`best_streak`。
     - [`game_menus.gd:758-776`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L758-L776)、[`818`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L818) `_after_data_swap()` 在還原與全部清除後同步刷新語系、音效、字級與塗裝。
     - [`battle_view.gd:219`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L219) 醫者（`st_ty != D.MEDIC`）近戰不再誤觸投射物分支，只有 `EV.HEAL` 才走補血光球。
     - [`game_menus.gd:331`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L331)、[`539`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L539)、[`546`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L546) 戰鬥暫停按離開時維持 `paused = true`，取消時回到 `pause_menu`。
     - [`game_menus.gd:337-339`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L337-L339) 與 [`game_place.gd:43`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L43) 設定子頁 Esc 回 `settings`、回標題清 `settings_ret`。
     - [`lobby_view.gd:539-541`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd#L539-L541) 「我的預設」雙欄下拉選單會先移除被遮蓋的底層 `_btns`。
     - [`game_modes.gd:1303-1308`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1303-L1308)、[`1332-1333`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_modes.gd#L1332-L1333) 與 [`game_place.gd:35`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L35) 競猜開戰即存檔歸零連勝並暫存 `pend`，中途離開清 `wg_active`。
     - [`ui_base.gd:200-205`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L200-L205) 與 [`game_screens.gd:298`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L298)、[`749`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd#L749) 永久吐司（`toast_mult == 0`）滿 0.3 秒後按任意鍵或點擊可關閉。
   - **漏做一半（1 項）**：
     - Ledger 第 2 輪第 1 條寫「`_progress_restore`、`_clear_data` 先檢查 `Save.data_locked`」，但實際上只有 [`_progress_restore()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L750-L752) 檢查了 `Save.data_locked`，[`_clear_data()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L803-L824) **漏掉 `Save.data_locked` 檢查**（見下方必修 #1）。

2. **背面（`Art.back`、`BACK_OK`、`_inf_back_items`、`cx_angles`）與靜態變數殘留檢查**
   - **戰場與圖集烘焙不會殘留 `Art.back`**：
     - 圖鑑繪製 [`_cx_portrait()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L561-L603) 單一函式內同步設定並在 [`599-603` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L599-L603) 還原 `Art.back = false`；圖集烘焙 [`_TurnPainter._draw()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L461) 與 [`_ExtraPainter._draw()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L535) 亦明確設 `Art2.back = false`。Godot 主執行緒 `CanvasItem._draw()` 不會被搶佔插入，因此 `Art.back` **不會殘留汙染戰場或圖集快取**。
   - **但圖鑑手動轉向切換角色存在狀態殘留漏洞**：
     - [`_cx_pick_unit()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L60-L66) 切換兵種時沒有重設 `cx_angle = -1`，且 [`_cx_portrait()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L568-L573) 手動角度分支寫 `Art.back = sin(th) < -0.01`，**漏掉 `cx_unit in Art.BACK_OK` 條件**（對比自動旋轉 [`582` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L582) 與 [`unit_review.gd:26`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/tools/unit_review.gd#L26) 都有加 `in Art.BACK_OK`）。當玩家在人形兵按 `◀/▶` 轉到背面（`cx_angle` 為 `9..15`）後點選騎兵或奇幻兵，`cx_angle` 超出其 9 向範圍且 `Art.back` 被設為 `true`，導致騎兵出現「馬頭朝前有眼、騎士變後腦無眼」的錯亂畫面（見下方必修 #2）。
   - **背面部件遮擋瑕疵**：
     - [`kingdom.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd) 在 `back == true` 時雖然先畫了 [`_inf_back_items()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L35) 與後腦頭髮（[`54-55` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L54-L55)），但後續仍照畫正面專屬部件：盾兵正面大盾與頭盔眼縫（[`94-105` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L94-L105)）、投彈手額頭護目鏡與瞳孔（[`194-197` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L194-L197)）、醫者帽前十字章（[`225-226` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L225-L226)）、戰鼓手胸前大鼓（[`255-269` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L255-L269)），在背面會直接疊在披風／後腦上。

---

### 二、§8 進度表與 `docs/STATE.md` 誠實度檢查

- **[`docs/2026-11-09-v1.5.0-plan.md` §8](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/2026-11-09-v1.5.0-plan.md#L218-L253)**：**誠實**。已將未做完的項目如實標為「部分」（圖集僅做側面與轉身、圖鑑僅 9 人形兵有背面、僅 5 種兵有獨立小動作、結果頁階層化保留舊按鈕但做寬高主次區分）與「延後」（材質與陰影統一、奇幻兵剪影重繪、五語字型與超長翻譯巡檢、Steam Rich Presence 實機驗證），沒有虛報「完成」。
- **[`docs/STATE.md`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md)**：
  - 「介面與角色（V1.5.0）」與「已知限制」對 9 種人形兵背面、轉身圖集快取、Steam 未實機測試等限制描述誠實。
  - 唯獨 [`docs/STATE.md:44`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L44) 舊段落仍寫「27 成就」，與 [`docs/STATE.md:102`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L102) 的「新增 7 個 Steam 成就（總計 34）」前後數字不一致。

---

### 三、對「背面追加」裁決與 §8「部分／延後」之收尾表態

- **對「背面追加」與 §8「部分／延後」的立場**：
  - 戰場相機固定、士兵只朝左右接戰，原本戰場就不需要背面；在圖鑑提供 9 種人形兵 16 向轉身、騎兵與奇幻兵維持正面半圈 9 向，以及將純美術打磨（奇幻兵剪影、材質陰影統一）與五語超長字串巡檢列為已知限制／延後，**作為 V1.5.0 範圍裁決是務實且可接受的**。
- **能不能收尾出貨？**
  - 只要修掉下方 **2 條必修**（唯讀鎖下清除資料洗掉記憶體與備份、圖鑑手動背面切到騎兵／奇幻兵破圖），即可收尾出貨。

---

### 必修（最多 5 條，只列會讓玩家遇到錯誤或資料損失的）

1. **[`game/scripts/ui/screens/game_menus.gd:803-824`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L803-L824)（關聯 [`save.gd:421-422`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L421-L422)）**
   - **觸發條件**：當 `Save.data_locked == true`（讀到較新版本存檔進入唯讀保護模式）時，玩家到「設定 → 清除資料」點選「只清戰績與紀錄」或「全部清除」；或一般情況下磁碟寫入失敗（`Save.save_data()` 回傳 `false`）。
   - **後果**：[`_clear_data()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L803) 漏檢 `if Save.data_locked:`，而 [`Save.save_data()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L421) 在 `data_locked` 時直接回傳 `true`，導致當場把記憶體中的 `Save.data` 清空並顯示「已清除」吐司；若玩家同場再按一次清除，[`_progress_backup()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L804) 還會把已被洗空的記憶體資料寫成新備份。此外，`_progress_restore` 與 `_clear_data` 都在確認 `Save.save_data()` 成功前就先覆寫了 `Save.data`，磁碟寫入失敗時會造成記憶體與磁碟狀態不一致。
2. **[`game/scripts/ui/codex_view.gd:60-66`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L60-L66)、[`568-573`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L568-L573)**
   - **觸發條件**：在圖鑑選任一人形兵（如劍士），按 `◀` 或 `▶` 轉到後半圈背面（`cx_angle` 為 `9..15`），接著點擊左側名單切換到騎兵（`3`）或任一奇幻兵（`10..19`）。
   - **後果**：[`_cx_pick_unit()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L60) 未重設 `cx_angle = -1`，且 [`572` 行](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L572) `Art.back = sin(th) < -0.01` 漏判 `cx_unit in Art.BACK_OK`，導致不支援背面的騎兵與奇幻兵被強制以 `Art.back = true` 及越界角度繪製（騎兵會出現馬臉朝前有眼睛、馬上騎士卻變後腦無五官的破圖，且換角色自動轉一圈的展示完全失效）。

---

### 建議（最多 5 條）

1. **背面時隱藏正面專屬裝備（[`game/scripts/ui/units/kingdom.gd:94-105`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L94-L105)、[`194-197`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L194-L197)、[`225-226`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L225-L226)、[`255-269`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L255-L269)）**：`back == true` 時建議跳過盾兵頭盔眼縫與正面大盾（或將盾移到背側底層）、投彈手額頭護目鏡瞳孔、醫者帽前十字章、戰鼓手胸前大鼓，避免背面角度看到正面裝備壓在後腦與披風上。
2. **清理未使用的背面分支（[`game/scripts/ui/units/kingdom.gd:274`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L274)）**：`_inf_back_items()` 的 `D.CAVALRY` 永遠不會從 `draw_infantry()` 進入，可移除以免誤導維護者。
3. **修正 `STATE.md` 成就總數前後不一致（[`docs/STATE.md:44`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/STATE.md#L44)）**：第 44 行仍寫「27 成就」，建議與第 102 行的「34 成就」同步更新。

---

### 對收尾的結論一句話

架構、效能快取與絕大多數第 2 輪修正皆已紮實到位，進度表與限制揭露誠實；只需補上 [`_clear_data()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L803) 的 `Save.data_locked` 檢查，並在圖鑑 [`_cx_pick_unit()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L60) 與 [`_cx_portrait()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L572) 擋住非 `BACK_OK` 兵種進入背面狀態，V1.5.0 即可安心收尾出貨。
