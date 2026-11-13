你是《落子無悔》(Godot 4.6.2) 1.4.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 2～4 大類：規劃 coordination/v140-impl/cat02-plan.md；方案 docs/2026-11-13-v1.4.0-plan.md §7、§1、§8；差異 coordination/v140-impl/cat02-r1/diff.patch。
請檢查：①_woodtype 在棋鐘（最後 10 秒跳、音效、跳轉／暫停時 clock_last 的行為）、擺陣預算、戰績、比數的使用；簡化介面；②大廳方印 btn_seal_square 有沒有在別的按鈕殘留（例外路徑沒重設）、lobby_stamps 存檔驗型、_lobby_start 在擋下（why 不空）時不記；③設定抽屜與值格木牌對手把焦點、停用、色盲的影響；④圖鑑熱鍵木牌（R11／R12 宣告、_probe_glyph）；⑤三枚印章：_res_seals 在 DUEL、觀戰、看代碼、和局、全部陣亡時（best_t 為空）；點擊區用 _btns.append 有沒有手把焦點；toast 字串；⑥覆盤硃筆圈位置推算（chh 反推）是否和實際圖表一致；⑦擺陣牌尺與卡片、自由部署的互動。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
