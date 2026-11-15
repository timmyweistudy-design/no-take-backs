extends RefCounted
## 1.6.0 B03（P1.1）桌位表：桌上每樣東西放哪裡的單一來源（1280×800 基準；docs/art-spec-v160.md §3）。
## 只放幾何，不畫圖；擺陣、戰鬥、結果、標題都從這裡拿位置，測試直接驗數字。

const SCREEN := Vector2(1280, 800)
const BOARD := Rect2(128, 100, 1024, 576)        # 盤面（＝ui_base ORIGIN、FIELD）
const BOARD_FRAME := 16.0                        # 盤框外露寬
const BOARD_MAX_W := 1040.0                      # 規格上限（含框）；目前 1056，縮盤留給 B06 並列審片決定
const EDGE_MIN := 120.0                          # 規格：左右桌緣各 ≥120
const SLOT_GAP := 16.0                           # 右緣槽距盤框 ≥16
const SLOT_W := 104.0                            # 右緣槽寬（規格）
const SLOT_W_MIN := 88.0                         # 桌緣不夠寬時收窄到這裡；再不夠就依 HIDE_ORDER 隱藏裝飾
const SLOT_TOP := 108.0
const SLOT_BOTTOM := 692.0                      # ＝盤框下緣：右緣三槽只在盤框的高度內（不和擺陣卡列、戰鬥底列重疊；Hydrogen B03 r1 #5）
const SLOTS := ["owner", "cup", "clock"]         # 上：老闆肖像鈕（敵情翻牌）｜中：茶杯或木籌｜下：棋鐘或沙漏、放大鏡
const HIDE_ORDER := ["coaster", "chips", "clock_deco"]   # 窄到放不下時依序隱藏
const OWNER_H := 112.0                           # 上槽（肖像鈕）高
const RESULT_PAPER := Rect2(200, 100, 880, 610)  # 結果紙
const RESULT_NOTE_MAX := Vector2(260, 120)       # 局內便條：紙外左下桌緣
const FIRST_NOTE_MAX_FRAC := 0.35                # 首開便條：標題左區 ≤35% 屏寬

static func frame_rect(board := BOARD) -> Rect2:
	return board.grow(BOARD_FRAME)

## 右緣桌面可用寬（盤框右緣到螢幕邊，扣槽距）
static func right_room(board := BOARD) -> float:
	return SCREEN.x - frame_rect(board).end.x - SLOT_GAP

## 右緣三槽 {名稱: Rect2}；放不下（< SLOT_W_MIN）回空字典（呼叫端照 HIDE_ORDER 退）
static func right_slots(board := BOARD) -> Dictionary:
	var w := minf(SLOT_W, right_room(board) - 4.0)   # 右邊留 4px 不貼螢幕
	if w < SLOT_W_MIN:
		return {}
	var x := frame_rect(board).end.x + SLOT_GAP
	var mid_h := 150.0
	var top := Rect2(x, SLOT_TOP, w, OWNER_H)
	var bot_h := 96.0
	var bot := Rect2(x, SLOT_BOTTOM - bot_h, w, bot_h)
	var mid := Rect2(x, (top.end.y + bot.position.y - mid_h) * 0.5, w, mid_h)
	return {"owner": top, "cup": mid, "clock": bot}

## 規格符合度（ledger／測試用）：盤寬、左右桌緣、槽寬
static func spec_report(board := BOARD) -> Dictionary:
	var fr := frame_rect(board)
	return {"board_w": fr.size.x, "board_ok": fr.size.x <= BOARD_MAX_W, "edge_l": fr.position.x, "edge_r": SCREEN.x - fr.end.x,
		"edge_ok": fr.position.x >= EDGE_MIN and SCREEN.x - fr.end.x >= EDGE_MIN, "slot_w": minf(SLOT_W, right_room(board) - 4.0)}

## 局內便條釘位：結果紙外左下桌緣（寬不超過紙左邊的桌面）
static func result_note_rect(paper := RESULT_PAPER) -> Rect2:
	var w := minf(RESULT_NOTE_MAX.x, paper.position.x - 2.0 * SLOT_GAP)
	return Rect2(SLOT_GAP, paper.end.y - RESULT_NOTE_MAX.y, w, RESULT_NOTE_MAX.y)

## 首開便條：標題左區
static func first_note_max_w() -> float:
	return SCREEN.x * FIRST_NOTE_MAX_FRAC
