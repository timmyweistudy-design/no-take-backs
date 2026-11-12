僅靜態讀檔，未執行測試。碎片分格正確（frags.gd:61）；戰役整卡命中區、鎖關防護及手把焦點註冊合理（game_playroom.gd:296、386；ui_base.gd:815、900）。版本為 1.2.0。以下 7 條必改：

1. **仍非雙時鐘**：[battle_view.gd:81](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:81) 停頓直接返回，模擬仍停止；慢動作減少 `_sim_step`，卻不記欠時。§9.6 與 ledger:162 的「修了」尚不成立。

2. **跳回仍播演出**：battle_view.gd:86 把欠時塞進 accum，:103 仍呼叫 `_sim_step(true)`；會密集播音效、特效並再次觸發慢動作。須以無演出路徑追到目標；超秒分支也未遵守「慢動作時不追」。

3. **跳轉殘留欠時**：[replay_view.gd:202](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/replay_view.gd:202) 清 accum、hitstop，漏清 present_debt；跳轉後會無故加速。暫停不增債、新重播開場歸零則正確。

4. **欠時單位不可靠**：battle_view.gd:83 記整幀 delta，會多算停頓尾幀；:87 又以當下 speed 換算，切倍速會改寫舊欠量。4 倍速欠 0.3 秒已落後 1.2 模擬秒，卻不跳回。須統一時間基準；game_screens.gd:633 讓固定幀截圖完全繞過此流程，不能作驗證。

5. **外部阻塞分類過寬**：[ledger:167](/mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl/ledger.md:167) 把 §6.2／6.4／6.5、§7.5 全列做不到；既有程序繪圖、塗裝與方向管線可延伸，未證明必需畫師。應拆成未做與確切外部依賴。

6. **商店截圖可獨立做**：ledger:167 把 §13.3 綁錄音、關鍵美術；方案:275 只要求五張賣點截圖與分級。改列待版面驗收／未做。

7. **口吻誤列已有**：ledger:165 只證明十張便條；方案:270 要求教學、提示、教練、宿敵、戰報全面審稿。應列部分完成，母語校對另列阻塞。

結論：不可