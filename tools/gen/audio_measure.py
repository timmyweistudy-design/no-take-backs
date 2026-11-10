#!/usr/bin/env python3
"""V1.6.1 N4：音效自動量測（沒有真人盲聽前的替代檢查）。
每個 game/audio/*.wav|ogg 量：峰值 dBFS、RMS dBFS（有聲段，> −50 dBFS 的 20ms 窗）、頻譜重心 Hz、長度。
同一組（介面、戰鬥、木頭擬音…）裡 RMS 比中位數高 6 dB 以上或低 10 dB 以上、峰值 > −0.3 dBFS（削波）列為「要聽」。
輸出 docs/playtest/loudness.md 與 build/tmp/audio_measure.json（給試聽表標註）。
用法（專案根目錄）：build/venv-audio/bin/python tools/gen/audio_measure.py"""
import glob, json, os, statistics
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUD = os.path.join(ROOT, "game", "audio")

def group(n):
    if n.startswith(("k_", "ui_")): return "介面"
    if n.startswith("music"): return "音樂"
    if n.startswith("amb"): return "環境"
    if n.startswith("step"): return "腳步"
    if n.startswith(("wood_", "tension")): return "V1.6 木頭擬音"
    return "戰鬥與其他"

def measure(path):
    x, sr = sf.read(path, always_2d=True)
    m = x.mean(axis=1)
    peak = float(np.max(np.abs(m))) if m.size else 0.0
    win = max(1, int(sr * 0.02))
    n = len(m) // win
    rms_db = -120.0
    if n > 0:
        w = m[: n * win].reshape(n, win)
        r = np.sqrt((w ** 2).mean(axis=1))
        act = r[r > 10 ** (-50 / 20)]
        if act.size:
            rms_db = float(20 * np.log10(np.sqrt((act ** 2).mean())))
    spec = np.abs(np.fft.rfft(m[: min(len(m), sr * 4)]))
    fr = np.fft.rfftfreq(min(len(m), sr * 4), 1 / sr)
    cen = float((spec * fr).sum() / spec.sum()) if spec.sum() > 0 else 0.0
    return {"peak_db": round(20 * np.log10(peak), 1) if peak > 0 else -120.0, "rms_db": round(rms_db, 1), "centroid": round(cen), "sec": round(len(m) / sr, 2)}

files = sorted(glob.glob(os.path.join(AUD, "*.wav")) + glob.glob(os.path.join(AUD, "*.ogg")))
res = {}
for f in files:
    b = os.path.basename(f)
    res[b] = measure(f)
    res[b]["group"] = group(b)
flags = {}
for g in set(v["group"] for v in res.values()):
    rs = [v["rms_db"] for v in res.values() if v["group"] == g and v["rms_db"] > -100]
    med = statistics.median(rs) if rs else -20
    for b, v in res.items():
        if v["group"] != g:
            continue
        why = []
        if v["peak_db"] > -0.3: why.append("削波")
        if v["rms_db"] > med + 6: why.append(f"比組內中位數大聲 {v['rms_db'] - med:.0f} dB")
        if v["rms_db"] < med - 10: why.append(f"比組內中位數小聲 {med - v['rms_db']:.0f} dB")
        v["median"] = round(med, 1)
        if why: flags[b] = "、".join(why)
os.makedirs(os.path.join(ROOT, "build", "tmp"), exist_ok=True)
json.dump({"files": res, "flags": flags}, open(os.path.join(ROOT, "build", "tmp", "audio_measure.json"), "w"), ensure_ascii=False, indent=1)
lines = ["# 音效自動量測（V1.6.1 N4）", "", "`tools/gen/audio_measure.py` 產生。這不是盲聽：只抓「同組裡明顯太大或太小聲、削波」。標「要聽」的請優先在 `listen.html` 試聽。", "",
         f"共 {len(res)} 個檔，要聽 {len(flags)} 個。", "", "| 檔案 | 組 | 峰值 dBFS | RMS dBFS | 組中位數 | 頻譜重心 Hz | 秒 | 要聽 |", "|---|---|---|---|---|---|---|---|"]
for b, v in sorted(res.items(), key=lambda kv: (kv[1]["group"], kv[0])):
    lines.append(f"| {b} | {v['group']} | {v['peak_db']} | {v['rms_db']} | {v['median']} | {v['centroid']} | {v['sec']} | {flags.get(b, '')} |")
open(os.path.join(ROOT, "docs", "playtest", "loudness.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("AUDIO", len(res), "files;", len(flags), "flagged")
for b, w in flags.items():
    print(" ", b, w)
