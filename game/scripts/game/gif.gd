extends RefCounted
## V1.4 #14：極簡 GIF89a 編碼器（零依賴）。固定 252 色調色盤（紅 6 × 綠 7 × 藍 6），每格不抖色，LZW 壓縮，無限循環。
## 用在「錄 3 秒 GIF」：320×200、10 fps、約 30 格，背景執行緒編碼，不卡畫面。

const RL := 6
const GL := 7
const BL := 6

static func _index(c: Color) -> int:
	var r := clampi(int(round(c.r * (RL - 1))), 0, RL - 1)
	var g := clampi(int(round(c.g * (GL - 1))), 0, GL - 1)
	var b := clampi(int(round(c.b * (BL - 1))), 0, BL - 1)
	return (r * GL + g) * BL + b

static func _palette() -> PackedByteArray:
	var p := PackedByteArray()
	for r in RL:
		for g in GL:
			for b in BL:
				p.append(int(round(255.0 * r / (RL - 1))))
				p.append(int(round(255.0 * g / (GL - 1))))
				p.append(int(round(255.0 * b / (BL - 1))))
	while p.size() < 256 * 3:
		p.append(0)
	return p

static func _u16(out: PackedByteArray, v: int) -> void:
	out.append(v & 0xff)
	out.append((v >> 8) & 0xff)

## frames：同尺寸的 Image 陣列；delay_cs：每格停留（百分之一秒）。回傳整個 GIF 檔的位元組。
## ctl（1.1.0 H1）：{"stop": true} 時每一格之間停下、回空陣列（呼叫端就不寫檔）。
static func encode(frames: Array, delay_cs := 10, ctl := {}) -> PackedByteArray:
	var out := PackedByteArray()
	if frames.is_empty():
		return out
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	out.append_array("GIF89a".to_ascii_buffer())
	_u16(out, w)
	_u16(out, h)
	out.append(0xF7)   # 全域色表、8 位元色深、256 色
	out.append(0)
	out.append(0)
	out.append_array(_palette())
	# 無限循環
	out.append_array(PackedByteArray([0x21, 0xFF, 0x0B]))
	out.append_array("NETSCAPE2.0".to_ascii_buffer())
	out.append_array(PackedByteArray([3, 1, 0, 0, 0]))
	var fi := 0
	for img in frames:
		if bool(ctl.get("stop", false)):
			return PackedByteArray()
		if ctl.has("done"):
			ctl["done"] = fi   # 1.1.0 A14：已編好的格數（主執行緒讀來畫進度；鍵事先建好，只改值）
		fi += 1
		var im: Image = img
		if im.get_format() != Image.FORMAT_RGBA8:
			im = im.duplicate()
			im.convert(Image.FORMAT_RGBA8)
		out.append_array(PackedByteArray([0x21, 0xF9, 4, 0]))
		_u16(out, delay_cs)
		out.append_array(PackedByteArray([0, 0]))
		out.append(0x2C)
		_u16(out, 0)
		_u16(out, 0)
		_u16(out, w)
		_u16(out, h)
		out.append(0)
		var idx := PackedByteArray()
		idx.resize(w * h)
		var data := im.get_data()
		for i in w * h:
			idx[i] = _index(Color8(data[i * 4], data[i * 4 + 1], data[i * 4 + 2]))
		out.append(8)
		out.append_array(_blocks(_lzw(idx, 8)))
	out.append(0x3B)
	return out

## LZW（GIF 版：可變碼長、清除碼、碼表滿 4096 就重來）。
static func _lzw(idx: PackedByteArray, min_size: int) -> PackedByteArray:
	var clear := 1 << min_size
	var eoi := clear + 1
	var acc := 0
	var nacc := 0
	var size := min_size + 1
	var dict := {}
	var next := eoi + 1
	var res := PackedByteArray()
	# 內聯寫碼（lambda 無法改外層整數，所以直接展開）
	acc |= clear << nacc
	nacc += size
	while nacc >= 8:
		res.append(acc & 0xff)
		acc >>= 8
		nacc -= 8
	var prefix := -1
	for i in idx.size():
		var k := int(idx[i])
		if prefix < 0:
			prefix = k
			continue
		var key := prefix * 256 + k
		if dict.has(key):
			prefix = int(dict[key])
			continue
		acc |= prefix << nacc
		nacc += size
		while nacc >= 8:
			res.append(acc & 0xff)
			acc >>= 8
			nacc -= 8
		if next < 4096:
			dict[key] = next
			next += 1
			if next > (1 << size) and size < 12:   # 解碼端加表比編碼端慢一步，所以超過才加位元
				size += 1
		else:
			acc |= clear << nacc
			nacc += size
			while nacc >= 8:
				res.append(acc & 0xff)
				acc >>= 8
				nacc -= 8
			dict.clear()
			next = eoi + 1
			size = min_size + 1
		prefix = k
	if prefix >= 0:
		acc |= prefix << nacc
		nacc += size
		while nacc >= 8:
			res.append(acc & 0xff)
			acc >>= 8
			nacc -= 8
	acc |= eoi << nacc
	nacc += size
	while nacc > 0:
		res.append(acc & 0xff)
		acc >>= 8
		nacc -= 8
	return res

static func _blocks(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	while i < data.size():
		var n := mini(255, data.size() - i)
		out.append(n)
		out.append_array(data.slice(i, i + n))
		i += n
	out.append(0)
	return out
