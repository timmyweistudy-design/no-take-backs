確認 4 項必改；全程只讀。劍士資料與原公式的 101 點比對最大差約 1.33e−15；未執行 Godot 測試。

1. [codex_view.gd:758](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd:758)：新增表情直接傳入 `Art.overlay`，但該函式沒有 `_eyes` 的背面判斷與轉向定位。圖鑑轉到背面仍會長出眼嘴，斜面表情也會與原五官錯位。改法：表情層共用五官的背面、轉向座標處理，並驗證自動旋轉與手動角度。

2. [battle_units.gd:707](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:707)：`_tumbler` 把已乘 `flash_pct` 的 `hurt` 當時間相位。預設閃白 50% 時，命中瞬間便跳到 −0.035 rad，整段只走部分搖擺；關閉閃白則完全不搖。改法：以受擊經過時間算 1→0 相位，閃白強度僅控制閃白。

3. [battle_units.gd:852](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:852)：待機與歡呼雖局部使用 `_pose_t`，傳給 `_unit` 的仍是原始 `time`；直接繪製與快取路徑的 `idle_bob` 都持續逐幀位移。關閉「平滑動作」後，角色仍未真正定格。改法：獨立傳入量化的表演時間給待機起伏與姿勢，保留攻擊、命中、移動的原時間。

4. [battle_units.gd:1004](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:1004)：`lift` 只套在身體；前面的 `draw_base`／`ring_base` 仍畫在原位。結果是身體脫離底座，底座並未依規劃離地。改法：分離地面影子與底座，將同一離地量套到身體和底座，影子留在地面。

結論：有條件