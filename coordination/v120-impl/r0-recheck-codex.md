只讀複查完成，未改檔。已妥：§9.5／§14.7已對齊憲法；§19逐列重算為304～465、334～510、含新兵358～555人日，順序也已引用§0.7。其餘必改四條：

1. **§9.6仍有問題：機制確實存在，但須精確描述。** [battle_sim.gd:1533](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:1533)的`cast`將指令入列；下一次`step`先加tick，再由`_cmd_tick`取出，成功施放才於1581行記錄；1543行起按紀錄tick重播。因此固定延遲應明寫「1個模擬tick」。[test_cmd_delay_v151:1228](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/ui.gd:1228)只測展示緩衝，並未驗證此流程。[view_buffer.gd:132](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/view_buffer.gd:132)僅補滿快照；[battle_view.gd:75](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle_view.gd:75)停頓會停止推進。須把獨立模擬時鐘列為新增工程，並修§17「以展示tick施放」舊文。

2. **§8.3部分已妥。** 冷卻與本tick致命傷急救已補；火傷「下一tick起每20tick」仍可解作`t+1、t+21`或`t+20、t+40`。須列唯一傷害tick，明定到期tick先傷害或先移除，確保兩次。

3. **§11.5／11.6仍有問題。** 分數跟玩家、合作用玩家ID已妥；現行公式卻非血量加總／開局戰力：[battle_sim.gd:316](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:316)按兵價加權剩血，[puzzles.gd:349](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/puzzles.gd:349)按預算換百分比並四捨五入。須照此改文，或明列新公式；合作另補撤銷是否返還手數／預算，以及餘款買不起任何兵時的結束規則。

4. **§14.10／14.11仍有問題。** 平移對齊不足以處理紙卡翻折，須用材質座標或形變對齊，排除遮擋與新露區域；對比須定明度公式及邊界取樣寬度。觸地≤1px須在扣除鏡頭運動的棋盤座標量測，指定解析度與觸地區間，否則鏡頭移動也會判溜冰。

結論：有條件