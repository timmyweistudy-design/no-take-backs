extends "res://tests/test_base.gd"

## 第七輪 R2：測試框架自己的契約。
func test_harness_v7() -> void:
	ok(runner.exit_code(1, 0) == 0, "R2：有通過、沒失敗 → exit 0")
	ok(runner.exit_code(0, 0) == 1, "R2：0 項 → exit 1（不能假綠）")
	ok(runner.exit_code(5, 1) == 1, "R2：有失敗 → exit 1")
	ok(runner.SUITES.has("ui") and runner.SUITES.has("free") and runner.SUITES.has("rules") and runner.SUITES.has("new"), "R2：舊的四個測試組都還在")
	for k in runner.SUITES:
		for fn in runner.SUITES[k]:
			ok(runner.has_test(fn), "R2：測試組 %s 的 %s 存在" % [k, fn])
	for fn in runner.ALL_TESTS:
		ok(runner.has_test(fn), "R2：完整清單的 %s 存在" % fn)
