你是《落子無悔》（Godot 4.6.2 確定性自動對決）V1.5.0 實作審查者。方案在 docs/history/2026-11-09-v1.5.0-plan.md。已完成 M1＋M2 前半（commit 261332e 之後還有圖鑑檢視控制，未提交）：
- 主畫面五大牌匾（scripts/ui/screens/game_menus.gd home_plaques / _draw_hub）
- 設定 7 分頁 45 項、預設組合、設定碼 NTS1、備份還原、清除資料、首次啟動（game_menus.gd、scripts/game/save.gd）
- 遠程時間同步：view_buffer.gd DELAY_LONG=8、battle_state.gd proj_phase、battle_units.gd _draw_projectile、battle_view.gd proj_tgt
- 角色握持三層、轉身、圖鑑 CX_FIT 與檢視控制（kit.gd、kingdom.gd、fantasy.gd、codex_view.gd _cx_portrait/_cx_turn）
附圖：units_sheet.png（22 種 × 轉身＋出手幀）。
請只讀檔，找出：1) 實際 bug（含行號、觸發條件、後果）；2) 違反方案或鐵則（模擬不能讀畫面狀態、舊 FINGERPRINT 不變、字串不寫死）；3) 角色圖上仍有缺件、紙片感、手持物被裁的單位（指出列號）。最多 12 條，依嚴重度排序，繁體中文。
