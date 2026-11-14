必改 4 項：

1. [game_screens.gd:120](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:120)：開機未同步 `voice_vol／mono`，人聲存為 0，重開仍以 70% 播放。[game_menus.gd:733](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd:733) 切單聲道只呼叫 `_apply_master`，也未更新聲像旗標；應統一套用。
2. [sfx.gd:485](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/sfx.gd:485)：人聲調至 0 時直接返回，正在播放的片段繼續發聲；應立即停止或更新 Voice 匯流排音量。
3. [save.gd:138](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd:138)：音量範圍清理漏登 `voice_vol`，匯入超界值可放大人聲；補上 0～100 限制。
4. [battle_view.gd:551](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:551)：死亡事件只有 `id`，沒有 `src`，死亡與倒座音因此永遠居中；應以死者位置計算。

其餘：新匯流排順序、去重及送回正確，未寫版面檔；鏡頭換算與事件後歸中正確，快轉不播事件音。人聲列、木軌及音量表已登記，CLEAR_KEYS 無須加入設定鍵。人聲亂數獨立於模擬與畫面；減少特效仍保留字幕、人聲。主音量 0 僅衰減至 −80 dB，非硬靜音。

[test_sound_v140:2082](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:2082) 未涵蓋上述回歸；FakeSfx 欄位齊，但 `play_voice` 空白，應記錄呼叫供驗證。本次僅靜態審查，未執行測試。

結論：有條件
