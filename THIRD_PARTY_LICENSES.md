# 第三方授權清單（優化方案 R、N0）

**規則**：來源不明的素材不得進入公開版本。新增任何素材，先在這裡登記一行（來源網址、授權、改了什麼、署名文字）。

| 素材 | 用在哪 | 來源 | 授權 | 改作 | 署名 |
|---|---|---|---|---|---|
| Godot Engine 4.6 | 引擎 | https://godotengine.org | MIT | 無 | 遊戲內製作名單＋`game/licenses/GODOT_LICENSE.txt` |
| Noto Sans TC Regular/Bold | 介面字型 | https://github.com/notofonts/noto-cjk | SIL OFL 1.1 | 子集化（`tools/build_font.py`），未改名稱以外的字形 | 製作名單；`game/fonts/OFL-NotoSansTC.txt` 隨遊戲附上 |
| Cainos「Pixel Art Top Down - Basic」草地 tileset、樹叢 | 戰場地面、兩側裝飾 | https://cainos.itch.io/pixel-art-top-down-basic | 作者條款：可商用、可修改、不得轉賣素材本身；署名非必要 | 樹叢自動裁切成單張 | 製作名單（作者表示「感謝但非必要」） |
| GodotSteam GDExtension 4.23.2 | Steam 成就、雲端、Remote Play（`game/addons/godotsteam/`，只放 win64、linux64） | https://codeberg.org/godotsteam/godotsteam | MIT | 刪掉用不到的平台與編輯器更新器、精簡 `.gdextension` | `game/licenses/GODOTSTEAM_LICENSE.md` |
| Steamworks API（`steam_api64.dll`、`libsteam_api.so`） | 隨 GodotSteam | Valve Steamworks SDK | Steamworks SDK 授權：上架 Steam 的遊戲可以附帶 | 無 | 不需要 |
| 角色、特效 | 全部單位 | 本作程式繪製（`game/scripts/ui/art.gd`） | 本作原創 | — | — |
| 音效、音樂 | 全部聲音 | 本作程式合成（`game/tools/gen_audio.py`） | 本作原創 | — | — |

## 目前**沒有**使用、等來源確認才能用的素材
| 素材 | 狀態 |
|---|---|
| 使用者桌面 `OneDrive/桌面/godot/` 的 Q 版角色（Archer／Shielder／Goblin／Skeleton／Zombie／Miner sheet） | 疑似「LPC 通用角色產生器」做的（延伸動作列沒畫盔甲，符合產生器官方說明）。產生器逐圖層授權不同（CC0／CC-BY／CC-BY-SA／OGA-BY／GPL），要拿到原始匯出的署名清單（CREDITS 或 JSON）才能用；GPL 圖層要避開。**目前遊戲完全沒有用到** |
| Swordsman_run／Miner.png 等側視大圖 | 風格不合，不用 |

## 檢查方式
- 每次 build 前：`game/` 底下所有 png／wav／otf／ttf 都要能在上表找到（`tools/check_assets.py`）。
