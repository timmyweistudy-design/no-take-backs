以下為第三輪複查結果，僅列出目前仍存在、會讓玩家困擾或出錯的問題（共 3 條）：

### 1. 手把模式下無法觸發「對齊點陣」，且「占地圈」中心仍跟著滑鼠跑
- **位置**：[free_place.gd:603-607](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6c/free_place.gd#L603-L607)、[free_place.gd:680-686](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6c/free_place.gd#L680-L686)
- **問題**：
  1. **對齊點陣在手把下失效**：第 680–681 行寫 `if _snap_on() and _fp_in_field(mouse): var c := _q(_w_of(mouse))`，完全綁死滑鼠座標 `mouse`。當玩家使用手把按下 L3 開啟對齊（`fp_snap`）時，若滑鼠游標停在戰場外，畫面完全不會顯示 3×3 對齊點陣；若滑鼠在戰場內，點陣則畫在滑鼠位置而非手把準星 `fp_cur` 處。
  2. **手把懸停占地圈錯位**：第 603、606 行計算友軍占地虛線圈時，`hover_w` 只取 `_w_of(mouse)`，未像第 622 行判斷 `pad_mode` 改取 `Vector2i(fp_cur)`，導致手把移動準星靠近友軍時不會浮現占地圈（反而顯示在滑鼠停放處）。
- **建議**：將 `hover_w` 統一改為 `Vector2i(fp_cur) if pad_mode else _w_of(mouse)`，且第 680 行改為 `if _snap_on() and (_fp_in_field(mouse) or pad_mode): var c := _q(hover_w)`。

### 2. 手把或對齊（Snap）模式下畫筆／直線後，手把準星與最後落兵位置脫節
- **位置**：[free_place.gd:446-447](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6c/free_place.gd#L446-L447)、[free_place.gd:697-704](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6c/free_place.gd#L697-L704)
- **問題**：第 697 行與第 700 行在 `pad_mode` 下繪製手把準星與射程圈時，直接使用未量化的 `Vector2i(fp_cur)`，但實際按下 A 放兵或搬移（第 109、361、630 行）會經過 `_q(...)` 量化（尤其開啟對齊 `fp_snap` 吸到 `500` 格點時，差距可達 0.25 格），造成手把準星／射程預覽圓心與實際落點不一致（滑鼠模式在第 700 行有用 `_q(hover_w)`，手把卻漏掉 `_q`）。
- **建議**：第 697 行與第 700 行的手把座標改用 `_q(Vector2i(fp_cur))`。

### 3. 畫筆／直線拖曳期間切換兵種，預覽射程圈與同一筆混合兵種行為不直覺
- **位置**：[free_place.gd:117](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6c/free_place.gd#L117)、[free_place.gd:665-668](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-impl6c/free_place.gd#L665-L668)
- **問題**：玩家按住左鍵或手把 A 拖曳畫筆時，若誤觸數字鍵或 `Q`/`E`（手把 `LB`/`RB`）切換 `selected`，若新兵種在當前模式不可用（`not _allowed(selected)`），`_fs_try` 未檢查 `_allowed(t)` 會直接把禁用的兵種塞進 `fp_stroke` 並於放開時繞過檢查擺上場；此外第 665 行首尾射程圈固定查 `_fp_range_of(selected)` 而非該點實際記錄的兵種 `int(it[0])`。
- **建議**：在 `_fs_try` 開頭加上 `if not call("_allowed", t): return false`（或在 `_fs_begin` 鎖定該筆兵種），並將第 665–668 行改為依各預覽點自身的 `int(it[0])` 查詢射程。

結論：需修正
