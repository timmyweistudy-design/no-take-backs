唯讀審查，不改檔。《落子無悔》第八輪實作（git diff v8-base HEAD，方案 docs/2026-11-04-fantasy-units-plan-v8.md；裁決 coordination/v8-ledger.md）。排除 tests 資料、docs。
只列能用程式證明的 bug（嚴重度排序、檔案:行號、觸發情境、後果），重點：
1. game/scripts/core/battle_sim.gd 的 _v8_*：確定性、鏡像、舊場次位元組不變（golden 已過）、生兵、羊連鎖與 _pending_blast、巫毒傷害分配（h[2] 就地改、擊殺歸屬）、時停、吸塵貓與碰撞、寶箱怪現身時 sv 改動的順序、毒圈、碎石區、stun/windup、沙盒關技能（skill_off）時的狀況、僵局。
2. army.gd NTB6、ruleset.gd NTBR3（to_code 21 欄、from_code）、battle_code.gd NTB4（decode 時 pool、apply_rules 順序、rules 空字串）。舊格式與新格式切換。
3. UI：game_screens 的 _card_types／_allowed／_gauntlet_pool（遠征 armies pool 沒設？）、_reset_place 的 pool、AI 敵方在 fantasy 卡池、hard AI、ai_turns 新兵、lobby roster 名單上限與 ai_pool_same、試玩版遮罩、Presets.make/selectable/clamp_pool、解鎖流程。
4. sprite_cache 分頁：ensure 競爭、換配色、頁淘汰後 pages[i]=null 的索引、loc 指到已淘汰頁、atlas。view_buffer 新欄位。
繁體中文 900 字內，沒證據不列。最後一行「結論：可／有條件／不可」。
