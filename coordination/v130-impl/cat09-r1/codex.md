只讀靜態審查及 WAV 量測；未啟動 Godot、未跑版面截圖。必改 5 條：

1. **P2 邊界仍低估**：[ui_base.gd:1490](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1490)。提環實際外伸約31.5px，卻只算26；case 合頁陰影右伸12，算10；book 書脊陰影下伸9，算6。`screen` 仍可能放過越界，須含描邊／陰影並補臨界測試。

2. **P2 跳轉後變體不一致**：[sfx.gd:366](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/sfx.gd:366)。只在開戰 reseed；`replay_view.gd:132` 跳轉未還原 RNG／上一變體，快轉也不消耗音效亂數。同一 tick 重複跳回後聲音依先前操作而變；須依事件決定變體，或重建音效亂數狀態。

3. **P2 緊張環境音殘留**：[battle_view.gd:129](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:129)。離開戰鬥未清 `room_tense_target`；若最後為緊張狀態，結果頁、大廳仍持續700Hz低通及半音量。須在戰鬥結束／離場重設。

4. **P2 便籤尺寸未隨文字變化**：[game_place.gd:618](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:618)。紙寬300、模式文字允許380；150%比分文字框底約y59，紙底僅49，跨入y52資訊帶。須按實際文字框配置紙張並保留圖釘空間。

5. **P2 環境響度未達宣告**：[room_ambience.py:51](/mnt/c/Users/timmy/projects/no-take-backs/tools/gen/room_ambience.py:51)。峰值限制再次縮小正規化結果；實測近／中／遠為−33.6／−33.4／−35.2 dBFS RMS，低於宣告−30～−24，之後還乘層增益及0.22。須調整動態並重測混音。

其餘：獎盃架及右側絲帶已收回；HUD結果頁、手把、簡化分支合理，未見教學依賴。RoomFar經Ambience送Master，夜間／單聲道可涵蓋；headless未啟播、子節點隨父釋放。22種材質映射未見漏項。

結論：有條件
