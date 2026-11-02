# 《落子無悔》第四輪新兵種實作畫面複查（第 3 輪・結案審查）〔G〕

---

## 1. 第 2 輪問題與本輪改動核對〔G〕

1. **[16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/16_review.png) 覆盤 10 顆頭像按鈕越界問題**：**已解決**。按鈕寬度與間距已縮減，第 10 顆（狂戰士）已完整收進彈窗右邊框內，不再凸出面板外。
2. **[19_codex_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/19_codex_new.png) 醫者「範圍」語意與數值更新**：**已解決**。左欄第 3 項已改標為「支援範圍 `3.0 格`」，與右側「包紮」說明（每 1.5 秒補 3 格內友軍 `+22`）及「每秒補血 `15`」完全一致；彈窗上方亦無殘留截斷跳字。
3. **[20_puzzles_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/20_puzzles_new.png) 新兵試玩 5 關定案與解鎖提示**：**已確認到位**。「新兵試玩 ★ 0/15」分頁清楚列出 5 關（長槍兵・拒騎、投彈兵・盾牆、醫者・撐住、鼓手・節拍、狂戰士・破陣），未解鎖關卡皆以灰階搭配「（再 1／3／5 場）」明確標示進度，左側小縮圖陣型辨識度佳。
4. **[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/18_battle_new.png) 平衡數值與狂戰士破陣擴散**：**已確認到位**。上下路可見更新後的「破陣！11」黑底跳字，中路紅方盾兵與長槍兵群同時套上灰色碎盾環與橘色擴散波紋，搭配醫者 `+22` 描邊綠字，清楚呈現破陣擴散 1 格與補血改動。

---

## 2. 還有什麼問題〔G〕

### 【必須修】
* **無**。所有阻擋結案的版面越界、文字遮擋與數值語意問題均已修復。

### 【可以之後再說】
1. **[16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/16_review.png) 第 10 顆按鈕右緣貼框**：第 10 顆（狂戰士）已收進面板內，但右框線剛好貼齊彈窗右邊框，若每顆再微縮 1～2px 讓右側留白與下方勝率條切齊會更勻稱。
2. **[13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/13b_poses_new.png) 第 9 欄長槍星芒微切邊**：「交替招式」長槍兵槍尖白星芒右半部仍貼到展示框右緣被切齊，僅影響展示面板。
3. **[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/18_battle_new.png) 中路團戰特效較密集**：破陣擴散至多隻盾兵／長槍兵時，灰色碎盾環、橘色同心圓波紋、`!` 與 `+22` 疊在一起略顯擁擠，日後可微調擴散環透明度。

---

## 3. 每張圖評分（0～10 分與「可／不可」）〔G〕

| 圖片檔案 | 分數 | 判定 | 簡評〔G〕 |
| :--- | :---: | :---: | :--- |
| [18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/18_battle_new.png) | **9.0 / 10** | **可** | 「破陣！11」、醫者 `+22` 與中路盾／槍破陣擴散特效清楚呈現，實戰張力十足。 |
| [13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/13b_poses_new.png) | **9.0 / 10** | **可** | 五種新兵 9 態動作、武器高光與專屬姿態完整清晰，僅第 9 欄槍尖星芒右緣微切。 |
| [12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/12_fx.png) | **9.0 / 10** | **可** | 鋸齒爆炸＋灰煙、描邊音符、鼓舞金菱形、盾面 Z 字裂紋與深酒紅鼓手帽辨識度極佳。 |
| [17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/17_place_new.png) | **9.5 / 10** | **可** | 投彈盲區紅底斜線、外圈射程、底部剋制提示與 10 張兵卡排版乾淨直覺。 |
| [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/16_review.png) | **8.5 / 10** | **可** | 10 顆頭像鈕已全部收進面板邊框內，功能與視覺皆合格（右緣略貼框屬微瑕）。 |
| [19_codex_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/19_codex_new.png) | **9.5 / 10** | **可** | 「支援範圍 3.0 格」與「每秒補血 15」語意精準、排版工整，小劇場模擬正常。 |
| [20_puzzles_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/20_puzzles_new.png) | **9.5 / 10** | **可** | 「新兵試玩」5 關主題明確，未解鎖「（再 N 場）」提示與陣型縮圖清楚易讀。 |
| [21_place_locked.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl3/21_place_locked.png) | **9.5 / 10** | **可** | 右上角金鎖頭不擋小人臉部，懸停「再打 1 場解鎖」提示清楚。 |

---

## 4. 總評：**全數過關（8 張皆「可」），可以正式結案！**〔G〕

第 2 輪唯一未過關的覆盤按鈕出界問題已修正，圖鑑支援範圍語意、新兵試玩 5 關介面與狂戰士破陣擴散表現皆已到位，第四輪新兵種實作可正式結案〔G〕。
