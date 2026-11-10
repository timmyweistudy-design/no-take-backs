#!/usr/bin/env python3
"""V1.6 #14 擬音：木雕棋子的撞擊（四種材質）、倒下（木座兩下彈跳）、緊張時的低鼓循環。只用標準函式庫，全部本作合成（CC0 自製）。
用法：python3 tools/gen/gen_audio_v16.py（在 game/ 下，輸出到 audio/）。固定種子，重跑結果一樣。
"""
import math, random, struct, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio")
r = random.Random(20261110)

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

def decay(xs, tau, attack=0.001):
    return [x * min(1.0, (i / SR) / attack) * math.exp(-(i / SR) / tau) for i, x in enumerate(xs)]

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

def delay(xs, sec, g=1.0):
    return [0.0] * int(sec * SR) + [x * g for x in xs]

def tap(f, q, body, click=0.012):
    """木頭敲擊：短促的雜訊點＋兩個不和諧的木質共振（f 與 2.76f，像木琴條）。"""
    return mix(decay(hp(noise(0.03), 0.45), click), sine(f, 0.25, q), [s * 0.45 for s in sine(f * 2.76, 0.2, q * 0.5)], [s * body for s in sine(f * 0.5, 0.3, q * 1.4)])

# 四種材質：輕木、重木（實心大棋）、空心（鼓、骷髏、菇）、包鐵（武器、盔甲）
write("wood_light", tap(820, 0.035, 0.2))
write("wood_heavy", tap(360, 0.06, 0.6, 0.02))
write("wood_hollow", mix(tap(520, 0.05, 0.3), sine(260, 0.3, 0.09)))
write("wood_metal", mix(tap(700, 0.04, 0.2), [s * 0.35 for s in sine(2900, 0.25, 0.06)], [s * 0.25 for s in sine(4130, 0.2, 0.04)]))
# 倒下：木座撞地、彈一下再落定
write("wood_topple", mix(tap(300, 0.05, 0.5, 0.02), delay(tap(330, 0.04, 0.3), 0.11, 0.55), delay(tap(345, 0.03, 0.2), 0.19, 0.25)))
# 緊張低鼓：2 秒循環（每拍 0.5 秒，第 3、4 拍後有輕的反拍）
def drum(f):
    return mix(sine(f, 0.45, 0.12, -0.25), decay(lp(noise(0.12), 0.08), 0.04))
n = 2 * SR
lp_ = [0.0] * n
for beat, g in [(0.0, 1.0), (0.5, 0.75), (1.0, 0.95), (1.5, 0.7), (1.75, 0.35)]:
    d = drum(62 if g >= 0.9 else 70)
    o = int(beat * SR)
    for i, s in enumerate(d):
        lp_[(o + i) % n] += s * g
write("tension", lp_, 0.7)
print("ok")
