# 加語言（簡中、日文）前置說明

> V1.2.1 G3 整理。只做了程式前置，沒有翻譯。

## 現在的結構
- 介面字：`game/data/strings.csv`，欄位 `key,zh_TW,en`。`strings.gd` 的 `LANGS` 是語言清單的單一來源（存檔檢查也讀它）。
- 資料檔（殘局、章節、試煉、圖鑑）的文字欄位用後綴：`zh`、`en`、`hint_zh`、`story_en`…。程式一律用 `L.field(資料, "hint")` 取，`strings.gd` 的 `SUFFIX` 決定後綴。
- 二元陣列的舊資料（成就名 `steam.gd`、成就條件 `ACH_DESC`）用 `L.pick(中文, 英文)`；加語言時改成字典。
- 分隔符：`list_sep`（、／, ）、`name_sep_fmt`（・／ · ）在字串表。
- 仍依語言寫死的兩處（刻意保留）：大廳地圖大小的中文名稱（`lobby_view.gd`）、普通 AI 陣型英文名（`game_core.gd` 的 `AI_TPL_EN`）。

## 加一個語言的步驟
1. `strings.gd`：`LANGS` 加代碼、`SUFFIX` 加後綴（例：`"zh_CN": "sc"`、`"ja": "ja"`）。
2. `strings.csv` 加一欄；`tools/check.py` 的缺字串檢查會列出沒翻的鍵。
3. 資料檔加 `*_sc`／`*_ja` 欄位（沒填的會退回英文）。
4. 字型：
   - 簡中：源泉圓體只有 TW／JP 字形。簡中用同一系列的 Resource Han Rounded CN（OFL，免費），一樣用 `build_font.py` 子集化、改名，在 `_load_fonts` 依語言換後備字型。
   - 日文：源泉圓體 JP（GenSenRounded2JP，OFL）。
   - 子集只收該語言字串用到的字；`tools/check_font_coverage.py` 要加新字型。
5. 換行：`wrap_lines` 已經逐字斷 CJK，並有行首禁則（。，、）」』！？；：%）。日文另外要加小假名（ゃゅょっ）與長音（ー）不放行首。
6. 版面：`layout_check.sh` 的 `COMBOS` 加新語言 × 三字級；每個新語言至少跑一次完整檢查。
7. 設定畫面的語言切換已經在 `LANGS` 裡循環（V1.2.1），不用改。

## 估工（不含翻譯）
每個語言約 12～20 人時：字型子集與後備 4～6、字串與資料欄位接線 2～4、換行禁則 2～4、版面全檢與修正 4～6。
