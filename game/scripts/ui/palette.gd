extends RefCounted
## 1.3.0 §4 色票單一來源（1.2.0 記錄的 B1）：介面材質、文字墨色、隊色與塗裝、圖表色。
## 其他檔的同名常數都指到這裡（值和 1.2.0 一模一樣；改色只改這一份）。新程式不要再寫內嵌 Color("#…")——
## `test_palette_v130` 會擋內嵌色碼數量變多（棘輪；要減少可以，要加先加到這裡）。
# ── 介面 ──
const UI_BG := Color(0.11, 0.08, 0.06, 0.95)
const PANEL := Color(0.17, 0.125, 0.09, 0.98)
const ACCENT := Color("#ffd166")
const TXT_DIM := Color("#cfc3ae")
const TH_WOOD := Color("#3a2a1f")
const TH_WOOD_L := Color("#55402d")
const TH_WOOD_D := Color("#231912")
const TH_EDGE := Color("#8d6c47")
const TH_ACTIVE := Color("#8a5a24")
const TH_PARCH := Color("#efdfbb")
const TH_INK := Color("#2c2016")
const TH_PRIMARY := Color("#e08a1e")
const INK := Color("#24150B")
const INK_SHADOW := Color("#140B06")
const DIM_INK := Color("#1c130d")
# ── 桌上小物 ──
const CUP_GLAZE := Color("#e9e1cf")
const CUP_BODY := Color("#d8cdb6")
const CUP_FOOT := Color("#b9ac92")
const TEA := Color("#6b4a22")
# ── 角色個性小物（1.3.0 §5.3）──
const TRINKET_GOLD := Color("#d9b25a")
const TRINKET_RED := Color("#c0392b")
const TRINKET_LEATHER := Color("#7a5434")
const TRINKET_BRASS := Color("#b8913f")
# 1.3.0 §7.1 狀態竹籤
const BAMBOO := Color("#d9c27a")
const BAMBOO_D := Color("#8a7434")
# 1.4.0 §7.2 木活字（每個數字一塊刻好的木塊）
const WOOD_TYPE := Color("#dcc39a")
const WOOD_TYPE_D := Color("#6b4a2a")
# 1.4.0 §3.1 牛皮紙短標籤
const KRAFT := Color("#e2cfa6")
const KRAFT_D := Color("#7a5a36")
# ── 隊色（[一般, 色盲][藍, 紅]）與塗裝底漆 ──
const TEAM := [[Color("#45acff"), Color("#d93a44")], [Color("#2f80ff"), Color("#ffb000")]]
const PAINTS := [[Color("#45acff"), Color("#3f6fd8"), Color("#2fa5a0"), Color("#7d8be6")], [Color("#d93a44"), Color("#a62f3c"), Color("#d6662d"), Color("#c4467a")]]
# ── 圖表 ──
const CHART_BLUE := Color("#4aa3ff")
const CHART_RED := Color("#ff5a5a")
const CHART_BLUE_CB := Color("#33ddff")
const CHART_RED_CB := Color("#ff9a1f")
const CHART_GRID := Color(1, 1, 1, 0.12)
const CHART_MUTED := Color("#cfc3ae")
# ── 地貌（底、慢、快、擋、擋的高光、框；判讀色是底線，材料只改質感）──
const TERRAIN := {
	"river": {"base": "#6f9a4a", "base2": "#7da655", "slow": "#7a6a44", "fast": "#a9b07a", "block": "#2f7fb5", "edge": "#7cc4e8", "frame": "#5b4632", "sound": "water", "outer": "#22351f"},
	"forest": {"base": "#4e7a3c", "base2": "#578545", "slow": "#6b5233", "fast": "#8f9a5c", "block": "#2f4d29", "edge": "#6f9a4a", "frame": "#3e2f22", "sound": "forest", "outer": "#16261a"},
	"ice": {"base": "#9cadb9", "base2": "#a6b6c0", "slow": "#bccbd5", "shadow": 0.42, "fast": "#7fb6d3", "block": "#4a7796", "edge": "#e4f0f7", "frame": "#4f6475", "sound": "wind", "outer": "#2c3d4c"},
	"lava": {"base": "#3f3640", "base2": "#4a4049", "slow": "#7e7680", "fast": "#6a5d62", "block": "#d94a14", "edge": "#7a3322", "frame": "#2c2428", "sound": "lava", "outer": "#19131a"},
	"canyon": {"base": "#d9b37a", "base2": "#e2bf88", "slow": "#c79a5e", "fast": "#a89a86", "block": "#6d3a26", "edge": "#c47a4e", "frame": "#6e4a2c", "sound": "wind", "outer": "#3f2c1e"},
}
# ── 1.6.0 B03（P1.3）主材質表：[Base, Shadow, Highlight]（docs/art-spec-v160.md §2；灰階三階：桌 ≤25｜紙 35～65｜主層 ≥75 L*）──
const MAT_WALNUT := [Color("#5b4632"), Color("#3a2b1e"), Color("#7a5e44")]
const MAT_PAPER := [Color("#e8dcc0"), Color("#cbbd9c"), Color("#f6efdf")]
const MAT_WAX := [Color("#a8231c"), Color("#7a1812"), Color("#c94a3a")]
const MAT_CHALK := [Color("#f5eedc", 0.62), Color("#cfc6b0"), Color("#f5eedc")]
const MAT_BRASS := [Color("#b8913f"), Color("#7a5a22"), Color("#d4ae55")]
# 1.6.0 B03（P1.2）主光與接觸影：左上 35° 暖白；桌上物件底緣影偏移 (3, 4)、羽化 6、DIM_INK α0.4
const LIGHT_DEG := 35.0
const CONTACT_OFF := Vector2(3, 4)
const CONTACT_FEATHER := 6.0
const CONTACT_A := 0.4
# 1.6.0 B03：攤在桌上的紙（結果紙）在桌燈下的色調——把 L* 從 1.5.0 的約 86 壓到紙的中階（量測見 tools/tone_check.py）
const PAPER_DESK_TONE := Color(0.72, 0.68, 0.62)
const PAPER_DESK_TONE_TEX := Color(0.8, 0.76, 0.7)   # 1.6.0 B06：羊皮紙貼圖（art/ui/paper.png）斑紋比卡紙深，乘 0.72 最暗處 L*≈51、墨字 4.17:1 → 淺一階（最暗處 ≥L*55，墨字 ≥4.5:1）
# 1.6.0 B03：盤外桌面壓暗（只在盤框外，盤內隊色 ΔE＝0）
const OFF_BOARD_DIM := 0.18
