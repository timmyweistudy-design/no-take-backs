# 三方共同擬定：《落子無悔 No Take-Backs》整個專案的優化方案（輪 1，獨立初審）

使用者原話：「和三方共同擬定整個專案的優化方案，所有面向都要包括到，可以查資料，先不要實作，列出三方綜合完整版給我。」
這一輪你**獨立**提出你的完整優化建議（不會先看到另一位的意見）。只擬方案，不改任何檔案。一次呼叫就結束，不記得以前對話。

## 專案現況（2026-11-01，Claude 已驗證）
- 類型：可愛 Q 版、斜俯視、派兵自動對決，Steam 買斷小品。擺好兵按開戰後不能操作。使用者最想要「對決時勝負很激烈」。
- 企劃 v1.0（三方擬定）：16×9 格、每邊部署 6 欄、100 金、每隊 24 隻；90 秒、60 秒起狂熱（攻速×5/4＋遞增耗損）；三戰兩勝；同機「輪流落子」（預設，公開輪流每手 1～10 金、不能收回）＋「約定盲擺」；Remote Play Together；原生線上延到 v1.1；里程碑 M0～M9。
- **火柴人原型已完成**（Godot 4.6、GDScript、全部程式繪製）：擺放／移動／移除、對 AI（6 套陣型隨機）、輪流落子、三戰兩勝、五兵種全部特性、拔河條、狂熱、最後時刻慢動作＋鏡頭拉近、特殊跳字、死亡小靈魂、MVP、重播。
- **沒做**：教學、挑戰關、遠征、障礙物、音效、正式美術、手把、存陣型、盲擺、戰報細節、Steam 整合、AI 難度分級。
- **測試**：30 項 headless 全過；Windows exe 與 Linux 指紋相同（612786773464）；加的規則都驗過「改壞會紅」。
- **效能**：GDScript 一場 48 隻約 0.36 秒（中位）、最長 1.2 秒。即時遊玩沒問題，但平衡報表 552 場要約 8 分鐘；企劃原本假設每場 20ms。
- **平衡 F1 剛套用**（數值、10 組實驗都在 docs/2026-11-01-balance-proposal.md）：
  - 剋制 10/10。
  - 一局中位數 50 秒。
  - 勝方剩餘戰力中位數 26%，碾壓局 9%。
  - 陣型勝率 23%～64%（刺客陣偏弱）。
  - 限制：只測純兵種方陣＋6 套 AI 陣型，萬用陣搜尋還沒做。
- **Codex 原型審查留下的 3 項**：
  - 交戰面向每 tick 重算、沒有鎖定。
  - 衝鋒允許小角度逐步轉彎累積。
  - 多刺客同 tick 打同一劍士時，反擊對象依編號決定。
- **素材**：使用者桌面一批 Q 版 64×64 LPC 排版四方向像素角色（弓兵、盾兵、哥布林、骷髏、殭屍、礦工）＋斜俯視地圖包。**沒有劍、沒有馬**；原始來源與授權使用者還在找。
- **還沒有**：真人試玩、GitHub remote、Steamworks 帳號、任何行銷。
- **使用者已定案**：
  - 名稱《落子無悔／No Take-Backs》。
  - 輪流落子預設。
  - 斜俯視。
  - 用桌面素材。
  - 首版不做原生線上。
  - 不做課金與局外養成。
  - 開發者：Claude 寫全部程式，使用者負責試玩、決定、帳號與付費；Claude 不能畫圖。
- **三方協作規則**：
  - Claude 唯一改檔。
  - Codex 唯讀審查。
  - Antigravity 隔離、按需啟用。
  - 每批最多三輪。
  - 額度失敗不算通過。
  - 測試要「改壞會紅」。
  - build／發佈要使用者當次授權。

## Claude 先查到的資料（請在你的建議裡引用或修正）
1. **LPC 素材授權**：
   - LPC 基礎素材是 CC-BY-SA 3.0／GPL 3.0 混合，逐檔作者見 CREDITS。
   - CC-BY-SA：必須署名；改作要以 CC-BY-SA 釋出；社群整理寫「不得加密或保護」（DRM 疑慮）。
   - GPL：改作須 GPL。
   - 部分作者另有 OGA-BY。
   - 來源：https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles 、https://github.com/Scriptura/LcpCharacterGenerator （社群整理，非官方條文）。
   - **使用者的素材是否 LPC 衍生、用哪個授權，尚未確認。**
2. **Steam Deck**：
   - 1280×800 下最小字 9px（建議 12px）。
   - 圖示要對應輸入裝置，建議用 Steam Input。
   - 來源：https://partner.steamgames.com/doc/steamdeck/compat
3. **Remote Play Together**：有本機多人的遊戲自動支援；商店頁要明示（二手來源，2019 報導）。
4. **Next Fest**：
   - 業界整理：Next Fest 前有 2,000+ 心願單的遊戲才會明顯起飛。
   - 試玩版提早半年～一年上架的效果較好。
   - 來源：https://howtomarketagame.com/2025/03/26/archive-january-2026-benchmarks-how-many-wishlists-can-i-get-from-steam-next-fest/
5. **競品**：
   - Mechabellum（戰術自動對戰，US$14.99，Very Positive）。
   - Totally Accurate Battle Simulator（物理沙盒擺兵，Overwhelmingly Positive；評論批評 AI、多人、內容深度）。
   - Super Auto Pets（Very Positive，中位遊玩 3.3 小時）。
6. **名稱**：Steam 搜尋沒看到同名「No Take-Backs」遊戲（只搜過 Steam，商標未查）。
7. **GDScript 效能**：
   - Godot 官方論壇引述：C# 在單純運算約為 GDScript 4 倍，C++ 再快一些；跨語言呼叫有額外成本。
   - 加上靜態型別的 GDScript 能縮小差距。
   - 來源：https://forum.godotengine.org/t/state-of-gdscript-vs-c-performance-in-godot-4-0/5875

## 輸出格式（繁體中文，≤3,500 字）
1. **逐面向建議**（見下方 A～T 清單）：每項寫「現況問題 → 具體做法（數字、規則、工具）→ 優先度 P0～P3 → 放在哪個里程碑 → 怎麼驗收」。查到的資料附網址。
2. **前 10 名最優先的優化**（排序＋理由）。
3. **你認為企劃或原型目前最大的錯誤或盲點**（最多 3 個）。
4. **給另一位隊員的問題**、**只有使用者能決定的問題**（最多 3 個）。
