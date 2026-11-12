只讀靜態審查；未執行測試。必改 7 條：

1. [ruleset.gd:395](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd:395)、[battle_sim.gd:2098](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:2098)：摘要漏擴充規則，狀態雜湊漏 beat、arrows、ext_cd、saved_at、ext_fires；不同規則／未來行為可能同指紋。僅擴充啟用時追加雜湊，保留舊位元組。

2. [battle_sim.gd:1063](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:1063)：醫者排序、1083 目標平手只比目前座標；擊退夾邊造成重疊時仍取決於索引。最後追加鏡像不變的 slot／出生識別。

3. [battle_sim.gd:925](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:925)：stun、ext_cd 在急救前遞減；stun＝1 的醫者本 tick 不能行動卻能急救，違反⑤救援、⑦冷卻順序。擴充路徑須調整階段並固定邊界測試。

4. [battle_sim.gd:691](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:691)：投彈／敲擊提早 continue，略過799的接拍；加成既不套用也不消耗。集中處理所有攻擊宣告的加成與消耗。

5. [battle_sim.gd:1044](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/battle_sim.gd:1044)：火傷只加 dmg_in，未納入 per_pair／last_hit；純火燒死不記擊殺，混傷可能歸錯人。將火傷加入共同歸屬計算。

6. [ruleset.gd:276](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/core/ruleset.gd:276)：validate 未驗擴充範圍及 adj／synergy 互斥；匯入協同後切開相鄰陣法，仍通過驗證，卻輸出自己讀不回的碼。統一驗證入口。

7. [share_codes.gd:205](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/share_codes.gd:205)：接拍觸發可被既有 DRUM 事件滿足；火矢只驗箭數。補驗實際增傷、t+20／40 扣血、致命急救、多醫者、雙鼓手及救後同 tick 再受傷。

預設分支、舊碼讀取與規則 copy／對戰碼傳遞未見新增遺失。seek 從頭重算（replay_view.gd:112），漏雜湊不直接破壞跳轉；仍欠舊金標準實跑證明位元組不變。

結論：不可