### 《落子無悔》V1.3.0 實作審查（第 2 輪）

#### 1. 第 1 輪必修解決狀況
* **雙武器重影（已解決）**：[`turn_strip.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/turn_strip.png) 最右格重影已消除。
* **盾馬透視與武器切臉（部分解決）**：盾兵大盾不縮、外推 `3px`、馬身保底 `0.58` 與史萊姆拉高皆已到位，劍兵也避開五官；但**騎兵與長槍兵在第 4、5 格（`cos 0.3`）長矛／槍桿仍直線貫穿雙眼正中央**。
* **木座、粉筆線與介面削角（已解決）**：粉筆虛線降彩偏粉白後自然許多；[`ui_tex_new.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/ui_tex_new.png) 改為低頻削角後消除了破圖毛邊感；木座加寬至 `rx 21`（部分見於 [`36_fantasy_late.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/36_fantasy_late.png)）立體感明確。
* **走勢圖標示（未解決）**：[`05_result.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/05_result.png) 前段曲線仍被尾段全滅壓平貼齊中線，且無縱軸放大或刻度標示（若不改動曲線演算法可轉為建議項）。

#### 2. 新增項目（P1）視覺檢視
* **死亡「倒棋」（[`sheet_zh_100.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/sheet_zh_100.png) 右上格）**：側倒 90° 躺平非常契合戰棋物理感，但**倒下後的單位頭頂仍殘留半透明血條**，且倒臥旋轉軸心偏高，導致身體浮在木座上方而非躺在座面上。
* **金幣條改木槽木珠（[`02_place.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/02_place.png)、[`sheet_en_150.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/sheet_en_150.png) 頂部）**：目前僅見一排無底襯的高彩度小圓點（藍／綠／紫／橘），缺乏「木槽凹軌」與木珠溫潤感，在 `150%` 介面下圓珠過小像一般狀態點。
* **受擊閃白與符號上限（[`03_battle.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/03_battle.png)、[`36_fantasy_late.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/36_fantasy_late.png)）**：整隻純白剪影在混戰團回饋清晰，頭頂符號與跳字壓下停住的層級乾淨，未再發生遮擋。

#### 3. 剩餘必修（3 條）
1. **倒棋隱藏血條並貼合木座**：進入死亡倒棋時立即關閉血條，旋轉軸心下移使棋身確實躺在木座上。
2. **騎兵與長槍兵 `cos 0.3` 槍桿避臉**：[`turn_strip.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v130-impl2/agy/turn_strip.png) 第 4、5 格長柄武器微幅外移或斜傾，避開雙眼中央。
3. **金幣木珠補上木槽底軌**：於頂部圓珠列底下加上深色內凹木槽底條，並微調木珠高光與降彩度。

結論：有條件同意（修完上述 3 條：倒棋關血條貼木座、騎槍轉身避雙眼、金幣珠補木槽底軌即可過關）
