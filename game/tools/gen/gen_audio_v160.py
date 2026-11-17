#!/usr/bin/env python3
"""1.6.0 B20（P12.3）器物聲合成佔位：翻紙（obj_paper）、蓋印（obj_stamp）。木棋沿用 V1.6 的 wood_*／place_*。
真錄音到了就用同名檔替換（audio/obj_paper.wav、audio/obj_stamp.wav），程式不用改。
用法：python3 tools/gen/gen_audio_v160.py（在 game/ 下，輸出到 audio/）。固定種子，重跑結果一樣。只用標準函式庫。"""
import math, random, struct, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio")
r = random.Random(20261117)

def write(name, xs, peak=0.7):
    m = max(1e-9, max(abs(s) for s in xs))
    g = peak / m
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in xs))

def lp(xs, k):
    y = 0.0; out = []
    for x in xs:
        y += k * (x - y); out.append(y)
    return out

def hp(xs, k):
    y = 0.0; out = []
    for x in xs:
        y += k * (x - y); out.append(x - y)
    return out

def env(n, a, d):
    return [min(1.0, i / max(1, a * SR)) * math.exp(-max(0, i - a * SR) / (d * SR)) for i in range(n)]

# 翻紙：一陣帶通的沙沙聲（兩段：拉起、落下），高頻為主、很短
n = int(0.32 * SR)
nz = [r.uniform(-1, 1) for _ in range(n)]
bp = hp(lp(nz, 0.35), 0.08)
e1 = env(n, 0.03, 0.06)
e2 = [0.0] * int(0.14 * SR) + env(n - int(0.14 * SR), 0.01, 0.05)
paper = [bp[i] * (e1[i] + 0.7 * e2[i]) * (1.0 + 0.4 * math.sin(i / SR * 2 * math.pi * 23)) for i in range(n)]
write("obj_paper", paper, 0.55)

# 蓋印：印泥章壓在紙上——低沉的短「咚」（180 Hz 衰減）＋一點紙面的摩擦
n = int(0.28 * SR)
thud = [math.sin(2 * math.pi * (180 - 60 * i / n) * i / SR) * math.exp(-i / (0.045 * SR)) for i in range(n)]
rub = lp([r.uniform(-1, 1) for _ in range(n)], 0.2)
rub = [rub[i] * math.exp(-i / (0.02 * SR)) * 0.35 for i in range(n)]
write("obj_stamp", [thud[i] + rub[i] for i in range(n)], 0.75)
print("ok")
