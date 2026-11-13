必改如下（只讀審查，未重跑 Godot）：

1. [layout_rules.gd:65](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/layout_rules.gd:65)：沒有 `face／ink` 就跳過，漏宣告會直接過關。圖鑑熱鍵、認證牌內文仍有此問題；即使重排延後，也應先宣告格子／角標並檢查漏登記。

2. [layout_rules.gd:110](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/layout_rules.gd:110)：`按鈕面積 > 圖示面積×1.2` 會排除最需要抓的緊格。例如兩者皆40×40，反而列為自由圖示。移除面積門檻，並以實際按鈕面檢查，避免把下緣厚度算成留白。

3. [ui_base.gd:1340](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1340)：圖示仍量名目正方形，未量可見本體；向量筆畫、粗框及位移可能越界。須提供各圖示實際可見框。

4. [ui_base.gd:1004](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/ui_base.gd:1004)：縮小可用寬度後，`fit` 會新增降級；在字級表內仍是縮字。應維持語意字級，以換行、加寬或重排解決。

5. [lobby_view.gd:764](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd:764)：只截短列底色，內容未受限。150% 摘要若三行，技能鈕底到710.5、認證牌到715.7，撞700底列；需依剩餘高度重排，補英文讓子／自由排兵／技能組合案例。

6. [dev_main.gd:464](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/dev_main.gd:464)：匯出仍缺墨跡、格子及宿主身分；`padding_audit.py` 仍猜框並豁免左對齊。補齊資料契約，讓離線盤點與產品規則一致。

7. [ui.gd:1828](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:1828)：搜尋公式字串不能驗產品。補實際繪製後的框、字級、宿主斷言，以及逐畫面探針數守衛；目前總數非零仍可掩蓋局部漏測。

R11／R12 獨立執行正確，退回舊寬度仍會受驗；四語縮短未見明顯語意矛盾。覆盤、接力未見下移計算漏接。

結論：有條件
