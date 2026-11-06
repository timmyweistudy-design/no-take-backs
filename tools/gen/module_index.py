#!/usr/bin/env python3
"""V1.1 E8：產生 docs/MODULES.md（每個腳本一行：行數＋檔頭第一句 ## 說明）。
AI 協作時先讀這份找檔案，再 grep 行號範圍，不整檔讀。用法：python3 tools/gen/module_index.py [--check]"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
OUT = ROOT / "docs/MODULES.md"


def summary(p: Path) -> str:
    for line in p.read_text(encoding="utf-8", errors="ignore").splitlines()[:12]:
        s = line.strip()
        if s.startswith("##"):
            return s.lstrip("#").strip()[:90]
    return ""


def build() -> str:
    out = ["# 模組索引（自動產生，勿手改：`python3 tools/gen/module_index.py`）", "",
           "找程式先看這裡，再用 grep 加行號範圍讀；大檔不要整檔讀。", ""]
    for d in ["scripts/core", "scripts/game", "scripts/ui", "scripts/ui/battle", "scripts/ui/screens", "scripts/ui/units", "tests", "tests/suites", "tools", "tools/balance"]:
        files = sorted((GAME / d).glob("*.gd"))
        if not files:
            continue
        out += [f"## game/{d}", "", "| 檔案 | 行數 | 說明 |", "|---|---|---|"]
        for f in files:
            n = len(f.read_text(encoding="utf-8", errors="ignore").splitlines())
            out.append(f"| `{f.name}` | {n} | {summary(f).replace('|', '／')} |")
        out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    txt = build()
    if "--check" in sys.argv:
        ok = OUT.is_file() and OUT.read_text(encoding="utf-8") == txt
        print("MODULES OK" if ok else "MODULES 過期：重跑 tools/gen/module_index.py")
        sys.exit(0 if ok else 1)
    OUT.write_text(txt, encoding="utf-8", newline="\n")
    print(f"寫入 {OUT}（{txt.count(chr(10))} 行）")
