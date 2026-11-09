# 交接方案優化——第 1 輪後修訂稿（Claude）
依據：r0-claude.md、r1-codex.md、r1-agy.md；兩方結論皆「有條件」。查核：
- 採納 Codex「layout_check.sh 只算警告數不列明細」（查證：`warns` 有算沒印，layout_check.sh:46）。
- 不採 Antigravity「指定 LAYOUT_COMBOS 會讓張數檢查失敗」：腳本 `export LAYOUT_N=$(echo $COMBOS | wc -w)` 已跟著組數（layout_check.sh:27）。
- Antigravity 的 replay_view 路徑寫成 screens/ 下，實際是 `scripts/ui/replay_view.gd:576`；內容（*1.3、只隔約 9.6px）對。

## 一、事實修正（直接改交接）
1. §8 PID 清單刪掉 → 「開工前 `tasklist.exe /FI "IMAGENAME eq Godot*"` 確認；有殘留請使用者結束」。（本輪查到 0 個，但以開工當下為準。）
2. L3 清單改為「`grep -n 'tz(\"H1\") *\*' scripts/ui -r` 的全部候選＋偵測器全表」，手寫清單補：覆盤 `replay_view.gd:576`（*1.3）、還原／清除 `game_menus.gd:943、960`（*1.5）、首次啟動 `game_menus.gd:1246`（*1.8）、宿敵 `game_modes.gd:1213`（*1.6）。
3. `_h1` 回傳值定案：回傳**含尾的完整下緣** `center.y + 1.45×字級`（= r.end.y + 2），型別 float；呼叫端一律 `var y := _h1(...) + GAP_L`。
4. R2 等級統一：<12 FAIL、12～16 警告、≥16 通過；回寫方案 §2.2。L4 定案：最大高度內截前 N 行＋「…等 M 項」，不做捲動（確認框不放捲動，手把好操作）；回寫方案。R5／R7 重複整理（R7 只管置中副標）。
5. L2 入口定案：`_draw_bookmark()` 從材質分支（lobby_view.gd:642）移到 `_draw_lobby` 結尾（487～491 之後），兩個分支和簡化介面都會走到，且畫在紙頁之上；選中金框在書籤之後再補畫一次（或書籤避開金框）。未選分頁：**預設不畫**（A 案只要求選中的），M0a 截圖時讓使用者一起確認。

## 二、施工順序（改 §5）
- **M0a 修前基準**：commit 623d8f4 跑完整 19 組＋拼接觸表（畫中線），存 `docs/review/v152/before/`。
- **M0b 先修 L1、L2**（不承諾人時；L2 含文字槽、畫序、兩分支、簡化介面）＋L1／L2 的幾何單元測試（面板中心 640±1；書籤頂 96±1、左 x＝分頁右緣−34）→ 截圖給使用者看 A 案實際效果。
- **M0c 偵測器**：`_panel`、`_h1` 自動登記（語意明確）；`_tex_box` **不自動當容器**（31 處用在按鈕、背景、裝飾）；多欄畫面（設定、大廳、主畫面左欄）**顯式宣告欄位**；延後裝飾強制 `anchor_id`；ID、宿主、角色、漏登記守衛照原方案，不縮減。人時沿用 6～11。
- M1／M2／M3 同原方案。每段可獨立 commit＋push，結尾在 STATE 寫中斷點。

## 三、偵測器與檢查器補充
- 規則寫成「元素—宿主—關係—容差」（借 Galen 的 aligned／inside／below 斷言），不寫絕對座標。
- 間距常數 `GAP_XS..GAP_XL`（4／8／12／16／24）放 ui_base.gd；16／12 標明是**專案決策**，XAG 只當可讀性參考（Codex 指正：XAG 沒規定這些間距）。
- 新增反例：同層互蓋（L9 撤回鈕被說明欄蓋）。
- layout_check.sh 印出警告明細＋例外清單檔（`docs/ui-layout-exceptions.md`，每條：畫面、規則、理由）。
- 空／滿資料：在 dev_main.gd 加 `--shot-data=empty|full` 注入假存檔（宿敵 0／6、備份 0／10、預設 0／10、確認框最長文字、撤回鈕出現）。
- 違規時輸出疊圖（容器框、中線、違規紅框）到同資料夾，看圖時一眼定位。

## 四、交接文件結構（新增章節）
- 「第一小時」：讀 CLAUDE.md、本交接、ui-layout-rules；跑 load_all、check --quick；建快照 cg5。
- 每個 L 項的「完成定義」表：規則代碼＋截圖組＋數值。
- 「已知坑」：改區塊高要連固定區、`_tex_box` 缺圖提前 return、headless 讀內部類別卡住、Antigravity 截斷／讀錯名稱。
- 「不要做」：不縮字、不改數值、不做 B 案、PADWALK 不算排版通過、不用「0 違規」代表排版正確。
- 「收尾要更新」：CLAUDE.md 鐵則那句（V1.5.2 前）、記憶 layout-alignment-must-check、ntb-shots skill 加中線疊圖。
