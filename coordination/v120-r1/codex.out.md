已讀兩份文件及指定程式；全程唯讀，未跑 Godot。以下為工程估時：S＝≤1、M＝2–4、L＝≥5 人日；美術、作曲交件另計。程式路徑以 `game/` 為根。

1. **P0／M｜字型管線**：`tools/gen/build_font.py:12、21` 已收集文案與字串，但鎖死 Noto Regular／Bold。改為字型清單、來源版本與雜湊；TTC 指定字面後子集化。同步改 `tools/check_font_coverage.py:16`、`scripts/ui/ui_base.gd:323`，保留明確 fallback；單字重不得假設有 Bold、tnum。

2. **P0／S｜字型授權**：[粉圓](https://github.com/justfont/open-huninn-font)、[源泉圓體](https://github.com/ButTaiwan/gensen-font)、[芫荽](https://github.com/ButTaiwan/iansui)均採 OFL。隨包保留版權與授權全文；子集屬修改，須檢查保留名稱，必要時改內部名稱，不能只改檔名。現有 `fonts/`、`licenses/` 可沿用。[OFL FAQ](https://openfontlicense.org/ofl-faq/)

3. **P1／S｜點陣或 MSDF**：目前 `fonts/NotoSansTC-Regular-sub.otf.import:22` 關閉 MSDF。固定小字先保留一般光柵化與 hinting；縮放標題才試 MSDF，注意繁中字細節、產生耗時與記憶體。現有描邊 5px，啟用時 pixel range 至少 10，目前值 8 不足。[FontFile](https://docs.godotengine.org/en/4.6/classes/class_fontfile.html)

4. **P0／M｜文字與版面**：`ui_base.gd:477、491` 是直接畫字，LabelSettings 不會生效。陰影先以偏移、低透明度再畫一次，最後描邊與正文。描邊應依字級減薄；探針目前忽略描邊、陰影外擴。換字須重驗字寬、基線與換行；實際已有表內縮字（`:401`），並非筆記所稱完全不縮字。

5. **P1／M｜九宮格**：`ui_base.gd:547` 已快取 StyleBoxFlat，換成快取 StyleBoxTexture 後照用 `draw_style_box()`，不用重建 Control 樹。三材質、四按鈕態約 3–4 日接線。手切九塊也可，但須自行處理小框、接縫及縮放。內容留白需手動套入文字與探針。[官方 API](https://docs.godotengine.org/en/4.6/classes/class_styleboxtexture.html)

6. **P0／M｜Tween**：以穩定元件 ID 保存動畫進度，在事件／process 建立 Tween，繪製時讀值，勿每幀重建。`ui_base.gd:499` 依登記順序決定焦點，動畫不得改順序；視覺位移須同步命中框與探針。保留 `:599` 畫面世代保護，補減少動態及固定時間截圖。

7. **P0／M｜向量兵**：從 `units/kit.gd:56–72` 分離外輪廓、內線參數，明暗與固定紙紋烘進圖集；每幀貼圖成本接近原狀，但烘焙較慢。檢查武器外擴與裁切，保留 `art.gd:9` 命中相位，不動模擬。

8. **P1／M｜微抖與剪影白閃**：`sprite_cache.gd:173` 把兵畫在同一 CanvasItem，不能逐兵改 uniform 就期待各自生效。白閃可預烘共用 alpha 遮罩再疊白；微抖先做固定線形，真正 boil 需額外影格。`:17–28` 每頁可達 3072×4032，RGBA8 約 47MiB，勿直接把全部影格倍增。

9. **P2／L｜外包逐格**：另建 PNG 圖集＋影格時間、腳底錨點、命中標記與隊色遮罩資料，接入現有畫圖入口；不是換圖檔即完成。先三兵試點，工程約 5–10 日；22 兵美術另估數十人日，須驗翻面、色盲、武器裁切及修改權。

10. **P2／L｜粒子與後製**：`project.godot:31` 是 Compatibility。CPU／GPU 粒子可用，應池化、限量，避開不支援的軌跡／SDF 碰撞。4.6 有簡化 Glow，但無 HDR 2D；SDR 閾值容易連亮底一起發光，指定技能先用加法光暈貼圖。[渲染限制](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)、[Glow](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html#using-glow-in-2d)

11. **P1／M｜調色與暈影**：暈影用透明貼圖；調色先色彩矩陣，需要 LUT 再用展平 2D LUT。合併單次螢幕 shader、放在 HUD 前，避免文字變色與多次螢幕複製。`battle/battle_fx.gd:48` 已有狂熱邊框，可整合。[螢幕 shader](https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html)

12. **P0／M｜聲音**：長曲 Ogg Vorbis、短音 WAV；母帶保留無損，分軌同取樣率、長度、起點及循環點。`sfx.gd:110` 實為三軌；`:35、123、181` 鎖 WAV，需改載入。`:151` 未乘 ducking，須修混音並加匯流排、淡變；保留12聲道限制，新增3–5變體與避免連抽。音樂三軌解碼也須量測。[格式取捨](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_audio_samples.html)

13. **P0／S｜授權與切線**：逐素材記作者、網址、版本、授權、下載日、加工及憑證；Freesound 逐檔核對 CC0／署名／非商用，Sonniss 留存下載當時條款，委製合約涵蓋遊戲、宣傳、修改與分軌。[Freesound](https://freesound.org/help/faq/#licenses)、[Sonniss](https://sonniss.com/gdc-bundle-license/)

14. **P0／M｜驗收與總量**：必做約15–25工程人日，另留25%整合緩衝。依 `tools/layout_check.sh:21` 驗雙語×三字級、手把及轉場中間態；另驗 FINGERPRINT、冷烘焙、峰值記憶體與繪圖 p95≤基線+10%。這些是後續驗收門檻，本次未實測。

結論：V1.2.0 技術範圍＝字型管線、聲音混音、短轉場與烘焙角色質感必做；九宮格小範圍試點，逐格外包、動態線抖與完整後製延後。
