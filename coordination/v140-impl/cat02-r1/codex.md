只讀靜態審查，必改 5 項（P2）：

1. [battle_view.gd:842](game/scripts/ui/battle_view.gd:842)：只要秒數不同就滴答、重設跳字時間；未區分正常倒數與跳轉，也未在開局／seek 重設 `clock_last`。暫停時跳到最後 10 秒仍會響、跳。應只對正常播放跨秒觸發。

2. [game_result.gd:833](game/scripts/ui/screens/game_result.gd:833)：最大輸出與坦傷固定只選藍方；DUEL 紅方勝出或和局時，MVP 可來自紅方，其餘獎卻仍頒藍方。應明定雙人獎項範圍，資料與 toast 加隊別，避免同兵種無法辨識。

3. [game_result.gd:249](game/scripts/ui/screens/game_result.gd:249)、[845](game/scripts/ui/screens/game_result.gd:845)：印章依附 MVP 卡，單人敗局有敗因文字時整組消失；全部陣亡或無承傷者又直接少一枚。應獨立顯示獎項區，無合資格者保留「無得主」狀態，符合三枚契約。

4. [game_result.gd:858](game/scripts/ui/screens/game_result.gd:858)：`_btns.append` 讓手把能選取、確認，但沒有繪製焦點框，也未支援加強焦點。焦點會進入看不見的停靠點；應補齊共用按鈕的焦點呈現。

5. [game_modes.gd:996](game/scripts/ui/screens/game_modes.gd:996)：改用 `_woodtype` 後移除原本 `tw - 62` 寬度限制。長連勝數值在大字級會跨出戰績卡；需保留限寬／換行能力，並計入木牌兩側外擴。

其餘核對：方印呼叫後有重設；存檔有驗型且開戰會落盤，阻擋時不記。設定值格沿用焦點／停用與文字、撥片辨識。圖鑑宣告有效，`_probe_glyph` 不豁免 R11／R12。觀戰／看代碼不頒章。覆盤 `chh` 反推與兩圖中線一致；牌尺未改動自由部署命中與輸入。

結論：有條件
