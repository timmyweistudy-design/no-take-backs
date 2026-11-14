你是《落子無悔》(Godot 4.6.2) 1.4.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 9 大類（聲音 3.0 程式部分）：規劃 coordination/v140-impl/cat09-plan.md；方案 docs/2026-11-13-v1.4.0-plan.md §9；差異 coordination/v140-impl/cat09-r1/diff.patch（音檔 game/audio/voice_*.wav 是程序合成占位，產生器 tools/gen/mumble_voice.py）。
請檢查：①聲像：SfxL／SfxR 子匯流排送回 Sfx 的建法（重複開機、匯流排順序、AudioServer 版面檔是否會被覆寫）、pan_hint 設定與清除的時機（_on_event 之外的聲音、跳轉快轉 with_fx=false、結果頁）、單聲道設定 mono 的同步（開機讀設定時有沒有設）；_cam * _upos 座標換算是否正確（放大鏡頭時）；②人聲：Voice 匯流排、voice_vol 預設 70、設定列與 VOL_KEY／VOL_PREVIEW／CLEAR_KEYS 等表是否全部登記、拖曳音量木軌（vol_press）的列表是否包含新列；play_voice 的亂數是否影響確定性（模擬或截圖重現）；③靜音、主音量 0、減少特效時的行為；④測試 test_sound_v140 與 FakeSfx 補的欄位。
附行號。最多 6 條必改，600 字內。最後一行「結論：可／有條件／不可」。
