你是《落子無悔》(Godot 4.6.2) 1.3.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 8 大類：規劃 coordination/v130-impl/cat08-plan.md；方案 docs/2026-11-13-v1.3.0-plan.md §8、§0.4（竹簾）、§0.5；差異 coordination/v130-impl/cat08-r1/diff.patch。
內容：ui_base.gd 的 OBJ_OF 新器物（notebook、book、annot、specimen、toolbox、shelf、post）與 _obj_deco 畫法、OBJ_ANIM 開合動畫借用；game_result.gd 三折摺痕；game_place.gd 竹簾 _bamboo_blind 取代木屏風；測試 test_vessels_v130。
請檢查：①器物裝飾畫在面板外緣，會不會超出 1280×800 畫面、壓到標題緞帶、按鈕、捲動條或其他面板（大廳 Rect2(50,30,1180,740) 下緣絲帶、設定提環、獎盃架層板）；②簡化介面是否完全不畫；③竹簾：遮擋範圍是否和舊屏風完全一致（不洩漏陣型）、白字對比、自由部署與格子模式、迷霧模式；④三折摺痕對結果頁文字對比與 R11；⑤開合動畫 kind 對應、`panel_obj` 在 lobby／review 是否真的被設；⑥色票 ratchet、效能（每幀畫的多邊形數）；⑦方案 §8 還缺什麼（列出即可，裁決已延後幾何重排）。
附行號。最多 8 條必改，800 字內。最後一行「結論：可／有條件／不可」。
