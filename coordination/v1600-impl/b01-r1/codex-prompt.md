你是《落子無悔》(Godot 4.6.2) 1.6.0 實作的程式審查（第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
B01：規劃 coordination/v1600-impl/b01-plan.md；方案 docs/2026-11-15-v1.6.0-plan.md §3.1、§4 B01；差異 coordination/v1600-impl/b01-r1/diff.patch。
重點：①check.py 拆 t_stateful3：兩個行程的存檔前綴會不會互踩、測試 ID 聯集核對是否仍完整（看 check.py 357 行附近）、快取鍵；②affected_shots.py 規則是否寧可多拍（有沒有會漏拍的路徑，例如 data/*.json、scripts/game/*、新增畫面、只改 screens.json）；③sprite_cache 計時有沒有改到行為（await 順序、例外路徑、世代作廢）；④session_contract 範本能不能真的抓到「重抽、重領、壞資料、舊樣本」，塔的套用是不是只在測 sanitize 而沒測到結算只一次的實際程式（settle 是測試自己寫的閉包）。
附行號。最多 6 條必改、500 字內。最後一行「結論：可／有條件／不可」。
