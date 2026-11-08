# 第三方授權清單（優化方案 R、N0）

**規則**：來源不明的素材不得進入公開版本。新增任何素材，先在這裡登記一行（來源網址、授權、改了什麼、署名文字）。

| 素材 | 用在哪 | 來源 | 授權 | 改作 | 署名 |
|---|---|---|---|---|---|
| Godot Engine 4.6 | 引擎 | https://godotengine.org | MIT | 無 | 遊戲內製作名單＋`game/licenses/GODOT_LICENSE.txt` |
| 源泉圓體 GenSenRounded2 TW Regular/Bold（ButTaiwan，衍生自 Adobe Source Han Sans，保留名稱 Source） | 介面中文字型（V1.2） | https://github.com/ButTaiwan/gensen-font v2.100 | SIL OFL 1.1 | 子集化並改內部名稱為 NTB Rounded（`tools/gen/build_font.py`） | 製作名單；`game/licenses/GenSenRounded-OFL.txt` 隨遊戲附上 |
| 源泉圓體 GenSenRounded2 JP Regular/Bold（ButTaiwan，衍生自 Adobe Source Han Sans，保留名稱 Source） | 日文介面字型（V1.4 #17） | https://github.com/ButTaiwan/gensen-font v2.100 | SIL OFL 1.1 | 子集化並改內部名稱為 NTB Rounded JP（`tools/gen/build_font.py`） | 製作名單；`game/licenses/GenSenRounded-OFL.txt` |
| Resource Han Rounded CN Regular/Bold（Cyano Hao，衍生自 Adobe Source Han Sans，保留名稱 Source） | 簡體中文介面字型（V1.4 #17） | https://github.com/CyanoHao/Resource-Han-Rounded v0.990 | SIL OFL 1.1 | 子集化並改內部名稱為 NTB Rounded SC | 製作名單；`game/licenses/ResourceHanRounded-OFL.txt` |
| Fredoka（The Fredoka Project Authors） | 介面英數字型（V1.2） | https://github.com/google/fonts/tree/main/ofl/fredoka | SIL OFL 1.1 | 可變字型實例化 wght 500／650、子集化為拉丁字、0～9 字寬統一並置中、內部名稱改 NTB Latin | 製作名單；`game/licenses/Fredoka-OFL.txt` 隨遊戲附上 |
| UoqMunThenKhung Regular | 標題字型（≥22px 粗體標題） | https://github.com/MoonlitOwen/ThenKhung | SIL OFL 1.1 | 子集化（`tools/gen/build_font.py`），字形未修改；本專案從 timmy-project 取得原檔 | 製作名單；`game/fonts/OFL-ThenKhung.txt` 隨遊戲附上 |
| Cainos「Pixel Art Top Down - Basic」草地 tileset、樹叢 | 戰場地面、兩側裝飾 | https://cainos.itch.io/pixel-art-top-down-basic | 作者條款：可商用、可修改、不得轉賣素材本身；署名非必要 | 樹叢自動裁切成單張 | 製作名單（作者表示「感謝但非必要」） |
| GodotSteam GDExtension 4.23.2 | Steam 成就、雲端、Remote Play（`game/addons/godotsteam/`，只放 win64、linux64） | https://codeberg.org/godotsteam/godotsteam | MIT | 刪掉用不到的平台與編輯器更新器、精簡 `.gdextension` | `game/licenses/GODOTSTEAM_LICENSE.md` |
| Steamworks API（`steam_api64.dll`、`libsteam_api.so`） | 隨 GodotSteam | Valve Steamworks SDK | Steamworks SDK 授權：上架 Steam 的遊戲可以附帶 | 無 | 不需要 |
| 角色、特效 | 全部單位 | 本作程式繪製（`game/scripts/ui/art.gd`） | 本作原創 | — | — |
| 音效、音樂 | 戰鬥音效、音樂、環境音 | 本作程式合成（`game/tools/gen_audio.py`、`gen_audio_v9.py`） | 本作原創 | — | — |
| RandomMind〈Medieval: The Bard's Tale〉 | 標題配樂 `music_title.ogg` | https://opengameart.org/content/medieval-the-bards-tale （Loop_The_Bards_Tale.wav） | CC0 1.0，2026-11-07 下載、頁面存 build/dl/oga/medieval-the-bards-tale/page.html | 轉 Ogg、正規化 | 製作名單列出 |
| RandomMind〈Medieval: The Old Tower Inn〉 | 擺陣配樂 `music_place.ogg` | https://opengameart.org/content/medieval-the-old-tower-inn （Loop_The_Old_Tower_Inn.wav） | CC0 1.0，2026-11-07 | 同上 | 製作名單列出 |
| RandomMind〈Medieval: Minstrel Dance〉 | 戰鬥配樂 `music_battle.ogg`（狂熱時加快 8%） | https://opengameart.org/content/medieval-minstrel-dance （Loop_Minstrel_Dance_0.wav） | CC0 1.0，2026-11-07 | 同上 | 製作名單列出 |
| StarNinjas〈20 Sword Sound Effects (Attacks and Clashes)〉 | `slash*.ogg`、`block*.ogg` | https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes | CC0 1.0，2026-11-07 | 單聲道、去靜音、正規化、尾端淡出（`tools/gen/import_audio.py`） | 製作名單列出 |
| rubberduck〈100 CC0 metal and wood SFX〉 | `hit_metal*.ogg`、`hit_wood*.ogg`、`place_mid*.ogg`、`place_heavy__2.ogg` | https://opengameart.org/content/100-cc0-metal-and-wood-sfx | CC0 1.0，2026-11-07 | 同上 | 製作名單列出 |
| Kenney〈50 RPG sound effects〉 | `hit*.ogg`、`place_light*.ogg`、`place_heavy.ogg`、`k_tab*`、`k_open`、`k_close`、`k_place*`、`k_star*`、`k_unlock`、`step_*` | https://opengameart.org/content/50-rpg-sound-effects | CC0 1.0，2026-11-07 | 同上 | 製作名單列出 |
| Kenney Interface Sounds 1.0 | 介面音（`game/audio/k_*.wav`） | https://kenney.nl/assets/interface-sounds | CC0 1.0 | 不要求署名 | 取自 https://github.com/Calinou/kenney-interface-sounds |

## 目前**沒有**使用、等來源確認才能用的素材
| 素材 | 狀態 |
|---|---|
| 使用者桌面 `OneDrive/桌面/godot/` 的 Q 版角色（Archer／Shielder／Goblin／Skeleton／Zombie／Miner sheet） | 疑似「LPC 通用角色產生器」做的（延伸動作列沒畫盔甲，符合產生器官方說明）。產生器逐圖層授權不同（CC0／CC-BY／CC-BY-SA／OGA-BY／GPL），要拿到原始匯出的署名清單（CREDITS 或 JSON）才能用；GPL 圖層要避開。**目前遊戲完全沒有用到** |
| Swordsman_run／Miner.png 等側視大圖 | 風格不合，不用 |

## 檢查方式
- 每次 build 前：`game/` 底下所有 png／wav／otf／ttf 都要能在上表找到（`tools/check_assets.py`）。
