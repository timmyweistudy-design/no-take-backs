# 程式輪 R3 第 2 輪＋R4（Codex 唯讀）

請看 `git diff b0cd97e fc29ed3 -- game/`。你上一輪（coordination/r3-r1/codex.out.md）的三點：
1. battle_view.gd 新增 static event_route()：death／taunt／reveal／attack（必須帶 src、tgt、dmg）／skip（背水開關、繞翼、狂熱耗損）。_on_event 依路線分流。新測試 test_event_routes 用 30 場真實戰鬥的所有事件檢查（已證明把 attack 條件改成 true 會紅）。
2. codex.gd 新增 expect_hits()：用 unit_by_id 查觸發者位置；codex_view 用它跳字。測試逐 tick 比對每段示範的跳字位置＝觸發者位置、每段至少一次（已證明改回陣列索引會紅）。
3. _open_codex 清掉 painting／drag_new／drag_from；_mouse_button 在覆蓋層或非擺放狀態下，放開滑鼠也會清這三個狀態。

R4（純演出，不碰模擬）：battle_view.gd 新特效 aim（警覺）、hide（皮甲）、trip（絆馬）、vslash（背刺）、taunt＋bang（嘲諷）、puff（現形），shard 改旋轉三角；潛行 alpha 0.45＋暗紫殘影；暈眩改三顆金菱形。ui_base 加 freeze_fx（截圖用）；main.gd 截圖加 12_fx.png，截圖時暫時讓一隻騎兵 stun=10、拍完還原。

Claude 已驗證：測試 70/70、Windows 截圖 12 張。

請找：正確性 bug、上一輪三點是否真的修好（有沒有漏掉的路徑，例如鍵盤／手把開圖鑑、結果頁開圖鑑、圖鑑開著時 Esc）、新特效在 fx 陣列的欄位是否一致（_draw_fx 讀不到的欄位）、截圖改 sim 狀態的風險、測試假綠燈。
繁體中文、≤1,200 字，每點附檔名:行號與建議修法，最後一句給「可否繼續」。
