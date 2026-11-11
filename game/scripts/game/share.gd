extends RefCounted
## V1.6 #5 社群分享包：每日／每週的不劇透分享格（純文字，貼到聊天室）、每日連續天數。純函式（測試共用）。
## 分享格只寫成績（剩餘、花費、秒數、連續天數），不寫陣型、不寫兵種，看了也不會被劇透解法。

## 剩餘戰力 → 10 格條（■ 有剩、□ 沒剩；四捨五入到 10%）
static func bar(rem_pct: int) -> String:
	var n := clampi(roundi(rem_pct / 10.0), 0, 10)
	return "■".repeat(n) + "□".repeat(10 - n)

## 連續天數：今天打贏就接上（昨天也贏＝+1；中斷＝1；同一天重複不加）。回傳新的 {last, n, best}
static func streak_after(st: Dictionary, day: int) -> Dictionary:
	var last := int(st.get("last", -999))
	var n := int(st.get("n", 0))
	if last == day:
		return st.duplicate()
	n = n + 1 if last == day - 1 else 1
	return {"last": day, "n": n, "best": maxi(n, int(st.get("best", 0)))}

## 每日分享格。L＝字串表（傳進來方便測試）
static func daily_text(L, date: String, mut_name: String, rem: int, spent: int, budget: int, secs: int, streak: int) -> String:
	var lines: Array = [L.t("sh_daily_head", [date, mut_name]), "%s %d%%" % [bar(rem), rem], L.t("sh_stats", [spent, budget, secs])]
	if streak >= 2:
		lines.append(L.t("sh_streak", [streak]))
	lines.append(L.t("sh_tag"))
	return "\n".join(lines)

static func weekly_text(L, wk: int, won: bool, spent: int, best: int, tries: int) -> String:
	var lines: Array = [L.t("sh_weekly_head", [wk]), (L.t("sh_won") if won else L.t("sh_lost")), L.t("sh_weekly_line", [spent, best, tries]), L.t("sh_tag")]
	return "\n".join(lines)
