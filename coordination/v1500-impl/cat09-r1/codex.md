- P1：[ui.gd:2617](game/tests/suites/ui.gd#L2617) 仍搜尋 `_draw_pf_overview()` 等無參數呼叫；實作已傳入版位參數，此測試必敗。請更新斷言並驗證切頁行為。
- P2：[game_result.gd:388](game/scripts/ui/screens/game_result.gd#L388) 返回試煉未依 `tid / TRIAL_PAGE` 更新頁碼。從第 8 關連打到第 9 關後返回，仍停第一頁；請同步目前關卡所在頁。

其餘：成就移除焦點後，所有按鈕仍可循環到達；重進保留頁籤／兵團，切頁籤重設徽章頁碼。`_h1` 下緣使用正確；DEMO_TRIALS 0、2 仍在首頁。PADWALK 未覆蓋戰績與跨頁返回。排名以兵種編號破同分，具決定性（[Godot 比較實作](https://github.com/godotengine/godot/blob/4.6/core/variant/array.cpp#L156)）。

結論：有條件
