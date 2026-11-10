#!/usr/bin/env python3
"""音效試聽表（第十輪）：掃 game/audio/*.wav，輸出 docs/playtest/listen.html。
用法：python3 tools/gen/make_listen_sheet.py（新增或刪除音效後重跑）"""
import glob, json, os

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
files = sorted(os.path.basename(f) for f in glob.glob(os.path.join(root, "audio", "*.wav")) + glob.glob(os.path.join(root, "audio", "*.ogg")))   # V1.2：含 CC0 錄音 ogg
groups = {
    "介面": [f for f in files if f.startswith(("k_", "ui_"))],
    "音樂": [f for f in files if f.startswith("music")],
    "環境": [f for f in files if f.startswith("amb")],
    "腳步": [f for f in files if f.startswith("step")],
    "V1.6 木頭擬音": [f for f in files if f.startswith(("wood_", "tension"))],   # V1.6.1 N4
}
# V1.6.1 N4：有自動量測結果（tools/gen/audio_measure.py）就標上 RMS 與「要聽」
mj = os.path.join(root, "..", "build", "tmp", "audio_measure.json")
meas = json.load(open(mj, encoding="utf-8")) if os.path.exists(mj) else {"files": {}, "flags": {}}
used = set(sum(groups.values(), []))
groups["戰鬥與其他"] = [f for f in files if f not in used]
rows = ""
for g, fs in groups.items():
    rows += f"<h2>{g}（{len(fs)}）</h2>\n"
    for f in fs:
        n = f[:-4]
        m = meas["files"].get(f)
        tag = f'<small>{m["rms_db"]} dB</small>' if m else ""
        if f in meas["flags"]:
            tag += f'<b title="{meas["flags"][f]}">★要聽</b>'
        # 1.1.0 E5：盲聽時用量測響度把音量拉到同一水準（不讓大小聲洩漏是哪一個）；沒量測的不調
        gain = min(1.0, 10 ** ((-24.0 - float(m["rms_db"])) / 20.0)) if m else 1.0
        rows += f'<div class=r data-g="{gain:.3f}"><code>{n}</code><audio controls preload=none src="../../game/audio/{f}"></audio><span class=tag>{tag}</span>'
        for v, t in (("ok", "好"), ("loud", "太大聲"), ("quiet", "太小聲"), ("bad", "難聽")):
            rows += f'<label><input type=radio name="{n}" value={v}>{t}</label>'
        rows += "</div>\n"
page = """<!doctype html><html lang=zh-Hant><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>音效試聽表</title>
<style>body{font:16px system-ui;max-width:860px;margin:auto;padding:16px;background:#fafafa;color:#222}.r{display:flex;flex-wrap:wrap;gap:10px;align-items:center;padding:4px 0;border-bottom:1px solid #ddd}code{width:170px}audio{height:32px}button{font-size:16px;padding:8px 14px}textarea{width:100%;height:90px}</style>
<h1>音效試聽表</h1><p>只有想改的項目要勾；音樂與環境音聽前 10 秒就好。勾完按最下面的按鈕，把文字貼給 Claude。標「★要聽」的是自動量測覺得同組裡太大或太小聲的（滑鼠移上去看原因，全表在 loudness.md）。</p>
<p><label>盲聽種子 <input id=seed size=8></label> <button onclick="blind()">盲聽模式（隱藏名稱、打亂順序、音量拉齊）</button></p>
<script>
function rnd(s){return function(){s=(s*1103515245+12345)%2147483648;return s/2147483648}}
function blind(){var sd=parseInt(document.getElementById('seed').value)||Date.now()%100000;document.getElementById('seed').value=sd;
var r=rnd(sd),rows=Array.prototype.slice.call(document.querySelectorAll('.r')),box=document.getElementById('bb');
document.querySelectorAll('h2,.tag').forEach(function(e){e.style.display='none'});
for(var i=rows.length-1;i>0;i--){var j=Math.floor(r()*(i+1));var t=rows[i];rows[i]=rows[j];rows[j]=t}
rows.forEach(function(e,i){e.querySelector('code').textContent='#'+(i+1);var a=e.querySelector('audio');a.volume=parseFloat(e.dataset.g||'1');box.appendChild(e)});
document.getElementById('bl').textContent='盲聽中（種子 '+sd+'）：結果仍會用真正的檔名輸出';}
</script><p id=bl></p>
""" + rows + """<div id=bb></div><p><button onclick="var o=[];document.querySelectorAll('input:checked').forEach(function(e){if(e.value!='ok')o.push(e.name+': '+e.value)});var sd=document.getElementById('seed').value;document.getElementById('o').value=(sd?'盲聽種子 '+sd+'\\n':'')+(o.join('\\n')||'全部沒問題')">產生結果</button></p><textarea id=o></textarea></html>
"""
out = os.path.join(root, "..", "docs", "playtest", "listen.html")
open(out, "w", encoding="utf-8").write(page)
print(len(files), "個音效 →", os.path.normpath(out))
