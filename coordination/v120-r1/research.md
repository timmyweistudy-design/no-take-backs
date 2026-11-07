# V1.2.0 研究筆記（Claude 查的資料）
- 現況盤點：音樂與戰鬥音效全部程式合成（22050Hz 單聲道、戰鬥曲約 14 秒循環、4 軌疊加）；介面音 Kenney CC0。兵 22 種全部程式向量（正圓、等粗外框同一深紫、平塗）。只有平原用外部美術（Cainos 草地＋9 植物），其他 5 張地圖程式色塊。介面全部即時繪製方框、程式圖示 40 個。換畫面瞬間切換；按鈕只有變色＋按下縮 2.5%。沒有粒子、沒有後製。字型：內文 Noto Sans TC（子集化、Regular／Bold）、標題 ThenKhung（子集化）；字級表固定、不縮字；有黑色描邊。
- Balatro：東西從不完全靜止（懸浮、朝游標傾斜、翻面彈簧回彈＋小隨機旋轉）；回饋就是產品本身。https://blakecrosley.com/zh-Hant/guides/design/balatro
- 手繪感：線條微抖（每 2 幀換位移）、線寬變化、紙紋疊加、陰影用排線。Godot 有現成著色器。https://godotshaders.com/shader/line-jitter-stroke-shake-effect/
- Godot 4 2D 免費著色器包：外框、受擊閃白、溶解、閃光、剪影。https://forum.godotengine.org/t/2d-fx-essentials-nine-free-sprite-shaders-for-godot-4-outline-dissolve-hit-flash-shine/145788 ；調色／LUT／暈影：VesperaFX。
- 介面微互動：懸停／按下 150～250ms 減速；覆蓋層 300～500ms；進場減速、離場加速；按下縮到 0.98；彈簧不要太誇張（這是 UI 不是卡通）；要尊重減少動態設定。
- 音效：錄音撞擊＋合成呼嘯＋低頻重量分層；素材庫用太多會「跟別的獨立遊戲一樣」；風格要一致。
- Steam：小膠囊先設計（最小尺寸也讀得到標題）；預告片開頭就是實際遊玩；至少 5 張真實截圖。
- 字型：jf open 粉圓（OFL 1.1，改作自小杉圓體＋1477 台灣常用字＋注音）、源泉圓體（OFL 1.1）、芫荽（衍生自 Klee One，手寫感）、霞鶩文楷（楷書風）。OFL 可商用、可內嵌，要附 OFL.txt、不能單獨販售。遊戲排字：一個有個性的標題字＋一個好讀的內文字；每套 2～3 個粗細；小字要在真實背景上測。Godot 4：MSDF 描邊時像素範圍至少是描邊寬度 2 倍；Label 陰影是硬邊、要降透明度柔化；LabelSettings 可共用。
- 版面：好介面靠層次、間距、克制、一致；留白讓重點被看到；cozy 風格建議圓潤字、寬鬆間距、暖色、像筆記本分頁的導覽。

## 補充（第一輪進行中查的）
- 源泉圓體（GenSenRounded2，ButTaiwan，OFL 1.1）：6 個字重 EL／L／R／M／B／H，v2.100。https://formulae.brew.sh/cask/font-gensenrounded https://github.com/ButTaiwan
- jf open 粉圓（OFL 1.1）：改作小杉圓體＋1477 台灣常用字＋注音；字重少（主要一個）。https://mrmad.com.tw/justfont-jf-open-font
- 霞鶩文楷 TC（OFL 1.1）。https://fontsource.org/fonts/lxgw-wenkai-tc/about
- 芫荽（衍生自 Klee One，手寫感）。https://blog.justfont.com/2024/12/openfont/
- Sonniss GDC 音效包：免費、商用免版稅、不用署名；新版禁止拿去訓練 AI。https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/ https://rekkerd.org/sonniss-releases-gdc-2026-game-audio-bundle/
- 音樂外包行情：獨立遊戲約每分鐘完成曲 200～1,000 美元（常見約 400）；授權曲包每首約 20～300 歐元。https://www.twine.net/blog/video-game-music-cost-guide/ https://orphiq.com/resources/video-game-music-composers
- Kingdom Rush：美術目標是「細節很多的卡通風」，辨識度也靠清楚的聲音提示。https://www.gamedeveloper.com/design/kingdom-rush---the-wonderful-campaign-level-design

## 補充 2（第二輪進行中）
- Fredoka（OFL 1.1）：5 字重 300～700 可變字型；Fredoka One 只有 400。tnum 未確認，要開字檔查。https://fontsource.org/fonts/fredoka/about
- 芫荽（Iansui，OFL 1.1）：以 Klee Semibold 改作、合台灣教育部字形，Google Fonts 稱適合內文；字重看起來只有一個（要到 ButTaiwan/iansui 確認）。https://fonts.google.com/specimen/Iansui/about
- Slay the Spire：手繪 2D 是為了省成本，把力氣放在卡片與 UI；評價一致稱介面乾淨、顏色編碼清楚。https://www.greenmangaming.com/blog/how-slay-the-spire-became-the-gold-standard-for-all-card-battler-games/
- Cult of the Lamb：美術總監說一開始偏卡通，刻意做「可愛 vs 陰森」反差。https://unity.com/en/blog/games/recipe-behind-smash-hit-cult-of-the-lamb
- 桌遊沙盤感：WARTILE 用木製展示盒與桌面框住遊戲系統；移軸（景深）讓場景像模型；但用太多會讓棋子失焦。https://80.lv/articles/wartile-illusion-of-tabletop-gaming https://jovixie.pages.dev/posts/the-best-use-of-tilt-shift-in-games
