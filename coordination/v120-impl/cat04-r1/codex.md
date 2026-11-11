必改 2 條（只讀審查，未執行遊戲）：

1. 位置：[ui_base.gd:830](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:830)。`sel_on` 無條件允許空標籤按鈕變成淺木牌，繞過保護。遠征獎勵卡（`game_modes.gd:791–796`）仍直接畫白色標題及淺色說明，沒有使用 `last_btn_paper`；選取後底色變淺，文字卻未換墨色，閱讀性退化。改法：`TH_ACTIVE` 同樣要求非空標籤，或逐一修正另畫內容的呼叫端，依實際底面切換墨色並保存、還原狀態。

2. 位置：[battle_fx.gd:815](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd:815)。跳字啟用 `_ink_mode` 後，會套用 `ui_base.gd:789` 的介面文字透明度下限：亮色跳字的 alpha 在 0.45～0.85 間被拉到 0.85，但紙底仍依原 alpha 淡出。結果字與紙不同步，跨過 0.45 時文字透明度突然從 0.85 跳降，出現明顯斷階。改法：戰場墨色轉換保留原 alpha；另存進入時的 `_ink_mode`，繪完還原原值。

結論：有條件