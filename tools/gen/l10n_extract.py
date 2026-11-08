#!/usr/bin/env python3
"""V1.4 #17：把要翻成日文的所有文字抽成批次（給 Codex 翻；簡中用 OpenCC 轉，不用翻）。
用法：python3 tools/gen/l10n_extract.py <輸出資料夾> [每批筆數]
輸出 batch_NN.json：[{"id": ..., "zh": 中文, "en": 英文}]。id 規則：
  s:<key>　　　　　strings.csv
  d:<檔名>:<json 路徑>:<欄位基底>　資料檔（例 d:puzzles.json:extra.3:hint）
  x:<中文>　　　　　程式裡的二元陣列（成就名、成就條件、AI 陣型名）
"""
import csv, json, os, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
G = ROOT / "game"
DATA = ["puzzles.json", "trials.json", "codex.json"]


def strings():
    out = []
    with open(G / "data/strings.csv", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            out.append({"id": "s:" + row["key"], "zh": row["zh_TW"], "en": row["en"]})
    return out


def walk(o, path, fname, out):
    if isinstance(o, dict):
        for k, v in o.items():
            m = re.fullmatch(r"(?:(.+)_)?zh", k)
            if m and isinstance(v, str):
                base = m.group(1) or ""
                en = o.get((base + "_" if base else "") + "en", "")
                out.append({"id": "d:%s:%s:%s" % (fname, path, base), "zh": v, "en": en if isinstance(en, str) else ""})
            elif isinstance(v, (dict, list)):
                walk(v, path + "." + k if path else k, fname, out)
    elif isinstance(o, list):
        for i, x in enumerate(o):
            walk(x, path + "." + str(i) if path else str(i), fname, out)


def data():
    out = []
    for fn in DATA:
        walk(json.load(open(G / "data" / fn, encoding="utf-8")), "", fn, out)
    return out


def extra():
    """程式裡的 ["中文", "English"] 二元陣列與 AI 陣型名。"""
    out, seen = [], set()
    pair = re.compile(r'\[\s*"([^"]*[一-鿿][^"]*)"\s*,\s*"([^"]*)"\s*\]')
    for fn in ["scripts/game/steam.gd", "scripts/ui/screens/game_modes.gd"]:
        txt = open(G / fn, encoding="utf-8").read()
        for zh, en in pair.findall(txt):
            if zh not in seen:
                seen.add(zh)
                out.append({"id": "x:" + zh, "zh": zh, "en": en})
    txt = open(G / "scripts/ui/screens/game_core.gd", encoding="utf-8").read()
    m = re.search(r"const AI_TPL_EN := \{(.*?)\}", txt, re.S)
    for zh, en in re.findall(r'"([^"]+)":\s*"([^"]+)"', m.group(1)):
        if zh not in seen:
            seen.add(zh)
            out.append({"id": "x:" + zh, "zh": zh, "en": en})
    return out


def all_items():
    return strings() + data() + extra()


if __name__ == "__main__":
    od = Path(sys.argv[1])
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 260
    od.mkdir(parents=True, exist_ok=True)
    items = [i for i in all_items() if i["zh"].strip()]
    for b in range(0, len(items), n):
        json.dump(items[b:b + n], open(od / ("batch_%02d.json" % (b // n)), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(len(items), "筆，", (len(items) + n - 1) // n, "批")
