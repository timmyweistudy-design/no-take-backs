# 程式輪 R1＋R2（Codex 唯讀，第 1 輪）

第二輪方案（docs/2026-11-01-optimization-plan-v2.md）的 R1、R2 已實作，commit 9346354（上一版 ecaa886）。請看 `git diff ecaa886 9346354 -- game/`（不用看 docs、資料檔）。

內容：
- **R1**：
  - battle_sim.gd：繞翼狀態機（nav 0／1／2、到過途經點永久完成、新目標重新規劃一次、上下候選點夾在 EDGE+250 以內且離直線不到 FLANK_DETECT 就不採用、敵人進射程就結束繞翼）。
  - 騎兵追擊遲滯（chasing，reach−150）。
  - 刺客繞背目的地夾在場內。
  - 指紋加 nav／chasing，規則版本 1.2.0。
  - tools/orbit_detect.gd 打轉偵測器（A／B／C／N／T 分類＋門檻）。
  - 13 關殘局：t3、p8 重調；每關存兩組標準解，加回歸測試。
  - turn_placement.gd：5 手輪序改成 Thue‑Morse（先手 38%→48%）。
- **R2**：
  - main.gd 拆成 ui_base／battle_view／game_screens／main 繼承鏈，下層呼叫上層用 base 的佔位函式。
  - sprite_cache.gd：啟動時把 Art.unit 的各影格烘焙成圖集，戰鬥中貼圖（繪圖 p50 34→5ms）。
  - 效能量測模式 --perf。

Claude 已驗證：
- 測試 57/57（含：狀態機改回舊邏輯會紅）。
- 完整狀態鏡像 100/100。
- 偵測器：A 0、B 4、C 0。
- 平衡紅線全過（競技池 23%／碾壓 9%／42 秒）。
- 13 關驗證全過。
- Windows 截圖 9 張、效能量測。

繁體中文、≤1,500 字，附檔案:行號、標嚴重／中／低：
1. R1 的狀態機與遲滯有沒有確定性、鏡像、卡住或回歸風險？偵測器分類有沒有掩蓋真問題（例如 N、T 類）？
2. 拆檔有沒有改變行為（佔位函式、_ready／_draw 被改名包一層的 perf 量測）？
3. sprite_cache：烘焙影格與 Art.unit 是否等價（眨眼、呼吸、走路相位、攻擊相位、色盲配色、潛行半透明、受擊閃白）？headless 退回是否安全？
4. 測試假綠燈。
最後一句：這批可否繼續（可／有條件可／不可）。不要改任何檔案。
