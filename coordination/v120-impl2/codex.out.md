A．靜態程式審查（行號依目前檔案）

全程唯讀、未跑 Godot。core 無相對改動；既有紀錄為 `b8fe741bcbfcf800`，不能代替本輪驗證。

- ui_base.gd:512｜Important｜紅色傷害字等低亮度文字也會取消描邊；字色亮度不能判定背景是淺紙，深底辨識度會下降。
- ui_base.gd:505｜Important｜浮雕字先按描邊記探針，隨後才取消描邊；外框與實畫不符。應先決定樣式，再合併正文、描邊及陰影邊界。
- ui_base.gd:640｜Important｜九宮格有 10／14px 材質邊，但探針未登記內容內距；文字壓到斜角仍可能過關。
- ui_base.gd:552｜Important｜懸停／焦點面板上移、厚度下伸，標籤與命中框仍用 r；探針又關閉位移，漏驗實際不一致。
- game_screens.gd:527｜Important｜覆蓋層開啟前 0.18 秒只縮放繪圖，按鈕與滑鼠座標未轉換；邊緣點擊錯位，探針模式看不到此情境。
- sprite_cache.gd:103｜Important｜新增 await 延長重烘競態：連切色盲「關→開→關」可讓舊頁通過布林檢查；換色時 _baking 未清也可能漏排兵種。需世代取消並重新排隊。
- ui_base.gd:635｜Minor｜泡泡淡出時 alpha 進入 Flat／Texture 快取鍵，累積大量 StyleBox 且不淘汰；宜限制樣式／透明度級數。
- sfx.gd:219｜Important｜狂熱沿用同首錄音，卻重新指定 stream 並 play，曲目從頭跳播；應保留播放位置再改音高。
- sfx.gd:133｜Minor｜首次抽變體時 last=-1，索引必加一，本體永不首抽；首次應從全部變體抽取。
- battle_units.gd:323｜Important｜每幀新增約 35～54 次底紋繪製及環境圖元；未提供同機 p95 對照，≤10% 尚不能驗收，底紋宜併入地圖烘焙。
- THIRD_PARTY_LICENSES.md:16｜Important｜交付追溯時，合併條目缺逐素材版本／下載日，部分網址僅短路徑；需補完整登記。

charts.gd 的 ui.Save 對應基底常數，未列故障；duck 已涵蓋單軌／分軌，同名 play_music 有重入短路。

B．英文文案（保留原佔位符）

| key | 原文 | 建議 |
|---|---|---|
| ai_hidden | AI army\nrevealed at battle | AI army\nrevealed when battle starts |
| enemy_hidden | Opponent army\nrevealed at battle | Enemy army\nrevealed when battle starts |
| blurb_3 | Charges after 3 cells; hide armor halves arrows; flanks to archers | Charges after 3 cells; hide armor halves arrow damage; flanks archers |
| blurb_7 | Heals the most hurt ally nearby; holds back while fighters remain | Heals the weakest nearby ally; holds back while fighters remain |
| blurb_9 | Breaches shields and pikes (no taunt or block, take more damage); can't be knocked back; weak to arrows | Breaks shield and pike formations (disables taunt and block, increases damage taken); resists knockback; weak to arrows |
| blurb_11 | Raider: charges in and explodes; shot down early, it hurts allies too | Raider: charges in and explodes; if killed early, blasts allies too |
| blurb_12 | Raider: disguised and untargeted; bites hard and heals when enemies come close | Raider: disguised and can't be targeted; bites and heals when enemies approach |
| blurb_15 | Binds the enemy straight ahead and passes it half the damage it takes | Binds the enemy directly ahead, sharing half its incoming damage |
| res_top_enemy | %s dealt the most enemy damage. It is weak to %s. | Enemy %s dealt the most damage. Counter it with %s. |
| intro_s3_pad | Press %s when you're ready. Once the battle starts nothing can move, and the enemy appears. | Press %s when ready. Battle reveals the enemy and locks your formation. |
| lbd_time_of | Looks only; rules are unchanged. | Visual only; rules stay the same. |
| ph_l1 | ① Direction | ① Strategy |
| ph_applied | Three-star answer placed. Hit Start to watch. | Three-star solution placed. Press Battle! to watch. |
| ph_locked | Clear it once (1★) to see which units the three-star answer uses. | Clear it once (1★) to see the three-star solution's unit counts. |
| ph_reveal_q | This places the three-star answer on the board and replaces your setup. Sure? | Replace your formation with the three-star solution? |
| leave_body_gauntlet | Expeditions save between battles; this battle will not be kept. | Gauntlet progress saves between battles. This battle won't be saved. |
| gr_go | Continue expedition | Continue Gauntlet |
| daily_mut_7_d | This week: Fantasy army, %d gold, %d units, both sides get %s | This week: Monsters, %d gold, %d units, both sides get %s |
| lb_map_fantasy_note | Terrain maps are not balance-certified; the Fantasy army wins less often here in AI battles. | Terrain maps aren't balance-tested; Monsters win less often here against AI. |
| reason_bothwipe | Mutual wipe-out | Both sides wiped out |
| reason_time_even | Time up — even | Time's up — tied |
| reason_empty | An army is empty | One side has no units |
| rv_title | Review: what if you changed one unit | Review: change one unit |
| rr_turn_too_small | Each turn's gold can't buy a fighter | Gold per turn is too low for a fighter |
| err_cantskip | You must place at least one unit while you can afford it | Place at least one unit if you can afford one |

結論：修完再繼續
