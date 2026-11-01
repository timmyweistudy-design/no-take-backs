# 法務清單（優化方案 R）

> 不是律師意見。標 **【你】** 的要你處理或確認。

## 1. 素材授權（目前狀態：可公開）
- 遊戲裡**每一個**圖片、聲音、字型檔都登記在 `THIRD_PARTY_LICENSES.md`，並由 `game/tools/check_assets.py` 檢查（也放進 CI）。
- 目前用到的第三方素材只有三項：Godot（MIT）、Noto Sans TC（OFL）、Cainos 地圖包（作者條款允許商用）。授權文字隨遊戲放在 `game/licenses/`，遊戲內也有製作名單畫面。
- **你桌面那批 Q 版角色目前完全沒用到。** 它們疑似 LPC 通用角色產生器做的，逐圖層授權不同，有些圖層是 GPL。要用的話，【你】先找到原始匯出的署名清單（CREDITS 或 JSON）。

## 2. 名稱與商標
| 檢查 | 結果（2026-11-01） |
|---|---|
| Steam 同名遊戲 | 沒看到「No Take-Backs」 |
| App Store／網路搜尋「落子無悔」 | 沒看到同名遊戲或 App（只有圍棋、五子棋類 App） |
| 網路搜尋「No Take Backs / No Takebacks」 | 沒看到同名遊戲；有一篇同名短篇小說、一集 podcast，都不是商品 |
| 台灣智慧局 TIPO 商標檢索 | **【你】未查**：要到「商標檢索系統」搜「落子無悔」與近似字，類別 9（軟體）、41（線上遊戲服務） |
| 美國 USPTO | **【你】未查**：搜 "NO TAKE-BACKS" / "NO TAKEBACKS"，類別 9、41 |
| 風險提醒 | 「落子無悔」是成語，識別性較弱，可能不容易註冊，但也比較不容易被別人獨占。英文名含 "Take"：Take-Two 曾對 *It Takes Two* 的 "takes two" 提異議。"Take-Backs" 字面不同，風險應該低，但要查 |

## 3. 隱私政策（草稿，可直接放商店頁「隱私政策」連結）
> 《落子無悔》不收集、不上傳任何個人資料。
> 遊戲存檔（設定、進度、陣型）只存在你的電腦；開啟 Steam 雲端時，由 Steam 同步你的存檔，適用 Steam 的隱私政策。
> 「試玩紀錄」功能預設關閉。開啟後只會把戰鬥結果與你的評分寫在本機的 `playtest_log.jsonl`，不會自動傳送；要不要寄給開發者由你決定。
> 遊戲沒有廣告、沒有分析追蹤、沒有帳號系統。

## 4. Steam 內容問卷（建議答案）
| 題目 | 答案 |
|---|---|
| 一般成人內容、性內容、裸露 | 無 |
| 暴力 | 有卡通化、非寫實的戰鬥；沒有血、沒有肢解；倒下會變成一團煙和小靈魂 |
| 恐怖、賭博、毒品 | 無 |
| 使用者產生內容 | 無（陣型代碼只是數字代碼，不含文字） |
| 遊戲內購買 | 無 |
| AI 生成內容揭露 | **要揭露**：程式碼與文件由 AI 協助撰寫；角色是程式繪製、音效是程式合成（不是生成式模型產生的圖片或聲音）。Steam 要求揭露「預先產生」與「即時產生」的 AI 內容，【你】填問卷時照實勾選並寫說明 |

## 5. 其他
- **分級**：依問卷，預期是最低分級。
- **退款政策**：Steam 標準規則（遊玩 2 小時內、14 天內）。單人內容要撐過 2 小時（見 `marketing-and-business.md` 與真人計時）。
- **字型**：只用 OFL 字型，授權文字隨遊戲附上（已做）。

## 參考資料
- Cainos 授權：https://cainos.itch.io/pixel-art-top-down-basic
- LPC 產生器授權說明：https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator
- CC BY-SA 3.0：https://creativecommons.org/licenses/by-sa/3.0/legalcode
- Steam 內容問卷：https://partner.steamgames.com/doc/gettingstarted/contentsurvey
- It Takes Two 商標爭議：https://www.pcgamer.com/take-two-takes-issue-with-it-takes-two-trademarking-takes-two-too
