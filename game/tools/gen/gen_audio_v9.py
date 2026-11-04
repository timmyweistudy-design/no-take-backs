#!/usr/bin/env python3
"""V9 音效：腳步、材質打擊、地圖環境音。只用標準函式庫，全部本作合成。
用法：python3 tools/gen/gen_audio_v9.py（輸出到 audio/）；介面音另外用 Kenney CC0（audio/k_*.wav）。
"""
import math, random, struct, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio")
r = random.Random(20261105)

def write(name, xs, peak=0.85):
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

def noise(sec):
    return [r.uniform(-1, 1) for _ in range(int(sec * SR))]

def decay(xs, tau, attack=0.002):
    out = []
    for i, x in enumerate(xs):
        t = i / SR
        out.append(x * min(1.0, t / attack) * math.exp(-t / tau))
    return out

def sine(f, sec, tau, bend=0.0):
    out = []; ph = 0.0
    for i in range(int(sec * SR)):
        t = i / SR
        ph += 2 * math.pi * f * (1 + bend * t) / SR
        out.append(math.sin(ph) * math.exp(-t / tau))
    return out

def mix(*ts):
    n = max(len(t) for t in ts)
    return [sum(t[i] for t in ts if i < len(t)) for i in range(n)]

def loop(xs, fade=0.5):
    """頭尾交疊，循環不會有接縫。"""
    n = int(fade * SR)
    out = xs[:-n]
    for i in range(n):
        k = i / n
        out[i] = out[i] * k + xs[len(xs) - n + i] * (1 - k)
    return out

# 腳步：依地面材質
write("step_grass", decay(lp(noise(0.09), 0.35), 0.022))
write("step_snow", decay(hp(lp(noise(0.14), 0.7), 0.15), 0.045))
write("step_wood", mix(decay(lp(noise(0.05), 0.5), 0.012), sine(210, 0.09, 0.025)))
write("step_stone", mix(decay(hp(noise(0.05), 0.3), 0.01), sine(420, 0.05, 0.012)))
write("step_heavy", mix(sine(70, 0.28, 0.09, -0.3), decay(lp(noise(0.2), 0.12), 0.06)))
# 材質打擊
write("hit_metal", mix(sine(1320, 0.18, 0.05), sine(2140, 0.14, 0.03), decay(hp(noise(0.04), 0.4), 0.008)))
write("hit_wood", mix(sine(320, 0.1, 0.03, -0.4), decay(lp(noise(0.05), 0.4), 0.012)))
write("hit_soft", mix(sine(150, 0.12, 0.04, -0.5), decay(lp(noise(0.08), 0.2), 0.03)))
# 開戰號角
def horn():
    out = []; ph = 0.0
    for i in range(int(0.9 * SR)):
        t = i / SR
        f = 196 * (1 + 0.5 * min(1.0, t / 0.08))
        ph += 2 * math.pi * f / SR
        a = min(1.0, t / 0.05) * min(1.0, (0.9 - t) / 0.25)
        out.append(a * (math.sin(ph) + 0.5 * math.sin(2 * ph) + 0.3 * math.sin(3 * ph)))
    return out
write("horn", horn(), 0.7)
# 地圖環境音（6 秒循環，音量由程式壓低）
write("amb_water", loop(lp(noise(6.5), 0.08)), 0.5)
def wind():
    xs = lp(noise(6.5), 0.03); out = []
    for i, x in enumerate(xs):
        out.append(x * (0.6 + 0.4 * math.sin(2 * math.pi * i / SR / 6.0)))
    return loop(out)
write("amb_wind", wind(), 0.5)
def forest():
    xs = lp(noise(6.5), 0.05)
    for start in (0.8, 2.6, 4.3):
        s = int(start * SR)
        for i, b in enumerate(sine(2600, 0.14, 0.04, 0.8)):
            xs[s + i] += b * 0.06
    return loop(xs)
write("amb_forest", forest(), 0.5)
def lava():
    xs = lp(noise(6.5), 0.015)
    for _ in range(14):
        s = r.randint(0, int(5.5 * SR))
        for i, b in enumerate(decay(lp(noise(0.1), 0.3), 0.02)):
            xs[s + i] += b * 0.12
    return loop(xs)
write("amb_lava", lava(), 0.5)
