唯讀完成，未啟動遊戲或 Steam 測試。下列 `.gd` 為 `game/scripts/` 下唯一同名檔。S＝半日內、M＝1～3日、L＝更久。

1. 挑戰碼繞過試玩限制｜證據 game_modes.gd:100、131；game_core.gd:424｜匯入後可使用正式版卡池｜接受前驗雙方卡池與兵種｜S｜P0 發售前必修。

2. 禁牌超出畫面｜證據 game_modes.gd:207、210｜兩邊不同卡池聯集可達20種，第三排起部分超出800高畫面，手把焦點也會走到看不見處｜分頁或縮成可視網格｜S｜P0 發售前必修。

3. 奇幻筆記永遠鎖住、勝率失真｜證據 game_core.gd:257、285；game_modes.gd:267｜奇幻局先返回，不累積 unit_wins；戰績分母卻持續增加｜統一在非沙盒正式結算累積兵種勝負｜M｜P1 應修。

4. 系列設定重開即失憶｜證據 lobby_view.gd:120；save.gd:172｜性格、輪替、禁牌、時段存成陣列，讀檔只保留字串｜逐欄驗證並保留 extra｜S｜P1 應修。

5. 手把無法輸入挑戰／規則碼｜證據 game_modes.gd:94；lobby_view.gd:134｜只能讀剪貼簿；只有 replay_view.gd:257 接 Steam 鍵盤｜共用代碼輸入入口｜M｜P1 應修。

6. 中離整段重來｜證據 game_result.gd:13、21；save.gd:13｜三戰兩勝比分、遠征陣型與獎勵沒有續局資料；試煉僅結算星數保存｜最低成本先明示離開損失；遠征加戰間快照｜M｜P1 應修。

7. 重播／困難AI仍同步重算｜證據 battle_view.gd:478；hard_ai.gd:49｜按重播或第二局開戰可能數秒無回應｜沿用覆盤背景計算方式，加忙碌狀態｜M｜P1 應修。

8. 困難AI忽略性格｜證據 game_core.gd:129、139、149｜已算出的性格卡池未傳入困難AI；選項與敵軍不符｜把 p1 傳到底｜S｜P1 應修。

9. 大戰報文字疊行｜證據 game_result.gd:278；charts.gd:42、53｜總高度封頂170，超過10種時每列不足17px，新增頭像也被壓小｜固定列高並分頁｜M｜P1 應修。

10. 音效靜音後環境音仍響｜證據 sfx.gd:70、153、164｜調整音效只更新變數；同地圖不重新設定環境音音量｜音量變更同步更新 amb｜S｜P1 應修。

11. 試玩範圍與方案不一致｜證據 game_menus.gd:177、269；lobby_view.gd:187；docs/release/marketing-and-business.md:27｜遠征、後五殘局、全地圖及困難難度仍可進；只試煉入口有隱藏｜先定範圍，再集中限制入口及匯入｜M｜P1 應修。

12. 缺Linux試玩匯出｜證據 game/export_presets.cfg:38、64｜只有Linux正式版與Windows Demo｜補Linux Demo及成品檢查｜S｜P1 應修。

13. 新手手把教學仍說滑鼠｜證據 game_place.gd:614；game/data/strings.csv:551｜入門要求「左鍵拖曳」，操作說明固定顯示鍵盤鍵｜依 pad_mode 換文案；提示亦讀重綁設定，game_screens.gd:518 目前硬寫A/B｜M｜P1 應修。

14. 奇幻地形弱勢不能直接歸因AI｜證據 ai_army.gd:139；formations.gd:206、223；terrain.gd:172；fantasy_defs.gd:25｜目前只拉伸、避牆，尋路成本不計快慢地形；不動菇等機制也有地圖依賴｜最低成本先提示未認證，再只替非平原試少量陣位候選；別先改兵值｜M｜P1 應修。

15. 商店關卡數不符｜證據 docs/release/store-page.md:28；game/data/puzzles.json:247、1256、1781｜宣稱30關，資料實為10＋5＋10＝25；另有10主題試煉｜分別列明內容，更新素材清單｜S｜P1 應修。

零場標準入口未見必然卡死：presets.gd:20、roster.gd:17。字級表最低14px（ui_base.gd:109），不能判為低於 [Valve建議12px](https://partner.steamgames.com/doc/steamhardware/compat)；實際字形仍須真機看。

不建議做的事：

- 為地形勝率改平原兵值、重建認證。
- 為湊新模式覆蓋率擴增成就。
- 在真人試玩前新增模式、美術系統。
- 把既有12聲道優先權機制當成缺陷（sfx.gd:38、60）。
- 用更多截圖綠燈取代首次真人試玩。

結論：有條件
