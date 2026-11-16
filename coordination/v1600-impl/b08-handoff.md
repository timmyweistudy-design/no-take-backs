# B08 暫停交接（2026-11-16 09:30，使用者指定自動暫停）

狀態：B06 已提交推送（aa156aa）。B08 實作中、**未提交**（改動在工作樹：battle_fx.gd、battle_units.gd、game_screens.gd、tests/suites/battle_visual.gd、tests/run_tests.gd、tools/layout_check.sh）。

做完的：
- 跳字避讓（完整畫出範圍 dr、頭胸框含姿勢餘量、盤內 12px、面積 15%、關鍵字併入／只留戰報列、黏著、最近乾淨位置、緊貼自己那隻）。
- 特效上限（面積 4%、字面色亮度 ≤0.8 全掃、動態色壓、頭胸上壓淡）。
- 測試 test_melee_read_v1600（15 項）、test_semantic_guard_v1600（4 項）全過；ui＋battle_visual 906 項全過（在 Hydrogen r2 引線修正之前）。
- 開發旗標 --face-debug／LAYOUT_FACE_DEBUG=1。

三方：
- Codex r1 不可（6 條，全處理）；r2 不可（3 條，09:22 已改：紙條下外擴 14、只併同種關鍵字、合併後當幀重排一層；test_melee_read_v1600 15 項過）——**第 3 輪是最後一輪**，下次送 diff3。
- Hydrogen r1 有條件（2 條，處理）；r2 有條件：中斷的短引線看不出歸屬 → 已改「整條通才畫、否則不畫」（09:2x，未經 Hydrogen 複查）。

接下來：
1. 讀 codex2.md，改；重拍 b08new（zh_TW:100、en:150 戰鬥 6 張）→ Hydrogen r3 與 Codex r3（最後一輪）。
2. 驗收鏈：check.py＋24 組 LAYOUT_FIXED（戰鬥頁跳字位置改了，固定時鐘比基線差的畫面要逐張解釋）。
3. ledger B08（裁決：K6 未做 → 勢箭頭、自動焦點不做；隕石落點等範圍圈不縮；擠不下關鍵字只留戰報列＝第七輪 D1 規則）、方案進度、commit、push、刪 build/tmp/b08*、build/cg/b08old。
4. 之後 B10 → B13a …，最後收尾（版本、STATE、CHANGELOG×4、進度表、記憶、完整匯報含 save.json 事件與 chain-busy 違規）。
