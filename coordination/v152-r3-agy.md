經純讀檔比對 [`v152-r2-plan.md`](file:///mnt/c/Users/timmy/projects/no-take-backs/coordination/v152-r2-plan.md)、兩方意見檔與示意圖 [`l2_options.png`](file:///mnt/c/Users/timmy/projects/no-take-backs/docs/review/v152/l2_options.png)，第 3 輪審查回覆如下：

---

### 1. 修訂稿遺漏／矛盾的排版問題（真實會破圖／壓字，共 5 條）

1. **殘局與教學選關：標題緞帶直接壓在章節切換鈕與標題上**
   - [game_menus.gd:353-370](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L353-L370)
   - `_h1(Vector2(640, 110))` 緞帶完整下緣在 150% 時達 `y = 160.75`，但章節切換按鈕 `◀`/`▶` 寫死在 `y = 158`、標題文字在 `y = 162`。緞帶左右尾翼直接壓在切換鈕頂部（重疊 2.75px），且與標題字僅隔 1.25px，嚴重違反 R2。（修訂稿 L3 漏列此處）

2. **代碼彈窗（Codes Overlay）：150% 說明文字壓入下方按鈕**
   - [game_menus.gd:311-313](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L311-L313)
   - 說明字 `codes_hint` 頂緣在 `y = 276`，在 150% 或英文環境下折為兩行（下緣達 `y = 339`），直接壓進下方首個「一鍵自動辨識代碼」按鈕（`y = 330`）內達 9px。（修訂稿 L4 僅訂正了確認彈窗，漏列此處固定高度 400 的代碼彈窗）

3. **軍令時間軸彈窗：說明文字撞入時間軸元件頂部**
   - [game_place.gd:936-937](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd#L936-L937)
   - 若僅依 R2 將緞帶下方文字留足 16px（下移至 `y = 248.75`），下方時間軸元件因寫死在 `y = 260`，文字下緣（`y = 268.75`）直接壓入時間軸刻度 8.75px。修訂稿 L3 雖提面板加高，但未列出時間軸 Y 座標與底部「完成」鈕的連動推移值。

4. **主選單主標題：雙劍光圈左緣超出螢幕邊緣被裁切**
   - [game_menus.gd:186-191](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L186-L191)
   - 當標題字寬逼近 430px 時，木牌左緣在 `x = -14`，外側雙劍光圈中心在 `x = -18`、半徑 22px，光圈左緣抵達 `x = -40`，在視窗左界外被硬生生切平，嚴重違反 R8（可見裝飾距畫面邊 ≥16px）。

5. **設定頁底部雙按鈕：置中基準與三欄結構定義矛盾**
   - [game_menus.gd:721-722](file:///mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_menus.gd#L721-L722)
   - 修訂稿 L8 寫「群組外框置中於面板中線」，但設定頁包含左側分頁（寬 190）與右側說明欄（寬 236），若單純對全螢幕中線（640）置中，相較於中央操作列（中線 615）會明顯偏右脫節，應明確定義是以「中央操作欄」還是「全螢幕」為置中基準。

---

### 2. 紅書籤 A／B 推薦與理由

- **推薦：B 案（貼齊分頁下緣、置中、補縫）**。
- **理由**：B 案將選中分頁與羊皮紙合為一體並由接縫垂下，最符合攤開戰術筆記本的物理書籤隱喻，且完全不佔用分頁文字寬度，能徹底根治咬破金框與懸空問題。（最終呈現由使用者決定）

---

### 3. 哪一條規則／偵測器不做會再犯？

- **規則面**：**R3（依附裝飾接縫貼齊 0～1px、水平置中）** 與 **R1（模態面板水平置中 ±1px）**。
- **偵測器機制面**：**「延後繪製元件強制宣告 `anchor_id`」** 與 **「畫面必要角色宣告（零登記守衛）」**。
  - **原因**：大廳紅書籤是「羊皮紙畫完才畫」的延後繪圖元件，若沒有透過 `anchor_id` 強制對齊宿主邊界檢驗，偵測器會將其當成孤立圖形放行，跨縫懸空與咬框必會再次漏網；而模態面板若無 R1 硬性置中與零登記守衛，面板偏心 190px 的低級錯誤同樣會再度逃脫。

---

### 4. 結論

**同意定稿**：三方對規則邊界、次級容量連鎖與工期已收斂一致，上述 5 處排版細節直接併入 M1/M2 執行清單即可啟動實作。
