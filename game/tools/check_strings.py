#!/usr/bin/env python3
"""字串表檢查（第七輪 R1、F1）。任何一項不符 exit 1：
欄數、重複鍵、空翻譯、%s／%d 參數數（兩語言要一致）、程式裡 L.t("鍵") 用到的鍵要存在。"""
import csv, glob, os, re, sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
rows = list(csv.reader(open(os.path.join(root, "data/strings.csv"), encoding="utf-8", newline="")))
head, rows = rows[0], rows[1:]
errs, seen = [], {}
ph = re.compile(r"%[-+0-9.]*[sdf]")
for i, r in enumerate(rows, 2):
    if not r:
        continue
    if len(r) != len(head):
        errs.append(f"第 {i} 行有 {len(r)} 欄（應該 {len(head)}）：{r[0]}（英文有逗號要加引號）")
        continue
    k = r[0]
    if k in seen:
        errs.append(f"第 {i} 行重複鍵 {k}（第一次在第 {seen[k]} 行）")
    seen[k] = i
    for lang, v in zip(head[1:], r[1:]):
        if v.strip() == "":
            errs.append(f"第 {i} 行 {k} 的 {lang} 是空的")
    # 第七輪 F2：用語表（docs/terms.md）
    if re.search(r"\b[Hh]ands?\b|\b[Tt]iles?\b|Turn Draft|Last stand", r[2]):
        errs.append(f"第 {i} 行 {k} 英文用了用語表禁用的詞：{r[2][:50]}")
    if "單位" in r[1]:
        errs.append(f"第 {i} 行 {k} 中文用了「單位」：{r[1][:30]}")
    a, b = sorted(ph.findall(r[1])), sorted(ph.findall(r[2]))
    if a != b:
        errs.append(f"第 {i} 行 {k} 兩語言參數不同：{a} vs {b}")
use = re.compile(r'L\.t\("([A-Za-z0-9_]*[A-Za-z0-9])"[,)]')
for f in glob.glob(os.path.join(root, "scripts/**/*.gd"), recursive=True):
    for m in use.finditer(open(f, encoding="utf-8").read()):
        if m.group(1) not in seen:
            errs.append(f"{os.path.relpath(f, root)} 用到不存在的鍵 {m.group(1)}")
for e in errs:
    print("STRINGS", e)
print(f"STRINGS {len(seen)} 個鍵，{len(errs)} 個問題")
sys.exit(1 if errs else 0)
