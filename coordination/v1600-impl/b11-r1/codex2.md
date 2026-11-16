- P1 [battle_units:1132](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/scripts/ui/battle/battle_units.gd:1132)：只排除 paused，未排除全場 hitstop；turn_crouch 仍用持續增加的 time，未受擊的兵在頓幀中仍壓彈。1140 的方向過渡也會在暫停／頓幀中到期跳格，應改用會凍結的展示時鐘。
- P2 [battle_units:1159](/mnt/c/Users/timmy/projects/no-take-backs/build/cg/b11/game/scripts/ui/battle/battle_units.gd:1159)：南北轉回側面的過渡期間，主體用過渡 face、walk=0，配件與 xray 卻仍用原 face、walk；密陣會疊出不同姿勢的輪廓。應共用本幀實際繪製姿勢，或過渡期間停用補畫。

結論：不可
