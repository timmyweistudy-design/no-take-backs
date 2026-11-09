"""V1.5.1 E2 母語校對包。

匯出：python3 tools/gen/l10n_review.py export <輸出資料夾>
  產生 review_ja.csv、review_zh_CN.csv：key, 繁中原文, 英文, 目前譯文, 修正（空白）, 備註（空白）, 原文指紋。
  校對者只要在「修正」欄填新譯文（不改就留空），變數 %d %s 要保留。
回填：python3 tools/gen/l10n_review.py import <校對後的 csv> <l10n 譯稿資料夾>
  日文寫成 ja_zz_review.json（排在最後，蓋過機器翻譯）；簡中寫成 zhcn_review.json。
  原文指紋對不上（校對期間原文又改了）的列會跳過並列出，要重新送校。
  之後照常跑 l10n_build.py、build_font.py。
"""
import csv, hashlib, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STR = ROOT / "game/data/strings.csv"


def fp(zh, en):
    return hashlib.sha256((zh + "\n" + en).encode("utf-8")).hexdigest()[:8]


def export(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    rows = list(csv.reader(open(STR, encoding="utf-8", newline="")))
    head = rows[0]
    for lang in ("ja", "zh_CN"):
        ci = head.index(lang)
        with open(out / f"review_{lang}.csv", "w", encoding="utf-8-sig", newline="") as f:
            w = csv.writer(f)
            w.writerow(["key", "繁中原文", "English", "目前譯文", "修正", "備註", "原文指紋"])
            for r in rows[1:]:
                if not r or r[0] == "lang_name":
                    continue
                w.writerow([r[0], r[1], r[2], r[ci], "", "", fp(r[1], r[2])])
        print("寫入", out / f"review_{lang}.csv")


def var_set(s):
    # 所有格式碼都要對得上：%d %s %% 和 %.1f 這類（Codex v151-i1 #10）
    return sorted(re.findall(r"%[-+ 0#]*\d*(?:\.\d+)?[dsfx%]", s))


def do_import(csv_path, l10n_dir):
    rows = list(csv.reader(open(STR, encoding="utf-8", newline="")))
    cur = {r[0]: r for r in rows[1:] if r}
    lang = "ja" if "_ja" in Path(csv_path).name else "zh_CN"
    got, skip = {}, []
    for r in csv.DictReader(open(csv_path, encoding="utf-8-sig", newline="")):
        fix = (r.get("修正") or "").strip()
        k = r.get("key", "")
        if not fix or k not in cur:
            continue
        base = cur[k]
        if fp(base[1], base[2]) != r.get("原文指紋"):
            skip.append((k, "原文改過"))
            continue
        if var_set(fix) != var_set(base[1]):
            skip.append((k, "變數 %d／%s 數量不同"))
            continue
        got[k] = fix
    d = Path(l10n_dir)
    if lang == "ja":
        f = d / "ja_zz_review.json"
        old = json.loads(f.read_text(encoding="utf-8")) if f.exists() else {}
        old.update({"s:" + k: v for k, v in got.items()})
    else:
        f = d / "zhcn_review.json"
        old = json.loads(f.read_text(encoding="utf-8")) if f.exists() else {}
        old.update(got)
    f.write_text(json.dumps(old, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"回填 {len(got)} 筆到 {f.name}；跳過 {len(skip)} 筆")
    for k, why in skip:
        print("  跳過", k, why)


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "export":
        export(sys.argv[2])
    elif len(sys.argv) >= 4 and sys.argv[1] == "import":
        do_import(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
