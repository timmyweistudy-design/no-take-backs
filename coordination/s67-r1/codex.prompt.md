# 程式輪 S5 第 2 輪＋S6＋S7（Codex 唯讀）

請看 `git diff cdb440e HEAD -- game/`（wav、png、字型、counter_lib.json 不用逐行看）。

**S5 修正**（你上一輪 coordination/s5-r1/codex.out.md 六點）：
- battle_code 帶 ba／bb 預算並驗證 1～400。
- watch_code() 初始化陣型、比分、局數；watch_mode 時結果頁不接「下一局」。
- _rv_set_type 在副本上換，失敗保留原兵；review_desc。
- _seek：用 _collect_mark 重建標記、ev_count；推到剛好 target；slow_used／clutch_tick／frenzy_seen／音樂重建。
- 鏡頭：follow 優先、其次最後時刻、否則回全景。
- 測試：預算來回、跳轉停在 60 且狀態一致、標記一致（含跳到結尾附近）、看代碼初始化、買不起保留原兵。

**S6**：
- balance_report Wilson 區間、valleague（formations.validation_pool）、turns:<rule>@<level>。
- ai_turns：困難落子 AI 只有 snake5c 才提早收手。
- tools/make_counter_lib.gd：24 原型、版本欄位、對驗證池量困難 vs 普通。
- game_screens.counter_lib_entries 版本檢查。
- 結論在 docs/balance-runs/s6-decision.md。

**S7**：
- main._draw_capsule 重寫。
- 標題選單分組與漸層遮罩。
- 地面草塊與小花（_draw_field）。
- sfx 三軌音樂（play_layers、layer_targets、_process 平滑）。
- Windows Demo 匯出設定＋OS.has_feature("demo") 的願望清單列。

Claude 已驗證：測試 118/118、版面檢查 102 張 0 違規。

請找：正確性 bug、假綠燈。特別看：
- 三軌音樂與 play_music 的切換（狂熱、回標題、靜音、音量設定變更）
- 反制庫工具的 duel 方向是否正確
- valleague 的報表完整性檢查
- 跳轉後再跳轉
- watch_mode 的殘留

繁體中文、≤1,200 字，每點附檔名:行號與建議修法，最後一句給「可否繼續」。
