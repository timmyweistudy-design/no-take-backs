### 阻擋

**1. §1 美術統一規格摘要缺可實作數值，尚不足以凍結**（§1 實作性／尺 1、2、5／簡化模式）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) §1（主光、主材質表、簡化介面）；對照 [r3-agy.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/r3-agy.md) S1／S2。
- **問題**：§1 宣告 R4 後凍結成 `docs/art-spec-v160.md`，但除墨色 `#2A1E15` 外，胡桃木、暖米紙、紅蠟、粉筆、舊銅均無色碼、目標灰階區間與顆粒尺度；「左上 35° 暖白」缺陰影偏移比例、柔邊半徑與透明度；「簡化介面＝保留輪廓與雙階色塊、關紋理」未定義邊框最小對比與替代底色。
- **影響**：`B03`／`B04`／`B06` 實作者無法據 §1 實作 `palette.gd` 與共用 StyleBox，`plain` 模式仍有退化為黑底系統窗之風險。
- **最小修正**：§1 補齊五材質 Base／Shadow／Highlight 色碼與灰階範圍（依 [r2-decision.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/r2-decision.md) 暗木 ≤25%、紙盤 35～65%、主層 ≥75%）、接觸影參數（偏移 px、羽化、陰影色／alpha）、顆粒尺度，及 `plain` 雙階邊框最小對比（≥3:1）。
- **通過條件**：`docs/art-spec-v160.md` 具備上述數值，且 `S1`／`S2` 產出 `14b_plain_ui` 與灰階對照確認無糊框與三階失真。

**2. §1 桌位表右緣三槽與便條釘位在 1280×800 空間撞車**（§1 實作性／R14＋英文 150%＋桌物化）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) §1 桌位表、P1.1／P1.5／P8.1；圖 `[zh-006｜`[zh_TW_100__02_place.jpg](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/zh_TW_100__02_place.jpg)`｜右緣與敵盤右上｜茶杯浮在約 115px 窄緣、翻牌條「棋館老闆・阿衡・100 金 ▼」約 260px 寬壓在盤內｜先算清盤寬與摺疊規則]`、`[zh-161｜`[fixed_zh_TW_100__v150_03f_battle_focus.jpg](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/fixed_zh_TW_100__v150_03f_battle_focus.jpg)`｜右下角｜圓形放大鏡壓住棋盤邊框，老闆與茶杯缺接觸影]`。
- **問題**：1280×800 下右緣扣除距盤 ≥16px 後僅餘百像素內，單行放不下長條翻牌與現尺寸放大鏡；且 §1「便條固定右上、左下」與 P8.1「首開左偏便條 ≤35%」及棋盤位置重疊。
- **影響**：`B03`／`B05`／`B06` 無法落地單一桌位表，`en_150` 翻牌必裁切或壓盤。
- **最小修正**：§1 明定 1280×800 棋盤最大寬度與右緣三槽實寬（或翻牌預設收合為老闆肖像鈕、展開才浮出，並納入窄緣隱藏杯墊退路）；明確區分「首開便條（標題左區）」與「局內便條（固定座標＋最大寬高）」。
- **通過條件**：`B03`／`B05` 單一座標表在 `zh_TW_100` 與 `en_150` 下三槽距盤 ≥16px、交集 0px、無字被裁。

**3. §1 與 §3／§4「1.6.0 新基線」登記時序自相矛盾**（基線升版／依賴順序）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) §1 基線升版、§3 順序、§4 `B03`／`B06`／`B08`／`B10`。
- **問題**：§1 明定 P1、P3、P4 合併**一次**登記 1.6.0 新基線，但 §3 與 §4 規定 `B06` 及量產須過「`B03 Go、新基線登記`」，而 `B08`（P3）與 `B10`（P4）排在 `B06` 之後——先登記則 `B08`／`B10` 改明度會撞線，後登記則卡死 `B06`。
- **影響**：實作進度在 `B06` 發生門檻死結，或違背一次性升版規則。
- **最小修正**：改為 `B03 Go` 先以左中右並列審片解鎖 `B06→B08→B10`；待 `P1＋P3＋P4` 全數完工並過四層觀片與 K1／K2 後，再由主持人**一次性**登記「1.6.0 新基線」。
- **通過條件**：§1、§3、§4 門檻口徑一致，全案僅執行一次基線升版並保留 1.5.0 對照。

**4. `05_result` 未納入降灰與背景戰力條收合，流程條仍斷裂**（全流程條世界一體／尺 3、5）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) §1、P1／P2.4／P6.5、`B03`；圖 `[zh-011｜`[zh_TW_100__05_result.jpg](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/zh_TW_100__05_result.jpg)`｜結果紙面與上緣｜紙面與 `[zh-053]` 同屬高亮淺底，背後透出「剩 67 秒／戰力條」HUD 與綠盤，左下炸彈與右下沙漏浮在暗緣無影｜壓紙面灰階至 35～65%、收起或遮罩背後戰力條、補器物接觸影]`、`[`[flow_zh_TW_100_gray.jpg](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/flow_zh_TW_100_gray.jpg)`｜第 2～4、9 格]`。
- **問題**：僅 P2.4 明定壓低大廳簿紙灰階（45～65%），遺漏 `05_result` 紙面與藍／綠／紅狀態旗幟（`藍方勝利！`、`平衡認證`）的字色對比規則，且背後殘留戰場 HUD 維持懸浮視窗感。
- **影響**：流程條首尾無法構成同一張桌，S2 無法過第 1 層灰階分離。
- **最小修正**：§1／`B03` 將 `05_result`（含宣紙戰報）紙面鎖定 35～65% 中灰、補齊彩色徽章／色盲底色字色對比規則（≥4.5:1），並規定結算時收合或遮蔽背後戰力條 HUD。
- **通過條件**：S2 三頁流程條灰階版中階紙盤同落 35～65%、無背後 HUD 透出。

---

### 建議

**5. 補齊非主流程頁與彈窗的六把尺覆蓋清冊及 `en_150` 頁籤保底**（六把尺全站覆蓋／R14＋英文 150%）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) §4 `B04`／`B06`／`B19`；圖 `[en-053｜`[en_150__22_lobby.jpg](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/en_150__22_lobby.jpg)`｜頂部頁籤列｜Monster Crew 與 One-type duel 雙行貼邊、左右木框僅約 5～6%｜預留雙行餘裕或縮寬時啟用保寬退路]`。
- **問題**：`B04` 只含對 AI 三步、`B06` 以「餘頁」統稱，未列清雙人／遠征／自由大廳、圖鑑、設定、出題台、暫停／確認彈窗的批次歸屬；且 `en_150` 在現行寬度已極緊，縮至 76% 簿寬極易爆框。
- **影響**：非對戰頁恐漏檢桌物化與 R14，或 `B04` 直接觸發退路。
- **最小修正**：`B06` 依 `screens.json`（見 [manifest.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/manifest.md)）補全頁數清單與彈窗規範；`B04` 寫明頁籤英文縮詞改寫並保留 S1 保寬退路。
- **通過條件**：全 200 畫面 × 24 組（含 `en_150`）裁切 0、R14 違規 0。

**6. 戰場尖峰幀補定「非 BOSS 疊層血條＋特效明度」上限**（戰場尖峰幀可讀／尺 5）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) P3.3／P3.4／P4.4；圖 `[zh-132｜`[fixed_zh_TW_100__87d_boss_battle.jpg](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/fixed_zh_TW_100__87d_boss_battle.jpg)`｜盤面上緣與中央｜「頂住！14」被頂框切半；中央三條橫血條疊壓頭目上方兵種頭臉]`、`[zh-161｜`[fixed_zh_TW_100__v150_03f_battle_focus.jpg](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/fixed_zh_TW_100__v150_03f_battle_focus.jpg)`｜中右混戰區｜音符／驚嘆號／紫黑鏈錘與橘弧疊壓近戰輪廓]`。
- **問題**：P4.4 僅規範 BOSS 血條不遮臉，P3.4 缺特效面積、明度／透明度數字上限與圖層順序，未處理多兵重疊時的疊層血條遮擋。
- **影響**：41 隻尖峰幀下非頭目交戰區仍易被血條與高對比特效糊掉剪影。
- **最小修正**：P3.4 定特效最高明度／面積上限並置於兵偶頭肩輪廓後層；P4.4 擴大為全兵種血條避讓或縮並，禁壓他兵頭臉。
- **通過條件**：S4 三張尖峰幀（`03f`、`18`、`87d`）左中右灰階對照：切框字 0、蓋兵臉胸像素 0、跳字＋勢箭頭 ≤15% 交戰區。

---

### 待驗（未實作項僅判規格是否足以驗證，不簽畫面達標）

**7. 角色剪影辨識、五方向轉身與腳底接地**（角色剪影與多方向過渡／尺 4、6）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) P4／P5、K3／K6；[manifest.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/manifest.md)（R0 缺動態連環條與錄影）。
- **問題**：R4 無動態連拍與 `460×215` 縮圖對照，無法實判重心起伏、轉身閃爍與 `59h_paint` 漬洗乾掃後底座色階差。
- **影響**：在無實機連環條前，只能審查驗證規格，不能認定 P4／P5 畫面成立。
- **最小修正**：規格已含 `P5.5` 基準補拍、K3（上 1.5／下 1.6 同 tick 關鍵姿勢連環條＋灰階接觸幀、腳滑比 ≤0.1）與 K6（5 人 × 20 題 ≥90%），已足驗證；僅須在 S3 補寫「`59h_paint` 塗裝後底座色階差 ≥10%」查核項。
- **通過條件**：S3 完成 160 姿勢組合缺格 0、腳滑比 ≤0.1、容量過 P10 預算與 K6 盲認後，始准放量 22 兵種。

**8. 簡化／色盲實機圖、音畫對拍與真人 3 秒讀勢**（尖峰幀／簡化／外部交付）
- **定位**：[2026-11-15-v1.6.0-plan.md](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v1600p/agy_r4/2026-11-15-v1.6.0-plan.md) P3／P4.2／P12、K1／K3／K6、§8；R4 圖包缺 `14_colorblind`、`14b_plain_ui` 與含音訊錄影。
- **問題**：目前缺 `plain`／色盲實機圖、帶時間戳音訊錄影及真人測試 K6 結果。
- **影響**：手把導航、音畫同步（≤50ms）與「3 秒指認推進方向」均未獲視覺與行為證據。
- **最小修正**：K1（24 組＋124 組 `_input` 擴充）、K3（含音訊時間戳錄影）、K6 與 §8 兜底揭露規格皆已足驗證，維持寫入對應批開始與放量門檻，不放行免驗。
- **通過條件**：對應批次繳交實機圖與含音訊錄影並通過四層觀片及 K1～K3；K6 未執行前發版說明必須保留「未經真人驗證」。

結論：有條件
