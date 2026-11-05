#!/usr/bin/env python3
"""音效試聽表（第十輪）：掃 game/audio/*.wav，輸出 docs/playtest/listen.html。
用法：python3 tools/gen/make_listen_sheet.py（新增或刪除音效後重跑）"""
import glob, os

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
files = sorted(os.path.basename(f) for f in glob.glob(os.path.join(root, "audio", "*.wav")))
groups = {
    "介面": [f for f in files if f.startswith(("k_", "ui_"))],
    "音樂": [f for f in files if f.startswith("music")],
    "環境": [f for f in files if f.startswith("amb")],
    "腳步": [f for f in files if f.startswith("step")],
}
used = set(sum(groups.values(), []))
groups["戰鬥與其他"] = [f for f in files if f not in used]
rows = ""
for g, fs in groups.items():
    rows += f"<h2>{g}（{len(fs)}）</h2>\n"
    for f in fs:
        n = f[:-4]
        rows += f'<div class=r><code>{n}</code><audio controls preload=none src="../../game/audio/{f}"></audio>'
        for v, t in (("ok", "好"), ("loud", "太大聲"), ("quiet", "太小聲"), ("bad", "難聽")):
            rows += f'<label><input type=radio name="{n}" value={v}>{t}</label>'
        rows += "</div>\n"
page = """<!doctype html><html lang=zh-Hant><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>音效試聽表</title>
<style>body{font:16px system-ui;max-width:860px;margin:auto;padding:16px;background:#fafafa;color:#222}.r{display:flex;flex-wrap:wrap;gap:10px;align-items:center;padding:4px 0;border-bottom:1px solid #ddd}code{width:170px}audio{height:32px}button{font-size:16px;padding:8px 14px}textarea{width:100%;height:90px}</style>
<h1>音效試聽表</h1><p>只有想改的項目要勾；音樂與環境音聽前 10 秒就好。勾完按最下面的按鈕，把文字貼給 Claude。</p>
""" + rows + """<p><button onclick="var o=[];document.querySelectorAll('input:checked').forEach(function(e){if(e.value!='ok')o.push(e.name+': '+e.value)});document.getElementById('o').value=o.join('\\n')||'全部沒問題'">產生結果</button></p><textarea id=o></textarea></html>
"""
out = os.path.join(root, "..", "docs", "playtest", "listen.html")
open(out, "w", encoding="utf-8").write(page)
print(len(files), "個音效 →", os.path.normpath(out))
