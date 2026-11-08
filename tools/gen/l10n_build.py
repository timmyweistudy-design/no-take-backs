#!/usr/bin/env python3
"""V1.4 #17：把簡中、日文寫進遊戲資料。
用法：PYTHONPATH=build/pylib17 python3 tools/gen/l10n_build.py <日文譯稿資料夾（ja_*.json）>
- 簡中：OpenCC tw2sp（台灣正體→大陸簡體＋慣用詞），再套 FIX 修正遊戲用語。
- 日文：Codex 譯稿（{id: 日文}）；缺的、佔位符對不上的退回英文並列出來。
- 寫入：strings.csv 加 zh_CN、ja 兩欄；puzzles/trials/codex.json 加 *_sc、*_ja；data/l10n_extra.csv（程式裡的二元陣列）。
重跑會覆蓋舊的簡中／日文欄位。翻譯是 AI 產生、未經母語校對（設定頁有標示）。
"""
import csv, io, json, re, sys
from pathlib import Path
from opencc import OpenCC

sys.path.insert(0, str(Path(__file__).resolve().parent))
import l10n_extract as X

ROOT = Path(__file__).resolve().parents[2]
G = ROOT / "game"
cc = OpenCC("tw2sp")
FIX = [("缺省", "预设"), ("殘局", "残局"), ("土豆", "马铃薯")]
LANG_NAME = {"zh_CN": "简体中文", "ja": "日本語"}
OVERRIDE = {("ja", "title"): "落子無悔", ("ja", "lang_unproofed"): "AI翻訳・未校正", ("zh_CN", "lang_unproofed"): "AI 翻译・未校对"}
PH = re.compile(r"%[-+0-9.]*[sdf]|\{[A-Z0-9_]+\}")


def sc(s):
    t = cc.convert(s)
    for a, b in FIX:
        t = t.replace(a, b)
    return t


def load_ja(d):
    ja = {}
    for f in sorted(Path(d).glob("ja_*.json")):
        txt = f.read_text(encoding="utf-8").strip()
        txt = re.sub(r"^```(?:json)?\s*|\s*```$", "", txt)
        try:
            ja.update(json.loads(txt))
        except Exception as e:
            print("讀不到", f.name, e)
    return ja


def main():
    ja = load_ja(sys.argv[1])
    bad = []

    def jp(item):
        v = ja.get(item["id"], "")
        if not isinstance(v, str) or not v.strip():
            bad.append((item["id"], "沒翻"))
            return item["en"] or item["zh"]
        if sorted(PH.findall(v)) != sorted(PH.findall(item["zh"])):
            bad.append((item["id"], "佔位符不同"))
            return item["en"] or item["zh"]
        return v

    # strings.csv
    p = G / "data/strings.csv"
    rows = list(csv.reader(open(p, encoding="utf-8", newline="")))
    head = rows[0][:3]
    out = [head + ["zh_CN", "ja"]]
    for r in rows[1:]:
        if not r:
            continue
        k, zh, en = r[0], r[1], r[2]
        if k == "lang_name":
            out.append([k, zh, en, LANG_NAME["zh_CN"], LANG_NAME["ja"]])
            continue
        out.append([k, zh, en, OVERRIDE.get(("zh_CN", k), sc(zh)), OVERRIDE.get(("ja", k)) or jp({"id": "s:" + k, "zh": zh, "en": en})])
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(out)
    p.write_text(buf.getvalue(), encoding="utf-8")
    # 資料檔
    for fn in X.DATA:
        fp = G / "data" / fn
        d = json.load(open(fp, encoding="utf-8"))
        items = []
        X.walk(d, "", fn, items)
        for it in items:
            _, _, path, base = it["id"].split(":", 3)
            o = d
            for seg in [s for s in path.split(".") if s != ""]:
                o = o[int(seg)] if isinstance(o, list) else o[seg]
            pre = base + "_" if base else ""
            o[pre + "sc"] = sc(it["zh"])
            o[pre + "ja"] = jp(it) if it["zh"].strip() else ""
        json.dump(d, open(fp, "w", encoding="utf-8"), ensure_ascii=False, indent=2 if fn == "trials.json" else 1)
    # 程式裡的二元陣列
    ex = X.extra()
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(["zh_TW", "zh_CN", "ja"])
    for it in ex:
        w.writerow([it["zh"], sc(it["zh"]), jp(it)])
    (G / "data/l10n_extra.csv").write_text(buf.getvalue(), encoding="utf-8")
    print("簡中、日文寫入完成；日文退回英文 %d 筆" % len(bad))
    for i, why in bad[:40]:
        print("  ", why, i)


if __name__ == "__main__":
    main()
