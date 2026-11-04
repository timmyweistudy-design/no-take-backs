extends RefCounted
## 按鍵重設（第七輪 K1、F9）。程式裡的按鍵判斷都用預設按鍵常數，這裡在入口把實際按下的鍵換回預設，
## 畫面提示也從這裡取按鍵名稱，提示和按鍵不會再對不起來。設定存在 settings["keys"]、settings["pad"]。
const ACTIONS := [
	["start", KEY_SPACE], ["place", KEY_ENTER], ["remove", KEY_BACKSPACE], ["prev", KEY_Q], ["next", KEY_E],
	["codex", KEY_F1], ["pause", KEY_P], ["flip", KEY_M],
]
const PAD_ACTIONS := [
	["start", JOY_BUTTON_START], ["place", JOY_BUTTON_A], ["remove", JOY_BUTTON_X], ["prev", JOY_BUTTON_LEFT_SHOULDER],
	["next", JOY_BUTTON_RIGHT_SHOULDER], ["codex", JOY_BUTTON_BACK], ["pause", JOY_BUTTON_Y], ["back", JOY_BUTTON_B],
]
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}

static func _default_of(list: Array, action: String) -> int:
	for a in list:
		if a[0] == action:
			return a[1]
	return -1

static func _translate(list: Array, table: Dictionary, code: int) -> int:
	for a in list:
		if int(table.get(a[0], a[1])) == code:
			return a[1]
	# 這個鍵是某個動作的預設鍵，但那個動作已經換到別的鍵：這個鍵不再有作用
	for a2 in list:
		if a2[1] == code:
			return -1
	return code

static func key_to_default(table: Dictionary, code: int) -> int:
	return _translate(ACTIONS, table, code)

static func pad_to_default(table: Dictionary, code: int) -> int:
	return _translate(PAD_ACTIONS, table, code)

static func key_of(table: Dictionary, action: String) -> int:
	return int(table.get(action, _default_of(ACTIONS, action)))

static func key_name(table: Dictionary, action: String) -> String:
	return OS.get_keycode_string(key_of(table, action))

static func pad_name(table: Dictionary, action: String) -> String:
	var c := int(table.get(action, _default_of(PAD_ACTIONS, action)))
	return PAD_NAMES.get(c, "B%d" % c)

## 不能拿來綁的鍵（Codex r1）：方向與確認導航、畫筆修飾鍵、選兵數字、固定快捷鍵。
const RESERVED := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESCAPE, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_G, KEY_Z, KEY_Y, KEY_DELETE,
	KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]

static func can_bind_key(code: int) -> bool:
	return not code in RESERVED

## 改鍵：撞到別的動作就互換（不會有兩個動作同一個鍵）。
static func rebind(list: Array, table: Dictionary, action: String, code: int) -> Dictionary:
	if list == ACTIONS and not can_bind_key(code):
		return table.duplicate()
	var out := table.duplicate()
	var old := int(out.get(action, _default_of(list, action)))
	for a in list:
		if a[0] != action and int(out.get(a[0], a[1])) == code:
			out[a[0]] = old
	out[action] = code
	return out

## 存檔讀回來的表逐項驗型（R4）：不是整數、不認得的動作都丟掉。
static func sanitize(list: Array, raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for a in list:
			var v = raw.get(a[0])
			if v is int or v is float:
				out[a[0]] = int(v)
	return out
