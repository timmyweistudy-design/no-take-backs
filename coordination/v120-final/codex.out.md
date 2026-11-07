- sprite_cache.gd:82｜Important｜世代檢查只保護頁面提交；舊 `ensure()` 在 await 返回後仍會清掉新世代的 `_baking`／`_busy`，造成重複烘焙與快取競態。`build()`、`ensure()`、`_bake_ring()` 都須攜帶世代，await 後先驗證再寫共享狀態。

- game_result.gd:116｜Important｜緞帶最多寬 504，摘要卻按 540 排字，長行會跨出本體；緞帶高度使用 fit 後字級，154 行正文推進仍用原字級，縮字時留下額外空白。應共用實際字級、換行結果及緞帶內寬，統一繪製與高度計算。

- game_result.gd:118｜Minor｜`rh` 減去含 drop 的 `ry`，使緞帶底邊固定、頂邊下降，開場變成收縮；摘要也沒有跟著移動。應先算靜態高度，再讓緞帶、標題與摘要共同套用 drop。

- game_place.gd:561｜Minor｜可負擔兵卡直接呼叫 `_tex_box()`，漏判 `plain_ui`，開啟簡化介面仍有木紋。補上與其他材質入口相同的設定判斷。

- ui_base.gd:541｜Minor｜`_ink()` 將灰白文字透明度乘 1.1，違反保留透明度的規則，也改變紙頁文字的淡化層級。改回 `Color(INK, c.a)`。

結論：修完再出
