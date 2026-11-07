#!/usr/bin/env python3
"""V1.2.1 E2：量每個短音效的響度（50ms 視窗最大 RMS），把離中位數太遠的拉回來，寫 game/data/audio_trim.json（檔名 → dB）。
不硬套同一響度：只把偏離中位數超過 ±4 dB 的修到 ±4 dB，同名變體再對齊本體 ±2 dB。音樂、環境音不動。
用法：build/venv-audio/bin/python tools/gen/audio_trim.py"""
import glob, json, os
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUD = os.path.join(ROOT, "game", "audio")
OUT = os.path.join(ROOT, "game", "data", "audio_trim.json")
BAND, VAR_BAND = 4.0, 2.0

def loud(path):
    d, sr = sf.read(path, always_2d=True)
    x = d.mean(axis=1)
    w = max(1, int(sr * 0.05))
    if len(x) < w:
        w = len(x)   # 比 50ms 還短的音：整段當一個視窗
    n = max(1, len(x) // w)
    return 20 * np.log10(max(1e-9, max(np.sqrt((x[i * w:(i + 1) * w] ** 2).mean()) for i in range(n))))

files = sorted(f for f in glob.glob(os.path.join(AUD, "*.ogg")) + glob.glob(os.path.join(AUD, "*.wav"))
               if not os.path.basename(f).startswith(("music", "amb_")))
lv = {os.path.basename(f): loud(f) for f in files}
pk = {os.path.basename(f): 20 * np.log10(max(1e-9, np.abs(sf.read(f, always_2d=True)[0]).max())) for f in files}
QUIET_BY_DESIGN = ("k_hover",)   # 本來就刻意很輕的音（滑過），不往上拉
med = float(np.median(list(lv.values())))
trim = {}
for name, v in lv.items():
    dev = v - med
    t = 0.0
    if dev > BAND:
        t = -(dev - BAND)
    elif dev < -BAND:
        t = -(dev + BAND)
    trim[name] = t
# 變體對齊本體（名稱__2 → 名稱）
for name in lv:
    base = name.split("__")[0]
    if "__" in name:
        bn = next((b for b in lv if os.path.splitext(b)[0] == base), None)
        if bn:
            a = lv[bn] + trim[bn]
            b = lv[name] + trim[name]
            if b - a > VAR_BAND:
                trim[name] -= (b - a - VAR_BAND)
            elif a - b > VAR_BAND:
                trim[name] += (a - b - VAR_BAND)
for k in trim:
    if k.startswith(QUIET_BY_DESIGN):
        trim[k] = min(0.0, trim[k])
    trim[k] = min(trim[k], -1.0 - pk[k])   # 拉大聲不能破音：峰值 ≤ -1 dBFS
out = {k: round(v, 1) for k, v in sorted(trim.items()) if abs(v) >= 0.5}
json.dump({"_說明": "V1.2.1 E2 tools/gen/audio_trim.py 產生；檔名→播放時加減的 dB（中位數 %.1f dBFS）" % med, "trim": out}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("寫入", OUT, len(out), "項；中位數", round(med, 1))
for k, v in sorted(out.items(), key=lambda kv: kv[1]):
    print(" ", k, v)
