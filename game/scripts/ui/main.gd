extends "res://scripts/ui/game_screens.gd"
## 主場景腳本。出貨版只有遊戲本身；帶開發參數且專案裡有 tools/ 時，換成 tools/dev_main.gd（第七輪 H3）。

const DEV := "res://tools/dev_main.gd"
const DEV_FLAGS := ["--shot=", "--capsule=", "--video", "--perf=", "--mem-check=", "--sil="]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		for f in DEV_FLAGS:
			if a.begins_with(f) and ResourceLoader.exists(DEV):
				set_process(false)
				visible = false
				_swap_to_dev.call_deferred()
				return
	super()

func _swap_to_dev() -> void:
	var p := get_parent()
	var d: Node = load(DEV).new()
	d.name = name
	p.remove_child(self)
	p.add_child(d)
	queue_free()
