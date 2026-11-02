# 《落子無悔》第四輪新兵種實作畫面複查（第 2 輪）〔G〕

---

## 1. 第一輪問題是否解決（逐條核對）〔G〕

### A. 五種新兵動作與造型細節（[13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/13b_poses_new.png)、[12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/12_fx.png)）〔G〕
1. **長槍兵鍋盔高光、紅纓放大、專屬拒騎動作**：**已解決**。鍋盔頂部已加亮邊、紅纓更醒目，第 7 欄「專屬」已改為頓槍斜立＋槍尖銀白十字星芒，與待機明確區分。
2. **投彈兵黑彈反光斑、專屬點火棒敲擊動作**：**已解決**。黑彈左上角已加灰白反光斑；第 7 欄「專屬」已收起肩上黑彈、改右手持短點火棒帶小火花前敲，貼身狀態一目了然。
3. **醫者施法動作幅度加大**：**已解決**。「揮擊／專屬／交替」已改為身體後仰、高舉長杖過頭且杖頭綠球放大發光，不再像木頭人。
4. **鼓手敲鼓幅度加大、紅隊帽身改深酒紅**：**已解決**。[13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/13b_poses_new.png) 雙手鼓棒高舉開合角度明顯拉大；[12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/12_fx.png) 右側紅隊鼓手帽身已改為深酒紅，不再與紅旗撞色。
5. **狂戰士斧刃加亮銀刃口、專屬雙斧高舉動作**：**已解決**。雙斧刃口銀白高光清楚，第 7 欄「專屬」已改為雙斧高舉過頭的下劈預備姿。

### B. 排版與介面問題〔G〕
6. **[16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/16_review.png) 覆盤 10 顆換兵按鈕越界**：**部分解決（仍有輕微出界）**。已從寬文字鈕改為單排 10 顆頭像方格，10 隻兵皆可見；但**第 10 顆（狂戰士）仍往右凸出彈窗邊框外約半顆寬度**。
7. **[19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/19_codex_new_en150.png) 圖鑑英文 150% 遮擋與截斷**：**已解決（附小瑕）**。打開時已捲回頂端，左欄數值條不再被口號蓋住，左右欄皆加上獨立捲軸避免半行切字。
8. **[19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/19_codex_new_en150.png) 醫者補回 `Heal/s` 數值條**：**已解決**。左欄第 2 條已顯示 `Heal/s 19`（28÷1.5s）。
9. **[17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/17_place_new.png) 成就吐司壓底部提示條**：**已解決**。底部「投彈兵 剋…怕…」提示條已完全淨空無遮擋。
10. **[17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/17_place_new.png) 投彈盲區紅底斜線**：**已解決**。內圈 1.5 格已加上清晰的半透明紅底＋紅斜線，與外圈攻擊距離區隔明確（中央白格已確認為滑鼠游標格）。
11. **[21_place_locked.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/21_place_locked.png) 未解鎖卡鎖頭擋臉**：**已解決**。金色鎖頭已移至卡片右上角價錢位置，8、9、0 號小人臉部與帽子輪廓完整保留。

### C. 特效與跳字（[12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/12_fx.png)）〔G〕
12. **爆炸特效改鋸齒星芒＋灰煙**：**已解決**。第二排左一已改為 10 尖角橘紅鋸齒星芒＋黃白核心＋4 團散開灰煙，爆裂感極佳。
13. **音符放大加描邊、鼓舞改金色小菱形**：**已解決**。音符 `♪` 放大 1.6 倍配深咖啡描邊非常醒目；藍方騎兵頭頂可見 3 顆往上飄的亮金小菱形。
14. **破陣裂盾圖示與盾面 Z 字裂紋、補血綠字描邊**：**部分解決**。[12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/12_fx.png) 紅方盾兵的藍盾面上已有清楚的黑色 Z 字裂紋，但畫面中未見到「放大加黑邊的破陣裂盾頭頂圖示」（人群中僅紅方鼓手頭上有灰色骷髏圓圖示）。

---

## 2. 尚存或新發現的問題〔G〕

1. **【必須修正】[16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/16_review.png) 第 10 顆頭像按鈕（狂戰士）仍超出彈窗右邊框**〔G〕
   * 10 顆按鈕總寬度（約 540px）大於右欄可用寬度（約 495px），導致第 9 顆（鼓手）貼齊彈窗右框線，第 10 顆（狂戰士）直接凸出彈窗右邊界外約 35px。建議將每顆按鈕寬度縮小 4～5px（或間距縮減 2px），讓第 10 顆右緣與下方勝率條右緣切齊。
2. **【小瑕疵】[13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/13b_poses_new.png) 第 9 欄「交替招式」長槍兵槍尖星芒被切邊**〔G〕
   * 第 7 欄「專屬」的十字星芒完整，但第 9 欄「交替招式」的槍尖更靠右，導致白色星芒右半部被面板右緣直線切斷。
3. **【小瑕疵】[19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/19_codex_new_en150.png) 背景殘留跳字與數值語意**〔G〕
   * 彈窗頂部外緣仍看得到背景戰場的 `+28`（深墨綠描邊很清楚）與被彈窗邊框切半的 `Breach! 12` 跳字；另外左欄醫者 `Range` 顯示 `0.7 cells`（貼身停步距離），與右側技能說明 `within 3 cells`（補血半徑）並列時容易讓玩家誤以為補血手短，建議醫者／鼓手的 `Range` 直接顯示 `3.0 cells`（支援半徑）。

---

## 3. 各圖評分（0～10 分與「可／不可」）與總評〔G〕

| 圖片檔案 | 分數 | 判定 | 簡評〔G〕 |
| :--- | :---: | :---: | :--- |
| [13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/13b_poses_new.png) | **9.0 / 10** | **可** | 五兵專屬動作、點火棒、高舉杖／鼓棒／雙斧與頭頂高光全數到位；僅第 9 欄長槍星芒右緣微切邊。 |
| [12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/12_fx.png) | **9.0 / 10** | **可** | 10 尖角鋸齒爆炸＋灰煙、描邊大音符、鼓舞金菱形、盾面 Z 字裂紋與深酒紅鼓手帽皆清楚美觀。 |
| [17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/17_place_new.png) | **9.5 / 10** | **可** | 投彈盲區半透明紅底＋紅斜線非常直覺，底部提示條不再與成就吐司重疊。 |
| [17_place_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/17_place_new_en150.png) | **9.5 / 10** | **可** | 英文 150% 版面乾淨、盲區斜線與窄卡三層資訊清晰無碰撞。 |
| [21_place_locked.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/21_place_locked.png) | **9.5 / 10** | **可** | 鎖頭移至右上角後，未解鎖三兵種的帽子與臉部特徵一覽無遺。 |
| [19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/19_codex_new_en150.png) | **8.5 / 10** | **可** | 已補上 `Heal/s 19` 且捲回頂端不再遮擋數值條；建議順手把醫者 `Range` 改顯示 `3.0 cells` 並隱藏背景殘留跳字。 |
| [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/16_review.png) | **6.5 / 10** | **不可** | 已改為 10 顆頭像鈕，但第 10 顆（狂戰士）仍凸出彈窗右邊框外約半顆，需微縮按鈕寬度或間距。 |

### 總評：**接近全數過關（7 張中 6 張「可」，僅剩 [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/16_review.png) 右緣微調即可結案）**〔G〕
* 第一輪提出的美術動作、爆炸／音符／鼓舞特效、盲區紅斜線、鎖頭位置與圖鑑英文 150% 遮擋問題均已高品質修復；只需將 [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl2/16_review.png) 覆盤的 10 顆頭像按鈕總寬度往左收進彈窗邊框內（每顆縮窄約 4px），即可正式通過第四輪實作驗收〔G〕。
