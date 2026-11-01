### 1. S3 三點檢視與新分數：**8.4 / 10**

1. **圖鑑捲動與數值修正（到位，唯英文 150% 頭部裁切）**：
   - [s3_10_codex.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s3_10_codex.png)、[s3_10b_codex_scrolled.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s3_10b_codex_scrolled.png) 大頭照、名稱與台詞已固定在上方，僅下方屬性與內文捲動，不再出現黑洞；騎兵每秒傷害也已修正為 `13`。
   - 但 [s3_10b_codex_scrolled_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s3_10b_codex_scrolled_en150.png) 因英文定位換成兩行，台詞 `"Hold on — we're` 下半部被分隔線裁切。
2. **結果時間軸與跳字清理（部分到位）**：
   - [s3_05_result.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s3_05_result.png) 戰場殘留跳字已清乾淨，中文時間軸上下交錯無孤點，但出現紅 `首次背刺 3s` 與藍 `首次背刺 8s` 兩個「首次」；到了 [s3_05_result_en150.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s3_05_result_en150.png)，下排 `1st backstab 3s` 過寬，導致 `8s` 藍色節點再次變成無字孤點。
3. **弓手射程焦點與殘局縮圖（射程到位、縮圖仍難辨）**：
   - [s3_02_place.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s3_02_place.png) 當前弓手射程加亮、其餘變淡，層次清楚。
   - [s3_09_puzzles.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s3_09_puzzles.png) 縮圖點位僅 2～3px，紅框菱形被內填色吃掉，肉眼仍難分敵我。

---

### 2. S4 五兵種動作辨識度與分數：**6.8 / 10**

從 [s4_13_poses.png](file:///tmp/claude-1000/-mnt-c-Users-timmy/daf65672-2bfd-44b2-ab2a-ec34c9d55673/scratchpad/gw-s3r2/s4_13_poses.png) 檢視，受擊 `><`、狂熱紅眼與部分專屬動作清楚，但存在三個結構性問題：
- **共用刀光違和**：五兵種「揮擊」全套用同一個近戰藍色圓弧刀光，連**弓手射箭**與**騎兵刺槍**都在揮砍大圓弧。
- **姿勢高度重複**：五兵種的「前搖＝勝利」完全相同，「後搖＝交替招式」幾乎一模一樣，劍士與弓手的「專屬＝待機」也無差異。
- **個別動作細節**：
  - **弓手**：前搖拉弓搭箭清楚，但揮擊與勝利不合理。
  - **盾兵**：架盾（專屬）放大很清楚，揮擊推盾配砍擊弧線像拿盾砍人。
  - **劍士**：看得出上挑，但後搖與交替招式無差別。
  - **騎兵**：衝鋒（專屬）星光清楚，但揮擊/交替招式前蹄抬起幅度極微。
  - **刺客**：潛行（專屬）清楚，但後手刀太短且被身體遮擋，看不出交叉斬。

---

### 3. 前 3 個程式做得到的問題

1. **修正 S4 兵種揮擊特效與重複姿勢**：移除弓手與騎兵揮擊的圓弧刀光（弓手改直線箭矢殘影、騎兵改水平突刺槍芒、盾兵改前推衝擊線）；拉長刺客雙刀在身前畫出 `X` 交叉；加大騎兵前蹄仰角；並將「勝利」（如舉武歡呼）與「前搖」拆開、「交替招式」與「後搖」做出不同角度。
2. **修復英文 150% 圖鑑裁切與時間軸孤點**：圖鑑左上固定區高度改由文字實際渲染高度動態決定，避免台詞被切；時間軸在英文 150% 縮短字串（如 `Backstab 3s`）或做水平位移避讓，確保 `8s` 節點不隱藏。
3. **殘局縮圖改純陣營高對比色點**：縮圖點位放棄細兵種色與細紅框，直接畫純亮藍圓點（我方）與純亮紅大菱形（敵方），一眼分清左右陣型。

S3 有條件可，S4 不可。
