"""V1.4 #17：字型子集與涵蓋檢查共用的「要用到哪些字」。
base_text：繁中＋英文（strings.csv 的 zh_TW／en、資料檔不是 _sc／_ja 的欄位、程式字串常值、credits）。
lang_text：某一語言（zh_CN／ja）自己的字。"""
import csv, glob, json, os, re

EXTRA = "★☆✓✗✦●◆■□｜・…×％（）：，。！？「」、‘’—"
ALT = {"zh_CN": "sc", "ja": "ja"}


def _walk(o, keep, out):
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(v, str):
                if keep(k):
                    out.update(v)
            else:
                _walk(v, keep, out)
    elif isinstance(o, list):
        for x in o:
            if isinstance(x, str):
                if keep(""):   # 字串陣列算原文（繁中／英文）
                    out.update(x)
            else:
                _walk(x, keep, out)


def _alt_key(k):
    return any(k == s or k.endswith("_" + s) for s in ALT.values())


def base_text(root, extra=True):
    t = set()
    with open(os.path.join(root, "data/strings.csv"), encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            for c in ("key", "zh_TW", "en"):
                t.update(row.get(c, "") or "")
    for fn in glob.glob(os.path.join(root, "data/*.json")):
        _walk(json.load(open(fn, encoding="utf-8")), lambda k: not _alt_key(k), t)
    for fn in glob.glob(os.path.join(root, "data/*.txt")):
        t.update(open(fn, encoding="utf-8").read())
    for fn in glob.glob(os.path.join(root, "scripts/**/*.gd"), recursive=True):
        t.update("".join(re.findall(r'"(?:[^"\\\n]|\\.)*"', open(fn, encoding="utf-8").read())))
    t.update(chr(c) for c in range(0x20, 0x7F))
    if extra:
        t.update(EXTRA)
    return "".join(sorted(c for c in t if c.isprintable()))


def lang_text(root, col, extra=True):
    suf = ALT[col]
    t = set()
    with open(os.path.join(root, "data/strings.csv"), encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            t.update(row.get(col, "") or "")
    ex = os.path.join(root, "data/l10n_extra.csv")
    if os.path.exists(ex):
        with open(ex, encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                t.update(row.get(col, "") or "")
    for fn in glob.glob(os.path.join(root, "data/*.json")):
        _walk(json.load(open(fn, encoding="utf-8")), lambda k: k == suf or k.endswith("_" + suf), t)
    t.update(chr(c) for c in range(0x20, 0x7F))
    if extra:
        t.update(EXTRA + "“”")
    return "".join(sorted(c for c in t if c.isprintable()))
