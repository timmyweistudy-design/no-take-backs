# 第 1 輪 Claude（主持＋產品、範圍、上線流程）

## 資料
- 上線後更新：第一個修正檔只修「影響最大、能驗證、能安全修」的；路線圖用「現在／下一步／之後／探索中」；用 Steam beta 分支先測；上線第一個月可兩週一次、之後每月。（次級資料，部落格意見）https://www.positioniseverything.net/indie-game-updates-how-to-build-a-sustainable-post-launch-plan/ 、https://www.strayspark.studio/blog/liveops-indie-developers-post-launch 、https://kindatechnical.com/game-development/post-launch-patches-dlc-and-community-management.html
- 實例：Astroneer 2026 初改月更、只修錯與生活品質；Mewgenics 上線後先出「穩定優先」修正檔、DLC 另排。https://blog.astroneer.space/?p=2312 、https://finalboss.io/mewgenics-just-shipped-a-stability-first-patch-dlc
- Godot 2D：Compatibility 對 2D 夠用；自繪大量簡單圖形省節點；同材質才合批（圖集）；要在目標機器量，編輯器數字不準。https://docs.godotengine.org/fr/4.5/tutorials/rendering/renderers.html 、https://docs.godotengine.org/ja/4.3/tutorials/2d/custom_drawing_in_2d.html
- Steam 語言：英文約 38%、簡中約 24%（2026 年中，次級來源，春節月簡中暴衝），日文約 2.6%；俄文有媒體說「重要」但這輪沒拿到可靠數字 → 請 Codex 查。

## 產品判斷
1. **1.1.0 不該是「再加一堆」**：1.0.0 還沒上架、沒有任何真人回報。1.1.0 的內容一半要等回報才知道。所以方案要做成兩段：
   - **先做（不等回報）**：工程債（命名、檢查時間、死碼）、P2 小品（印章、分類、捷徑、GIF 進度）、角色 17 種、配套工具（回報分析、Deck 預設、盲測頁、預告片素材）。
   - **等回報再定**：教學與新手流程調整、難度（殘局排序、三考門檻）、平衡。方案只放「量測方法＋決策規則」，不放結論。
2. **回報分析工具（E1）排最前**：真人試玩是 1.0.0 唯一還沒過的硬門檻；收到 json 後要能 10 分鐘內看出「卡在哪、為什麼輸、走到哪一步就停了」。
3. **命名整理（A1～A5）**：1.0.0 為了穩定延後。1.1.0 是做的好時機（上架前、沒有玩家存檔依賴檔名；存檔鍵、代碼前綴不碰）。但要和「等回報的熱修」錯開：先做命名、再收回報。
4. **新語言（N2）**：不放 1.1.0。四語的母語校對都還沒做，再加一語會稀釋；等簡中、日文校對完、看願望單地區分布再說。
5. **N4 每日歷史補打、N5 最佳解分享**：小而有黏著度，放 1.1.0 P2。N1 回報分類 P1（和 E1 一套）。N3 第二套色盲配色 P2（現在已有形狀區分）。N6 最壞規則背景重算 P2。
6. **B2 雙人輪序重播**：要新前綴（NTB8？），對「同機雙人」的分享價值低（兩人就在現場），1.1.0 不做，列「之後」。

## 我認為 1.1.0 必做前 12 條
1 回報分析工具＋遊戲內回報分類（E1＋N1）；2 熱修流程文件（beta 分支、修正檔範圍規則、更新說明範本）；3 命名整理 A1～A5（一次做完、單獨一個 commit、全檢查）；4 角色 17 種（A7）；5 Deck 預設一鍵（E3）；6 統一檢查 <600 秒（B1，若可行）；7 成就分類＋章節印章＋宿敵捷徑（A15、A10、A16）；8 三考結算頁一致（B11）；9 STATE 過期句清理（B17）；10 雙人先後手量測（A9）→ 大廳說明更新；11 盲測頁＋預告片素材（E5、E6）；12 每日歷史補打（N4）。
