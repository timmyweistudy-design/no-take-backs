# 程式輪 R5 修正＋R6＋R8（Codex 唯讀，本里程碑最後一輪）

請看 `git diff b484147 HEAD -- game/`（字型、wav、png 不用看）。

- R5 修正（你上一輪 coordination/r5-r1/codex.out.md 四點）：播完後展示時鐘續走（_disp_tick 播完時允許到 +8 tick）；atk_hit 改序列＋pick_hit()（揮擊優先、後搖可截斷）；Art.unit_xf 改成「外層 × 姿勢內層」與貼圖一致、攻擊影格疊加不帶走路相位；新測試（已證明改壞會紅）。
- R6：AI 迷霧、戰場色調（依模式）、金色暗角、圖示膠囊、按鍵圖示 _key_hints、結果徽章卡、殘局主角頭像 PZ.hero_type()、膠囊圖構圖。
- R7：balance_report 加刺客陣指標；實驗不採用（docs/balance-runs/r7-a/decision.md）。
- R8：sfx.gd 優先權 pick_channel()、主匯流排低通 set_muffled()；save.gd migrate()（schema_version 2）；色盲 ●◆。

Claude 已驗證：測試 85/85、鏡像 100/100、打轉偵測過門檻、匯出的 Windows build 跑完 14 張截圖 0 錯誤。

請找：正確性 bug（特別是 set_muffled 在各種離開戰鬥的路徑是否會殘留低通、pick_channel 用 stop() 搶聲道的副作用、migrate 對 _read 合併預設值後的行為、Save.data 舊鍵 version 是否還有地方讀）、UI 在英文／大字（text_scale 150%）下的截字風險（_pill、_key_hints、徽章卡寬度固定 90）、測試假綠燈。
繁體中文、≤1,200 字，每點附檔名:行號與建議修法，最後一句給「可否收尾」。
