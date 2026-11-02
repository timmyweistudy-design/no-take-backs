# 《落子無悔》第四輪新兵種實作畫面審查（第 1 輪）〔G〕

---

## 1. 五種新兵在 Q 版小尺寸與混戰中的辨識度與修改建議〔G〕

* **長槍兵（Pikeman）**〔G〕
  * **辨識度**：扁平暖銅鍋盔＋45° 斜舉紅纓長槍，在擺放（[17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17_place_new.png)）與圖鑑頁籤中與劍士（銀盔直劍）、騎兵（馬頭水平槍）區隔明確。但在大混戰（[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png)）擠成一團時，棕色鍋盔與泥地、木盾顏色相近，槍桿也容易被前排血條與特效遮住。
  * **具體修改建議**：① 鍋盔頂部加一道高光淺金邊，提升混戰頭頂對比度；② 紅纓放大 1.3 倍並改為高飽和亮紅；③ [13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/13b_poses_new.png) 的「專屬」欄與「待機」完全相同，請補上定稿 §4.3 規劃的「拒騎：槍尾頓地＋槍尖銀色十字閃光」專屬動作幀。
* **投彈兵（Bomber）**〔G〕
  * **辨識度**：橘紅頭巾＋黃銅護目鏡＋左肩大黑彈配亮黃引線火花，在藍紅雙方陣列中都極好認，不會跟弓箭手撞臉。
  * **具體修改建議**：① 混戰或遠景時，黑彈若剛好疊在深色血條底框下會稍微吃色，建議黑彈左上角加一小塊灰白反光斑；② [13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/13b_poses_new.png) 的「專屬」欄（被貼身敲人模式）目前與待機一模一樣，建議畫出「收起黑彈、右手亮出短點火棒往前敲」的姿勢，玩家在戰場上才看得懂它被貼身廢掉拋投了。
* **醫者（Medic）**〔G〕
  * **辨識度**：五種新兵中辨識度最高。白色高方帽＋綠十字＋發光綠杖，在 [18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png) 混戰人群裡一眼就能抓到。
  * **具體修改建議**：[13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/13b_poses_new.png) 中「待機／揮擊／後搖／專屬／勝利」五格的動作幅度太小（僅木杖微傾幾度），戰場上看起來像木頭人平移；建議補血施法（「揮擊／專屬」）時改為**雙手高舉長杖過頭、杖頭綠球放大發光**，受擊時手壓高帽。
* **鼓手（Drummer）**〔G〕
  * **辨識度**：紅白羽毛高帽是全兵種最高輪廓，配胸前大圓鼓，站在後排非常醒目，完全不撞臉。
  * **具體修改建議**：① 紅隊鼓手的高帽本身也是紅底，建議紅隊鼓手的帽身改深酒紅或滾粗白邊，避免與紅隊旗幟融在一起；② 同醫者，[13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/13b_poses_new.png) 的敲鼓動作（「揮擊／專屬／交替」）鼓棒位移太小，建議把雙手鼓棒高舉開合的角度拉大，讓打鼓節奏更有動態感。
* **狂戰士（Berserker）**〔G〕
  * **辨識度**：[13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/13b_poses_new.png) 修正待機雙斧外張後，臉部已不再被擋住，火紅刺蝟頭在單體時很醒目。但進入混戰（[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png)）與紅隊交鋒時，橘紅刺蝟頭會和紅隊頭盔／小旗混色。
  * **具體修改建議**：① 將雙斧斧刃再往身體兩側外推 2～3px 並加亮銀白刃口，靠「左右雙寬刃」建立不依賴髮色的橫向輪廓；② 「專屬」欄（破陣重劈）請補上雙斧高舉下劈的動作幀，與待機區分。

---

## 2. 排版問題（越界、重疊、太小、英文 150%）〔G〕

1. **【嚴重越界】[16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/16_review.png) 覆盤換兵按鈕直接衝出視窗外**〔G〕
   * 題目雖寫「10 個頭像按鈕」，但實作畫面仍是**單排寬文字按鈕**（`劍士`～`投彈...`），第 7 顆「投彈兵」在彈窗右緣被切半，第 8～10 顆（醫者、鼓手、狂戰士）完全消失在畫面外！
   * **修正**：比照圖鑑頁籤改為 **1 排 10 個窄頭像方格（約 48～52px 寬）**，或改成 **2 排 × 5 欄** 的圖文按鈕。
2. **【嚴重遮擋／截斷】[19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/19_codex_new_en150.png) 圖鑑英文 150% 左欄與右欄被切字**〔G〕
   * 左上兵種標題與口號（`"Who's hurt? Hands up!"`）在 150% 字級下高度變高，但下方捲動區起點沒往下推，導致**數值條（Speed / Cost）與故事前半段完全被蓋住**（直接從半句 `"staff."` 開始顯示），底部紅字 `✗ Cavalry and assassins go out of` 也被下緣切斷。右側 `Patch Up` 說明文字第 3 行也被小劇場頂部切掉一半。
   * **修正**：圖鑑左欄捲動區頂部應動態錨定在口號文字下方（或口號限制字級／行高），並縮小英文 150% 下小劇場高度約 24px 讓技能說明完整顯示。
3. **【規格遺漏】[19_codex_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/19_codex_new.png) 支援兵缺少 `HPS`／`光環` 數值條**〔G〕
   * 定稿 §4.6 規定「醫者顯示 `HPS 9`、鼓手顯示 `光環 +25% 攻速`，不顯示 `DPS 0`」，但目前醫者只剩「速度、價格」兩條，完全沒顯示補血效率。請補回第一條專屬能力數值條。
4. **【重疊】[17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17_place_new.png)、[17b_place_drum.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17b_place_drum.png) 成就吐司與底部剋制提示條互撞**〔G〕
   * 「成就解鎖：暗影三連」黑底橫幅剛好壓在「投彈兵 剋…怕…」提示條正上方邊緣，且在 [18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png) 開戰後仍殘留在場上。建議將成就吐司改放到頂部資訊列下方（y≈95），或上移避開底部提示條。
5. **【範圍預覽與鎖頭細節】[17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17_place_new.png)、[21_place_locked.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/21_place_locked.png)**〔G〕
   * **投彈盲區**：內圈 1.5 格目前只有一條細紅線（[17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17_place_new.png)），沒有定稿 §4.2 要求的「紅斜線／半透明紅底甜甜圈」，很容易被誤認成增益光環；且紅圈中央（第 2 欄第 4 列）多了一格不明的米白色方塊高亮（投彈兵明明在第 1 欄第 3、5 列）。
   * **未解鎖卡鎖頭**（[21_place_locked.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/21_place_locked.png)）：金色鎖頭剛好蓋在 8、9、0 號小人的**臉與帽子正中央**，遮住了最重要的頭頂特徵。建議把鎖頭移到卡片右上角（原本顯示 `6金` 的位置）或壓在下半身軀幹上。
   * **背景跳字穿透**：[19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/19_codex_new_en150.png) 與 [20_puzzles_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/20_puzzles_new.png) 彈窗頂部外緣看得到上一場殘留的 `Breach! ×2 (22)` 跳字，開彈窗時應清空或壓暗戰場跳字層。

---

## 3. 特效與跳字（太吵或看不懂的地方）〔G〕

1. **爆炸特效不像爆炸、混戰中像同心圓標靶（[12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/12_fx.png)、[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png)）**〔G〕
   * [12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/12_fx.png) 第二排最左邊的新爆炸樣品，畫成「深棕圓環＋下半部一個小橘色五角皇冠」，造型很像倒放的鋼盔或徽章；而在 [18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png) 中路混戰疊起來時，大量橘棕色平滑雙同心圓擠成一團，既像舊版震波，也把單位腳底與破陣圖示全蓋成泥巴色。
   * **建議**：改為定稿 §4.4 的**外擴不規則橘紅鋸齒星芒（8～10 尖角）＋3～4 團散開的深灰小煙雲**，取消平滑棕色同心圓。
2. **鼓手音符與鼓舞金點太小、跟草地小花撞色（[12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/12_fx.png)、[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png)）**〔G〕
   * [12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/12_fx.png) 第二排第 3 個的金色音符 `♪` 只有草地小花一般大，顏色又與草地黃花點高度接近；在 [18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png) 實戰中完全找不到音符與腳底金點。
   * **建議**：音符放大 1.6 倍並加 **1px 深咖啡色描邊**；受鼓舞友軍腳底的金點改為繞腳底藍／紅圈邊緣往上飄的 2～3 顆亮金小菱形星點。
3. **破陣持續狀態（碎盾圖示＋盾面裂痕）在混戰中看不見（[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png)）**〔G〕
   * 題目已說明修正了「破陣跳字太多」，但當跳字減少後，玩家必須靠「頭頂持續 3 秒的碎盾圖示」判斷誰被破陣（定稿 §4.4）。目前 [18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png) 中完全看不出哪隻盾兵正處於破陣狀態。
   * **建議**：被破陣單位的血條右側（或頭頂正上方）掛一個高對比的**亮橘紅裂盾小圖示（帶黑邊）**，並在盾面上畫明顯的黑色 Z 字裂紋。
4. **補血綠字與弧線（[12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/12_fx.png)、[18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png)）**〔G〕
   * 取消黑底框後的 `+15`、`+36` 綠字與 [12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/12_fx.png) 的淡綠補血弧線乾淨好讀，建議綠字加 1px 深墨綠描邊即可在淺草地上更清楚。

---

## 4. 各圖評分（0～10 分與「可／不可」）與總評〔G〕

| 圖片檔案 | 分數 | 判定 | 簡評〔G〕 |
| :--- | :---: | :---: | :--- |
| [12_fx.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/12_fx.png) | **6.5 / 10** | **不可** | 補血弧線清楚；但爆炸樣品像倒放鋼盔而非鋸齒爆裂，音符太小且無描邊易融入草地花點。 |
| [13b_poses_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/13b_poses_new.png) | **7.5 / 10** | **可（附條件）** | 五種頭頂輪廓鮮明、狂戰士不再擋臉；但「專屬」欄五兵皆與待機重複，醫者與鼓手動作幅度過小。 |
| [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/16_review.png) | **3.0 / 10** | **不可** | 10 顆換兵按鈕未改為窄頭像或兩排，第 7～10 顆直接衝出彈窗與畫面右緣外。 |
| [17_place_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17_place_new.png) | **7.5 / 10** | **可（附條件）** | 單排 10 張窄卡三層排版很成功；但投彈盲區缺紅斜線／底色、多出不明方格高亮，成就吐司撞提示條。 |
| [17_place_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17_place_new_en150.png) | **8.0 / 10** | **可** | 英文 150% 下 10 張窄卡與底部 `Bomber Beats...` 提示條完全不擠不疊，方案 D 驗證通過（盲區問題同 17）。 |
| [17b_place_drum.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/17b_place_drum.png) | **8.5 / 10** | **可** | 鼓手暖金光環與圈內友軍微亮清楚，「協同」提示條正確；僅需移開重疊的成就吐司。 |
| [18_battle_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/18_battle_new.png) | **6.0 / 10** | **不可** | 扣除已修的破陣跳字外，爆炸同心圓糊成一團、看不見破陣持續碎盾圖示與鼓舞金點／音符。 |
| [19_codex_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/19_codex_new.png) | **7.5 / 10** | **可（附條件）** | 頂部 10 個頭像頁籤乾淨好認；但醫者漏掉 `HPS 9` 數值條（只剩速度與價格）。 |
| [19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/19_codex_new_en150.png) | **4.5 / 10** | **不可** | 英文 150% 下左欄數值條與故事上半段被標題口號完全遮擋，底部紅字與右欄說明第 3 行也被截斷。 |
| [20_puzzles_new.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/20_puzzles_new.png) | **9.0 / 10** | **可** | 「新兵試玩」分頁、陣型縮圖與「（再 N 場）」鎖定狀態非常清楚直覺。 |
| [21_place_locked.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/21_place_locked.png) | **8.0 / 10** | **可** | 灰階＋「再打 1 場解鎖」提示清楚；建議將鎖頭移離臉部中央，保留未解鎖兵種的頭頂輪廓預覽。 |

### 總評：**有條件通過（需修正 4 張「不可」項目後複查）**〔G〕
* **已驗證成功的部分**：方案 D「單排 10 張上中下三層窄卡」（含英文 150%）、圖鑑頂部 10 個頭像頁籤、五種新兵的基礎 Q 版造型與殘局分頁都做得非常紮實〔G〕。
* **必須修正才能過關的 4 點**：① [16_review.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/16_review.png) 覆盤 10 顆按鈕越界；② [19_codex_new_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-v4impl/19_codex_new_en150.png) 英文 150% 圖鑑左欄遮擋截斷＋補回支援兵 `HPS`／`光環` 數值條；③ 投彈盲區補上紅斜線／半透明底色並移開成就吐司；④ 爆炸改鋸齒爆裂圈、放大描邊音符，並確保破陣 3 秒持續碎盾圖示在混戰中清晰可見〔G〕。
