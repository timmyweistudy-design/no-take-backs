### 1. 上輪必修檢核與現存「必修」

**已解決：**
淺色緞帶標題（圖鑑、大廳、設定）改純墨色＋淺浮雕後極為乾淨；擺陣頁（[02_place.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/02_place.png)）三扇屏風明暗、鉸鏈、頂部木條與底部木槽質感大幅升級；戰鬥頁（[03_battle.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/03_battle.png)）內陰影與對話泡清晰度良好。

**仍存在的「必修」缺陷：**
1. **[05_result.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/05_result.png)（結果頁頂部藍緞帶下方）**：緞帶縮小後，第三行字「單兵最高：藍方刺客 (840)...」直接壓在藍色緞帶底部的金色邊框線上（文字被金線橫切），屬於明顯排版穿模。
2. **[10_codex.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/10_codex.png)（圖鑑左欄羊皮紙底部）**：綠色建議字「✓ 放在兩側中排...」仍殘留厚重黑邊，在淺色羊皮紙上糊成髒黑塊，違反「淺底字不描黑邊」原則，極難閱讀。
3. **[10_codex.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/10_codex.png) 與 [22_lobby.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/22_lobby.png)（羊皮紙頁頂端）**：羊皮紙上緣與上方頁籤（如「標準」、「4 號騎兵」）的金色選取框 0 間距緊貼甚至重疊，缺乏呼吸空間。
4. **[05_result.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/05_result.png)、[01_title.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/01_title.png)、[22_lobby.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/22_lobby.png)（放大單位）**：僅圖鑑頁換成了向量繪製＋木底座；結果頁 MVP 刺客、標題頁底部十兵種、大廳右側對陣預覽仍為像素硬放大（鋸齒明顯且無木底座），視覺風格割裂。

---

### 2. 新的羊皮紙頁是否協調？
**整體方向非常成功，但邊界與細節需收尾。**
羊皮紙打破了原本「整頁深褐木頭」的沉悶感，建立出「木盒外框＋紙本兵書」的桌上沙盤層次，墨色字體在紙面上對比極佳。但目前紙張邊緣太像銳利的純色矩形裁切，且頂部緊貼上方頁籤，建議與上方頁籤拉開 `6~8px` 間距，並在紙張四周加一圈極淡的暖褐內陰影（inset shadow）表現紙張厚度。

---

### 3. 剩下最有感的 3 件事（零預算、程式可做）
1. **大單位全面統一為「向量＋木底座」**：將圖鑑頁已做好的向量大單位與木底座渲染邏輯，直接套用到標題頁底部、大廳右側預覽與結果頁 MVP 圖示。
2. **補齊「殘局挑戰」標題緞帶（[screens.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/screens.png) 左下）**：圖鑑、大廳、設定皆有羊皮紙標題緞帶，唯獨殘局挑戰的標題仍是白字黑邊懸浮於木框上，套用同款緞帶即可統一全 UI。
3. **圖鑑右側「小劇場」加凹槽木框（[10_codex.png](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v120-impl3/agy/10_codex.png) 右側）**：目前小劇場僅用 1px 淺灰白細線框住，改用與戰場相同的深木內凹框＋四層內陰影，沙盤感會瞬間拉滿。

結論：要修正（修復結果頁藍緞帶壓字穿模、移除圖鑑羊皮紙底部綠字黑邊、拉開羊皮紙與上方頁籤間距，並統一放大單位的向量木底座繪製）
