v0.2 已納入多數第一輪重點，但仍把幾項美術判讀當成程式事實，里程碑也有漏排。**方向可接受，尚須修訂才能定稿。**

本輪以 Python 探針核對原始碼，並追查事件→特效、重播→結算流程；未修改檔案、未重新驗收實機畫面。

**1. Antigravity 說法查核**

以下連結皆為 `game/scripts/ui/` 下的程式。

| 說法 | 查核結果與證據 |
|---|---|
| 鼓手帽「固定紅色」 | **不精確**。依 `tc.b > tc.r` 切換紅色 `#d8343d`／酒紅 `#6e1f4a`；藍方戴紅帽屬實，但不是兩隊同色。[art.gd:323](game/scripts/ui/art.gd#L323) |
| 狂戰士隊伍色只剩「褲腰 3px」 | **不實**。已有隊伍色披肩＋深色褲頭。幾何面積分別為 124.5、80，褲頭高 4 單位；不能直接換算最終像素佔比。[art.gd:175](game/scripts/ui/art.gd#L175) |
| 刺客帽固定紫色 | **屬實**，使用 `#6b3fa0`；「蓋過隊伍色、嚴重敵我不分」仍須實際尺寸辨識測試。[art.gd:237](game/scripts/ui/art.gd#L237) |
| 色盲血條旁有圓／菱形 | **屬實**，僅受傷且色盲模式開啟時顯示；含黑邊寬約 11／13 像素，不能據此斷言「比角色頭大」。[battle_view.gd:1004](game/scripts/ui/battle_view.gd#L1004) |
| 背刺是紫色 X | **屬實，但不完整**：同時產生 `flash` 的 X 與 `vslash` 方向斬痕。[battle_view.gd:380](game/scripts/ui/battle_view.gd#L380)、[1061](game/scripts/ui/battle_view.gd#L1061)、[1109](game/scripts/ui/battle_view.gd#L1109) |
| 衝鋒是橘色同心圓 | **不實**。衝鋒產生 `dust` 塵土；橘色雙圈屬盾兵嘲諷 `taunt`。[battle_view.gd:372](game/scripts/ui/battle_view.gd#L372)、[1057](game/scripts/ui/battle_view.gd#L1057)、[1119](game/scripts/ui/battle_view.gd#L1119) |
| 破陣是灰色四角星 | **不實**。破陣已產生飛散三角裂片，另有裂盾狀態圖示。[battle_view.gd:409](game/scripts/ui/battle_view.gd#L409)、[1072](game/scripts/ui/battle_view.gd#L1072)、[979](game/scripts/ui/battle_view.gd#L979) |
| 重播沒有回結算 | **缺獨立返回按鈕屬實；沒有返回途徑不實**。「直接看結果」及 Esc 都會跑完模擬再結算，並非立即返回。[replay_view.gd:26](game/scripts/ui/replay_view.gd#L26)、[battle_view.gd:6](game/scripts/ui/battle_view.gd#L6)、[game_screens.gd:835](game/scripts/ui/game_screens.gd#L835) |

另有三項既有功能被重提：弓手已有箭筒、投彈兵已有固定備用火罐包、勝方已有跳躍與舉武器。[art.gd:161](game/scripts/ui/art.gd#L161)、[165](game/scripts/ui/art.gd#L165)、[battle_view.gd:930](game/scripts/ui/battle_view.gd#L930)

**2. v0.2 仍需修正或補回的地方**

- **§6 C1-3／7／10、C3；§7 D5／D7**：改成「加強既有設計」。背水已有腳底擴散圈，狂熱已有脈衝氣場，D5「只靠音樂和文字」錯誤。[battle_view.gd:839](game/scripts/ui/battle_view.gd#L839)、[920](game/scripts/ui/battle_view.gd#L920)
- **§6 C2**：直接刪血條形狀標記欠妥；腳底圈會遭混戰遮擋，應先測縮小、按需顯示及替代提示。35～40% 隊伍色也應標為設計假設，不能當既有實證門檻。
- **§4 A1**：「第 12 秒被騎兵切到」須有事件證據，避免用含糊措辭暗示敗因；附「試試」也須對應實際可操作的覆盤入口。
- **§3 S4／S7、§14 J1**：第一輪要求被縮略：補回 Steam 離線補送、session ID 與 battle／rating 去重、封存的 commit／工具版本。
- **§3 S1、§2 R6**：補回「保留舊金標準，不隨實作一起更新」，以及「壞主檔恢復後，再遇寫入失敗仍保住好備份」驗收。
- **§4 A2、§18-2**：A2 誤指 §16；教學預設維持格子，須明列 A4 的自由排兵入門關為例外。
- **§17／§18**：R7、B4、F1～F4、K1／K3 等沒有落入里程碑；首發工期上限也遺漏。O4 尚把 P2 的騎兵改造納入「C1 全部」，凍結邊界不一致。

**3. 定稿前必須改的條件（最多 10 條）**

1. 同步更正 §0、§1.3、§6、§7、§19 的錯誤現況描述。
2. C1、C3、D5、D7 明確區分「已有」與「待改善」，重估成本及優先度。
3. C2 刪標記改為辨識測試後決定；隊伍色比例定義量測方式。
4. A9 定義各入口返回目的地，涵蓋結算重播、代碼觀看、覆盤播放及暫停；不得重複寫入比分、進度、成就或紀錄。
5. 補齊上述存檔、金標準、Steam、紀錄與封存驗收條件。
6. §17 為所有首發必要項目指定里程碑，R7 納入 O0／O1，K1／K3 不得漏排。
7. R2／S6／I3 在依賴其結果的大量 UI 修改前完成；O3 重構後重跑護欄。
8. §18-1 明定小樣通過條件；通過小樣不自動承諾十兵種全部重畫。
9. §18-2／5 統一自由排兵、首發功能及工期上限，解決 A2／A4／O6 衝突。
10. §18-3／4／6 記錄實際決策或明確預設值，讓平台、Demo 與重播相容政策能直接導出驗收矩陣。

結論：有條件可定稿