### 1. [merged.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r2/merged.md) 七項分歧逐條裁決

1. **五顆主按鈕配置**
   * **裁決**：採 **[claude.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/claude.md) 方案為主、折衷 [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md) 的代碼入口**：左側五顆大鈕固定為 **① 對戰**（對 AI、同機雙人、自訂大廳、再來一場）、**② 遠征**（繼續／新遠征、路線預覽）、**③ 挑戰**（殘局、試煉、每日、每週、幽靈）、**④ 遊戲間**（競猜、輪抽、車輪戰、雙封蠟）、**⑤ 收藏**（圖鑑、塗裝室、戰績、宿敵戰記、重播／覆盤館）；角落／底部放 **設定、輸入代碼、離開** 三顆小鈕，新玩家在「對戰」右上掛「先從教學開始」緞帶並將教學放在對戰子卡第一張。
   * **一句理由**：五顆大鈕全部留給核心遊玩與收藏、不把「設定」升格佔用主按鈕位，且將「遠征」與「遊戲間」獨立出來最符合本作的高頻遊玩動線。
   * **代價**：設定降為角落小鈕後，手把需支援 `Start` 快捷鍵與十字鍵向下到底部小鈕的明確焦點路徑。

2. **遠程飛行與扣血的時間同步**
   * **裁決**：採 **折衷方案（延長 [`ViewBuffer.DELAY`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L8) 至 5 tick＝0.25 秒 ＋ 長距離投射物命中回饋按落地時間微延遲）**。
   * **一句理由**：現有 [`ViewBuffer.DELAY`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L8) 僅 2 tick（0.1 秒）只夠投彈兵在 [`_draw_units_of`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L583-L591) 塞入過短的火罐飛行，擴至 5 tick 可讓前搖與中短距飛行在 [`_pump_view`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L204-L231) 預知階段自然發生，對手動軍令也僅增加 0.15 秒無感延遲，不必像 [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md) 拆成兩套緩衝規則或動到 [`Sim`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L9) 模擬層。
   * **代價**：[`ViewBuffer`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd) 佇列長度從 2 增至 5，且需把弓箭、紫火、孢子統一改走與 [`bomb_tgt`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L219) 相同的預知飛行佇列。

3. **轉身做法**
   * **裁決**：採 **折衷方案（圖鑑與直接繪製支援連續角度 $\theta$ 經正面轉身；戰場烘焙圖集維持離散角度並擴為 5 個轉身角）**，在既有 [`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L63-L88) 的 [`_part`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L63) / [`_part_at`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L75) 上補齊深度 $z$ 動態繪製排序、遠眼遮擋與方件側面厚度。
   * **一句理由**：戰場走 [`SpriteCache`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd) 貼圖不可能每幀跑連續角度重繪，必須在 [`Art.unit`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/art.gd#L87) 共用一套支援任意 `turn_c` / `turn_s` 的 2.5D 部件排序畫法，供圖鑑連續預覽與 [`_TurnPainter`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L443) 離散烘焙雙向共用。
   * **代價**：需將各兵種原本寫死先後順序的 [`_infantry`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L6) 與 [`_fantasy`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L6) 改為依角度切換前後手與五官遮擋。

4. **設定結構（分頁數、要不要「常用」頁、要不要「搜尋」）**
   * **裁決**：採 **6 分頁（畫面、戰場與鏡頭、聲音、操作、遊戲與無障礙、資料）＋ 每頁常用置頂與進階收合**；**不做獨立「常用」分頁，也不做文字搜尋欄**（塗裝與大廳規則只放跳轉入口鈕，不塞進全域設定分頁）。
   * **一句理由**：手把喚出虛擬鍵盤打字搜尋極度繁瑣（見 [`_ask_code`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L44-L52) 在無 Steam 環境甚至無法輸入），且「常用」頁會造成狀態同步與視覺重複；控制總項數在 36 項內並分 6 頁，手把 `LB` / `RB` 切頁最快。
   * **代價**：必須嚴格砍除冷門與冗餘設定，確保每頁核心項目不超過 6～8 項。

5. **「遊戲性輔助」（對 AI 玩家多金、AI 降級）要不要做？算不算客製化？**
   * **裁決**：**不另立設定項，直接在設定頁提供「開啟大廳讓子設定」捷徑並複用既有 [`RuleSet.handicap`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L51) 與 [`RuleSet.ai_level`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L163)**。
   * **一句理由**：大廳規則已具備雙方獨立預算（[`budget`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L50) 30～200 金）與 AI 難度，若在全域設定再做一套「對 AI 輔助」會與規則碼衝突並製造雙重來源。
   * **代價**：無法在固定規則的挑戰模式（殘局、每日挑戰、試煉）中套用多金輔助，以維持挑戰公信力。

6. **規則預設擴充（10 格預設、固定種子、雙人讓分）要不要放 V1.5？**
   * **裁決**：**「預設擴充為 10 格」（改 [`Save.MAX_PRESETS`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L6)）納入 V1.5；「雙人讓分」已在 [`RuleSet.handicap`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L51) 支援無須重做；「固定種子」不放 V1.5**。
   * **一句理由**：[`RuleSet`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L15-L19) 規則碼目前已演進至 `NTBR5`，新增固定種子需定義 `NTBR6` 並動到模擬器 RNG 初始化，而把 `MAX_PRESETS` 從 5 改 10 僅改本地存檔陣列上限，成本極低。
   * **代價**：大廳「我的預設」UI 需從單排 5 顆按鈕改為可切換或雙排 10 格。

7. **人時估計（[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) 必做 75 小時 vs [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md) 672～1,060 小時）**
   * **裁決**：採 **折衷之 160～220 人時**（約 4～5.5 週單人全職工時）。
   * **一句理由**：[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) 的 75 小時嚴重低估了 22 種兵逐一調校 `_draw()` 座標、[`SpriteCache`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd) 圖集烘焙與四語版面回歸的耗時；而 [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md) 的 672～1,060 小時把百項膨脹設定、新戰鬥規則與跨平台外部實測全部灌入，超出單一中版號合理範圍。
   * **代價**：必須將非核心玩法（如戰術試驗桌、選單朗讀 TTS、新規則碼格式）移出 V1.5 必做範圍。

---

### 2. 客製化清單聯集去重、問題診斷與 V1.5 最終清單

#### (1) 三方提案聯集診斷（重複、放錯分頁、未走規則碼、手把難用、過度膨脹）

* **重複項目（三方命名不同但底層完全相同，應合併）**：
  * 「簡化介面」（[`plain_ui`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L10)）＝ [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md)「介面密度」＝ [agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md)「無干擾模式」。
  * 「減少特效」（[`reduce_fx`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L11)）＝ [claude.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/claude.md)「畫質高／中／低＋環境動態」＝ [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md)「畫質預設＋裝飾特效密度＋地景動態＋減少動態」＝ [agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md)「混戰特效層級過濾＋動態背景開關」（拆成 4～5 個開關只會讓玩家困惑，保留「減少特效」與「環境動態」兩項即可）。
  * 「色盲配色＋隊伍形狀標記」：現有 [`Art.ring_mark`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/art.gd#L219-L230) 與 [`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L826-L834) 已實作藍圓紅菱形，只需把「形狀標記」拆出可獨立於色盲配色常駐開啟。
  * 「動態壓縮（夜間模式）」＝ [agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md)「混戰音效自動壓限（Audio Ducking）」＝ [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md)「動態範圍＋同類音效密度」。
* **放錯分頁**：
  * **塗裝室項目（底漆、漬洗、乾掃、木座、棋盤框）**：三份提案都把它們放進設定頁的「外觀分頁」，但它們受成就解鎖限制且已有獨立的「塗裝室」畫面，放進系統設定會造成雙重入口與未解鎖項目呈現混亂；**應留在「收藏 > 塗裝室」**，設定頁不重複擺放。
  * **大廳對戰規則（預算、兵數、部署、卡池、地圖、倍率、手動軍令）**：[codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md)（B9 共 28 項）與 [agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md)（類別七共 10 項）把它們列進設定表；**這些屬於單局大廳規則（[`RuleSet`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd)），絕不可放進全域設定頁**，全域設定只放「對 AI 預設難度／性格」與「雙人預設落子規則」。
  * **按鍵提示圖示**（自動／Xbox／PS／Switch／Deck）：[codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md) 放在「介面分頁」，應歸入**「操作分頁」**。
  * **時段外觀（白天／黃昏／夜晚）**：[claude.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/claude.md) 放「畫面」、[codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md) 放「外觀」，但程式碼中 [`rules.time_of`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L63) 已經在大廳規則裡（見 [`_tone()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L156-L166)），全域設定只應提供「戰場時段偏好（依模式／固定白天／固定黃昏／固定月夜）」，放在**「戰場與鏡頭」**。
* **會影響模擬或規則卻沒走規則碼（嚴重違規項）**：
  * **[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) D1「軟碰撞推擠優化（Soft Separation）」**：移動與碰撞推擠在 `battle_sim.gd` 模擬層計算（[`_upos`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L145-L151) 已做純畫面 `±4px` 錯開），若改動推擠向量會直接改變尋路與接觸 tick，導致所有 V1.4 重播碼與殘局解法失效！**必須嚴禁動模擬推擠**。
  * **[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) #42「遊戲內計時器無障礙延長」**：若指戰鬥秒數（[`RuleSet.ticks`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L52) 60/90/120/150s），改動會直接改變狂熱觸發時間與勝負判定，**必須走大廳規則碼**，不能做在全域無障礙設定；擺陣階段本身無倒數計時，無須此項。
  * **[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) #54「高地（遠程+射程）／泥沼（緩速）」、#57「攻速／體型倍率」、#58「史萊姆分裂數／巫毒分傷比微調」**：現有 [`RuleSet`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd#L79-L80) 僅支援 `[hp%, atk%, speed%]` 與 12 個技能開關，並無這些欄位，硬加會破壞規則碼格式。
* **手把不好操作（應砍或改設計）**：
  * **設定頁「關鍵字搜尋欄」**（[codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md)、[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md)）：手把打字極不友善，砍。
  * **自訂文字輸入類設定**（[claude.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/claude.md)「軍隊名稱、木座刻字縮寫」、[codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md)「戰報署名、自訂視窗尺寸、自訂匯出資料夾路徑」、[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md)「自訂指揮官稱號、自訂整數種子」）：手把無實體鍵盤且跨平台檔案對話框容易卡死焦點，全部砍掉或改為預設稱號清單選擇。
  * **「邊緣捲動」與「自由平滑游標」**（[codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md)、[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md)）：本作是固定 16×9 格沙盤，自繪 UI 全靠離散按鈕焦點，引入虛擬滑鼠游標會與現有手把十字鍵導航衝突，砍。
* **做了反而讓設定變太長的項目（建議砍除或收進進階）**：
  * **建議直接砍除（共 24 項）**：介面縮放與字級拆開（會搞爆 [`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd) 等自繪版面）、175% 字級（150% 已是自繪版面極限）、背景幀率、沙盤亮度、數字等寬字型開關（直接預設做好即可，不必做成開關）、說明顯示延遲／說明固定、數值呈現（數字／量表）、安全邊界、倍速音高變調（卡通音）、觸控放大定位窗、觸控左右手按鈕配置、選單文字朗讀 TTS、多重存檔槽位、全圖鑑沙盒一鍵解鎖開關（破壞成就動機）、圖片／GIF 匯出品質設定、Steam 排行榜提交開關、診斷資料匯出。
  * **建議收進各頁底部「進階細項」摺疊區（共 8 項）**：幀率上限、垂直同步、單聲道、失焦時靜音、搖桿死區、長按時間、擺陣復原步數、試玩紀錄（[`playtest`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L11)）。

---

#### (2) V1.5 最終客製化清單（6 分頁、共 35 項，全數不影響模擬）

*頂部固定提供 3 組一鍵無障礙預設膠囊鈕：**【視覺清晰】**、**【聽覺提示】**、**【低負擔操作】**；每頁底部提供「恢復本頁預設」。*

##### 分頁 1：畫面（Display & UI）— 7 項
| 項目 | 可選值 | 預設值 | 備註 |
|---|---|---|---|
| 1. 語言（`lang`） | 繁體中文／简体中文／English／日本語 | 依系統（`zh_TW`） | 既有；首次啟動精靈第 1 項 |
| 2. 文字大小（`text_scale`） | `100%` / `125%` / `150%` | `100%` | 既有；首次啟動精靈第 2 項 |
| 3. 標題一般字型（`plain_titles`） | 開／關 | 關 | 既有 |
| 4. 簡化介面（`plain_ui`） | 開／關 | 關 | 既有；關閉羊皮紙紋與裝飾邊框 |
| 5. 視窗模式（`window_mode`） | 視窗／無邊框全螢幕／全螢幕 | 視窗 | 擴充既有 `fullscreen` |
| 6. *(進階)* 幀率上限（`fps_cap`） | `30` / `60` / `120` / 不限 | `60` | 新增；掌機省電或高刷螢幕用 |
| 7. *(進階)* 垂直同步（`vsync`） | 開／關 | 開 | 新增 |

##### 分頁 2：戰場與鏡頭（Battlefield & Camera）— 8 項
| 項目 | 可選值 | 預設值 | 備註 |
|---|---|---|---|
| 8. 預設觀戰速度（`speed`） | `0.5x` / `1x` / `2x` / `4x` | `1x` | 從操作頁移入 |
| 9. 單位血條顯示（`hp_bar_mode`） | 受傷與低血時／永遠顯示／僅選中／關閉 | 受傷與低血時 | 新增；對應 [`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L821) |
| 10. 戰鬥跳字密度（`float_text_mode`） | 標準（自動合併）／僅關鍵技能／關閉 | 標準（自動合併） | 新增；控制 [`_merge_text`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd#L119) |
| 11. 投射物與特效表現（`reduce_fx`） | 完整／簡化（關閉環境飄落物與次要粒子） | 完整 | 整合既有 `reduce_fx` 與環境動態 |
| 12. 最後時刻慢動作与聚焦（`slowmo`） | 開／關 | 開 | 既有；控制 [`_check_clutch`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L121) 與 [`_check_final`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L153) |
| 13. 戰場時段外觀（`tone_pref`） | 依模式／固定晨曦／固定黃昏／固定月夜 | 依模式 | 新增；純視覺覆寫 [`_tone()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd#L156) |
| 14. 主畫面背景沙盤（`title_bg_mode`） | 動態示範對戰／靜態棋盤 | 動態示範對戰 | 新增；省電與防動態干擾 |
| 15. 結果頁預設視圖（`result_detail`） | 精簡摘要／詳細戰報統計 | 精簡摘要 | 新增；配合 V1.4 結果頁層級整理 |

##### 分頁 3：聲音（Audio）— 7 項
| 項目 | 可選值 | 預設值 | 備註 |
|---|---|---|---|
| 16. 主音量（`master_vol`） | `0%` ～ `100%`（步進 10%） | `100%` | 新增總控 |
| 17. 音樂音量（`music`） | `0%` ～ `100%` | `70%` | 既有 |
| 18. 戰鬥音效（`sfx`） | `0%` ～ `100%` | `80%` | 既有 |
| 19. 介面音效（`ui_vol`） | `0%` ～ `100%` | `80%` | 既有 |
| 20. 環境音量（`amb_vol`） | `0%` ～ `100%` | `80%` | 既有 |
| 21. *(進階)* 混戰音量壓限／夜間模式（`audio_ducking`）| 標準／強（防爆音） | 標準 | 新增；限制同幀疊加音效增益 |
| 22. *(進階)* 視窗失焦時靜音（`mute_bg`） | 開／關 | 開 | 新增 |

##### 分頁 4：操作（Controls & Input）— 6 項
| 項目 | 可選值 | 預設值 | 備註 |
|---|---|---|---|
| 23. 鍵盤按鍵重設（`keys`） | 動作映射子面板 | 預設配置 | 既有 [`Keymap`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L22) |
| 24. 手把按鍵重設（`pad`） | 動作映射子面板 | 預設配置 | 既有 |
| 25. 手把圖示風格（`pad_glyph_style`） | 自動偵測／Xbox／PlayStation／Switch／Steam Deck | 自動偵測 | 新增；覆寫 [`_pk()`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd#L41) |
| 26. 擺放棋子確認（`confirm_place`） | 開／關 | 開 | 既有 |
| 27. 連續塗兵模式（`paint_place`） | 開／關 | 開 | 新增；可關閉拖曳連續塗兵防誤觸 |
| 28. *(進階)* 按住操作改切換與長按時間（`hold_mode`）| 標準按住 (0.5s)／延長按住 (0.8s)／改為切換 | 標準按住 (0.5s) | 新增（XAG 107） |

##### 分頁 5：遊戲與無障礙（Gameplay & Accessibility）— 5 項
| 項目 | 可選值 | 預設值 | 備註 |
|---|---|---|---|
| 29. 色盲與高對比配色（`colorblind`） | 標準（藍紅）／色盲高對比（藍橘＋底座形狀常駐） | 標準 | 既有；首次啟動精靈第 3 項 |
| 30. 陣營形狀標記常駐（`team_shapes`） | 僅色盲模式／永遠顯示（藍圓●、紅菱◆） | 僅色盲模式 | 新增；將既有色盲形狀標記開放獨立開啟 |
| 31. 鏡頭震動（`shake`） | 開／關 | 開 | 既有 |
| 32. 受擊與技能閃白（`flash`） | 開／關 | 開 | 既有 |
| 33. 雙人同機预设規則（`duel_rule`） | 蛇形 5 手／帶錢蛇形／10 兵上限／暗封／自訂 | 蛇形 5 手 | 既有；另附「前往大廳規則編輯器」按鈕 |

##### 分頁 6：資料（Data & System）— 2 項＋操作鈕
| 項目 | 可選值 | 預設值 | 備註 |
|---|---|---|---|
| 34. 備份碼匯出／匯入與分段重置 | 匯出存檔碼／匯入存檔碼／重置教學提示／重置戰績 | 操作按鈕 | 新增分段重置（保護塗裝與通關星數） |
| 35. *(進階)* 試玩紀錄（`playtest`） | 開／關 | 關 | 既有；從操作頁移入 |

---

### 3. 角色部分：三份提案技術盲點／低估成本分析，以及最先做的 6 種兵

#### (1) 三份提案在技術上做不到或成本被嚴重低估的地方

1. **忽略既有 [`SpriteCache`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd) 圖集烘焙架構與 4096px 記憶體硬上限（三方皆低估）**：
   * **現況真相**：[`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L2-L5) 註解已明載「實測 48 隻時每幀直接程式繪製要 34ms（約 15fps）」，因此戰場上**不是每幀直接呼叫 `Art.unit` 畫向量**，而是離屏烘焙進 `CELL = 192`、`COLS = 16` 的圖集貼圖，且受 `gl_compatibility` 渲染器單張貼圖 `≤ 4096px` 限制！
   * **轉身頁與記憶體瓶頸**：[`sprite_cache.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L31-L34) 的 `TURN_C = [0.8, 0.55, 0.3]` 目前只烘「待機靜止」3 個轉角（`turn_tex`），連「走路轉身（`WT_C`）」都在 V1.3.1 因為烘 2 個角度會讓貼圖記憶體暴增 `+126 MiB`（超過 104 MiB 上限）而被迫砍成只剩 `WT_C = [0.55]` 1 個角度！而且**攻擊中（`atk > 0.0`）根本沒有烘轉身格**（見 [`draw_unit`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L350-L354)）。
   * **對三方提案的衝擊**：
     * [claude.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/claude.md) 與 [agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) 假設戰場上可以每幀用連續角度 $\theta \in [0, 2\pi)$ 即時跑 `_draw()` 與 Painter's Algorithm 動態排序——這在圖鑑單隻預覽（[`_cx_portrait`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L528)）可行，但在戰場 40 隻混戰若不走圖集會掉回 15 FPS。
     * [codex.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/codex.md) 提議烘「8 個主要方向 × 全部動作（待機 2＋走路 8＋姿勢 2＋攻擊 16＝28 格）」，若真把 22 種兵 × 2 隊 × 28 格擴大 8 倍，圖集將膨脹至 **30 頁以上、記憶體突破 500 MiB**，啟動與換塗裝烘焙時間會從 0.3 秒暴增到數秒卡頓。
   * **正確技術解法**：戰場的走／攻維持正側面（左右翻面）主圖集不變；只將獨立的待機轉身頁 [`TURN_C`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L31) 從 3 張擴為 4～5 張（含 `cos = 0.0` 正面姿勢），並在圖鑑 [`_cx_portrait`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L528) 直接呼叫 `Art.unit` 呈現連續平滑 360° 轉身。
2. **誤以為目前完全沒有轉身深度機制（沒看 [`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd) 現有實作）**：
   * [`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L24-L88) 在 V1.3 已實作了 `turn_c`、`turn_s`、[`turn_body_w`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L59)、[`_part(ci, z, fwd)`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L63) 與 [`_part_at(ci, x0)`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L75)！
   * 真正的問題不是「整隻水平乘 0.3」（頭與史萊姆已經設 `fwd = 0.0` 不壓扁），而是：
     1. **繪製順序寫死**：[`_infantry`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L6) 永遠先畫披風→身體→頭→武器，沒有根據轉向正面或背面交換部件層級。
     2. **五官沒有遠側眼裁切**：[`_eyes`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L172-L208) 只把兩眼中心 `c.x` 乘上 `turn_c`，但兩眼固定畫 `dx in [-3.0, 4.0]`，導致 `turn_c = 0.3` 時遠側眼（`+4.0`）直接凸出臉頰外緣，且當 `turn_c` 接近 1（正側面）時兩隻眼睛依然像正面一樣並排在臉上。
     3. **表情疊加層錯位**：[`SpriteCache._draw_turn`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L387-L392) 在轉身格疊加 [`Art.overlay`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/art.gd#L119) 時，因為 `overlay` 的眼睛座標寫死，在 `j == 2`（`cos = 0.3`）乾脆放棄不畫表情。
3. **純 `_draw()` 向量繪製沒有「圓形遮罩（Clipping Mask）」**：
   * [claude.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/claude.md) 與 [agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) 提議用「圓形遮罩裁切遠側眼」，但在單一 `Node2D._draw()` 內無法對局部圓形做硬體 Stencil Clip，而 `Geometry2D.intersect_polygons` 對圓弧與眨眼線條逐幀切多邊形太重；**實際應改用「條件隱藏＋近邊壓扁」**：當遠側眼 X 座標超出頭半徑 `head_r - 2.5px` 時直接縮小為單側弧線或隱藏，並在臉部邊緣補畫鼻尖小凸起。
4. **外輪廓與漬洗依賴烘焙後處理 Shader（[`unit_bake.gdshader`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L220)）**：
   * [`kit.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L9-L10) 將部件內線 `INNER_W` 調細為 `1.2px`，真正粗黑外框與漬洗／乾掃是在 [`SpriteCache._post`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd#L219-L239) 對烘好的圖集跑 `unit_bake.gdshader`。這導致圖鑑 [`_cx_portrait`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L528-L548) 在轉圈時（`Art.turn_c < 1.0`）退回 `Art.unit` 直接繪製，會瞬間失去外輪廓與漬洗乾掃質感！V1.5 必須讓圖鑑肖像區也套用同一個 Shader（或單格 SubViewport），否則圖鑑轉身時畫風會突變。
5. **個別兵種機制誤判（勘誤）**：
   * **[agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v150-r1/agy.md) 把第 18 號兵誤寫為「吹箭貓」**：查證 [`fantasy.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L278-L309) 的 [`_f_cat`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L278) 與 [`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L125)，第 18 號兵是**吸塵貓（Vacuum Cat）**，背集塵桶、持吸管施放範圍吸引（`EV.VACUUM`），並非吹箭遠程兵。
   * **投彈兵（第 6 號兵）已有拋物線程式**：[`battle_units.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L583-L591) 已實作 `pot_draw` 火罐拋物線，之所以看起來像沒飛，是因為 `ViewBuffer.DELAY` 只有 2 tick（0.1 秒），火罐只閃現 6 個畫面幀就落地，且 [`_infantry`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L208) 在 `w != 0.0` 時瞬間把手上火罐藏起來，視覺交接太快。

---

#### (2) 最該先做的 6 種試點兵種與理由

建議第一批先做 **【0 劍士、2 弓箭手、3 騎兵、4 刺客、12 寶箱怪、17 骷髏法師】**（涵蓋全部技術難點，驗證通過後即可套用至其餘 16 種）：

1. **0 劍士（`D.SWORD`）— 驗證「人形標準骨架 ＋ 單手劍三明治握持（柄尾／握柄／護手／拇指覆蓋）」**：
   * 理由：目前 [`kingdom.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L87-L94) 的劍只有刀刃與護手線、缺柄尾，且手圓直接蓋在護手上；劍士跑通後，盾兵、醫者、鼓手、小骷髏的單手握持與人形轉身五官遮擋可直接複用。
2. **4 刺客（`D.ASSASSIN`）— 驗證「雙手武器前後層動態 Z 排序 ＋ 反握短刀防截斷」**：
   * 理由：`brief.md` 點名「短刀像在手的位置被切斷」最嚴重的兵種（[`kingdom.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L153-L162) 只畫兩條白線），且具備「前手＋後手」雙武器與長圍巾，是測試轉身時雙手交換前後層（狂戰士雙斧、鼓手雙棒同理）的最佳代表。
3. **3 騎兵（`D.CAVALRY`）— 驗證「長柄貫穿握持 ＋ 複合長體（人＋木馬）轉身 ＋ 圖鑑極限包絡安全框」**：
   * 理由：`codex_crop.png` 點名槍尖刺穿圖鑑名稱區的主角，且木馬是長橢圓體（[`_cavalry`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L297)），轉身時馬頭、馬身、騎士與長槍的透視縮放比例各不相同，也是長槍兵的長桿握持範本。
4. **2 弓箭手（`D.ARCHER`）— 驗證「雙手協同（左手握弓＋右手拉弦搭箭）＋ 遠程投射物與 `ViewBuffer` 時間同步」**：
   * 理由：同時檢驗 [`kingdom.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kingdom.gd#L120-L136) 拉弓搭箭錨點、離弦交接，以及 [`battle_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd#L561-L563) 箭矢飛行與扣血閃白的同步契約。
5. **17 骷髏法師（`F8.BONE`）— 驗證「奇幻軍施法投射物（書上紫火脫離飛出）＋ 平面持物（魔導書）轉身透視」**：
   * 理由：`brief.md` 點名「只在自己身上揮擊、書上紫火沒飛出去」的代表（[`fantasy.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L241-L275)），能同時驗證奇幻軍新增飛行特效與手托書脊畫法（孢子菇、投彈兵可比照）。
6. **12 寶箱怪（`F8.MIMIC`）— 驗證「非人形方體側面厚度擠出（2.5D Extrusion）＋ 開合結構轉身」**：
   * 理由：[`_f_mimic`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/fantasy.gd#L81-L115) 是純矩形箱體與箱蓋，轉身時若無側面厚度板會最像紙片；跑通寶箱怪的側面厚度擠出後，盾兵大盾、沙漏精靈外框、石魔方塊軀幹皆可套用同一套厚度公式。

---

### 4. V1.5.0 里程碑切法（M1、M2、M3）

#### M1：角色試點與驗收管線 ＋ 遠程時間同步（預估 60～80 人時）
* **工作內容**：
  1. **角色自動驗收工具（最先建）**：擴充無頭截圖工具，一鍵輸出「16 角度轉身靜態拼表＋360° GIF」、「遠程攻擊 6 階段（待機／前搖／離手／飛行中／命中／收招）逐格分解表」、「持物 4 倍放大特寫表」與「圖鑑 22 卡安全框疊圖表」至 `docs/review/v150/`。
  2. **6 種試點兵種（劍士、刺客、騎兵、弓箭手、骷髏法師、寶箱怪）翻修**：實作三明治握持層、五官球面位移與遠眼遮擋、雙手動態 Z 排序、方體側面厚度。
  3. **遠程投射物與展示緩衝同步**：將 [`ViewBuffer.DELAY`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd#L8) 擴至 5 tick，統一弓箭、投彈、法師紫火、孢子菇的預知發射與命中回饋時機。
  4. **圖鑑大圖安全框與檢視控制列**：修正 [`codex_view.gd`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/codex_view.gd#L351-L367) 肖像區縮放包絡與標題隔離，並加上「自動轉身／播放攻擊／0.25x 慢動作／角度拖曳」控制鈕。
* **驗收標準**：
  * 6 種試點兵種的 360° 轉身、持物特寫、遠程逐格表由使用者目視確認通過，無截斷、無紙片壓扁、無武器穿眼。
  * 弓箭手、投彈兵、骷髏法師、孢子菇在 1x 與 0.25x 慢動作下，皆為「前搖手上有物 → 離手飛行 → 抵達目標同幀才觸發受擊閃白與扣血跳字」。
  * 騎兵與長槍兵在圖鑑任何角度與攻擊幀下，武器尖端距離文字區與邊框至少留有 `8px` 淨空。

#### M2：全 22 兵種展開 ＋ 主畫面五大入口 ＋ 設定系統重建（預估 65～85 人時）
* **工作內容**：
  1. **其餘 16 種兵全面套用與微調**：完成全部 22 種兵（含小史萊姆、小骷髏、偽裝寶箱）的握持、轉身與 [`SpriteCache`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd) 轉身頁烘焙，並驗證貼圖記憶體不超標。
  2. **主畫面五大按鈕重構**：實作左欄 5 大牌（對戰、遠征、挑戰、遊戲間、收藏）＋右側滑出第二層卡片＋角落設定／代碼／離開小鈕，完成新老玩家教學緞帶分流與手把／觸控動線。
  3. **設定頁 6 分頁重建與首次啟動精靈**：實作左分頁、中選項（開關／分段／滑桿控件分明）、右即時動態預覽窗、頂部 3 組一鍵無障礙預設、每頁恢復預設、戰鬥暫停選單（可開純顯示／聲音設定），以及首次啟動 3 問精靈。
* **驗收標準**：
  * 全 22 種兵通過 M1 同規格的 4 套視覺驗收表與 [`anchor_log`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/units/kit.gd#L47) 武器不穿臉自動檢查；[`SpriteCache`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/sprite_cache.gd) 總貼圖記憶體控制在預算內，48 隻同場維持 60 FPS。
  * 主畫面在鍵鼠、手把（十字鍵＋A/B＋LB/RB）、觸控（1280×800 最小目標 ≥ 48px）下，從主畫面最多按 2 次確認可進入對 AI 擺陣，按返回鍵焦點 100% 記憶原位。
  * 35 項設定即時生效並通過 [`Save.sanitize_settings`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/save.gd#L89) 舊存檔遷移測試；戰鬥暫停中修改設定絕不改變模擬指紋。

#### M3：V1.4 延後層級打磨 ＋ 混戰降噪 ＋ 回歸與發版收尾（預估 35～55 人時）
* **工作內容**：
  1. **大廳與結果頁資訊層級整理**：大廳進階 7 分頁規則收合為抽屜並顯示「已修改規則摘要膠囊」、擴充規則預設為 10 格；結果頁分為主次兩層（勝負與下一步為主，重播／時光機／統計圖表／分享工坊為次）。
  2. **大量混戰視覺與聽覺降噪**：依 [`_crowd_at`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd#L184) 強化密集交戰時的普攻特效淡化、跳字合併與混戰音效壓限，突顯關鍵大招與遠程軌跡。
  3. **四語大字級版面檢查、平衡掃描與全面回歸**：補齊新增設定與主畫面之繁／簡／英／日四語字串，驗證 100%／125%／150% 字級無截斷重疊；執行 V1.4 舊重播碼、規則碼、接力殘局碼與存檔相容性回歸測試。
* **驗收標準**：
  * 40 vs 40 極限混戰下，[`text_overlap_stats`](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_fx.gd#L212) 可見跳字重疊率為 0，關鍵技能跳字與底部戰報列不漏記。
  * 四語 × 三種字級（100% / 125% / 150%）跑過全部新畫面（主畫面、6 頁設定、大廳、圖鑑、結果頁）自動化版面探針零越界、零撞字。
  * V1.0～V1.4 既有金標準模擬指紋、重播碼與規則碼 100% 通過回歸測試。
