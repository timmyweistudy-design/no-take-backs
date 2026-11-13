只讀靜態審查，未執行遊戲。必改：

1. [battle_units.gd:474](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:474)：平滑與 0.25 門檻依繪製次數，非展示時間；暫停仍衰減到側面，相同重播在不同幀率／倍速會選不同方向。須改用固定時間取樣並加切換遲滯。

2. [battle_units.gd:1000](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1000)：未排除受擊；且 p 已混入後退、漂浮等偏移。會把姿勢位移當走向，違反受擊側面規則。應取純移動座標並清除非走路殘速。

3. [sprite_cache.gd:178](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd:178)：命中只刷新 ta_order，bw_order 不刷新；兩者淘汰後可能 ta 有、bw 無，重請求也不補烘。超過十種亦可淘汰在場兵，長期混搭側面，未守全種類門檻。

4. [battle_units.gd:1004](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1004)：背面路徑跳過 _unit 掉漆，且 mood 固定傳 0；轉北就消失。須保留掉漆與適用狀態表現。

5. [battle_units.gd:1010](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1010)：xray 仍存原 face、重畫側面；南北本體被遮時會疊出不同輪廓。須共用視角選格。

6. [battle_units.gd:1006](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1006)：南向直接傳 ±0.55；快取未就緒或 headless 時 Art.unit 只橫縮，未設定 turn_c／turn_s，成為壓扁側面。

7. [battle_view.gd:672](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:672)：puff 實際是紫色現形煙；且 CHARGE 是命中事件，無法呈現起步揚塵。須改塵土並接正確時點。

8. [battle_units.gd:998](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:998)：仍只量化待機時間；受擊後仰與出手收招未接定格軌，規劃 B 尚未完成。

結論：不可
