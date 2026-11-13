#!/usr/bin/env python3
"""1.3.0 §10 棋館環境三層（程序合成，固定種子；真錄音到位後換檔即可，檔名不變）：
  amb_room_near.wav：茶蓋碰碗（偶發清脆高頻＋短殘響）、線香微劈啪（極輕的點擊）
  amb_room_mid.wav ：老闆撥算盤（一串 3～6 顆的木珠輕敲，間隔不定）
  amb_room_far.wav ：窗外微雨（帶通粉紅雜訊、慢慢起伏）＋偶發更夫木梆（兩聲低木頭）
每個 24 秒、單聲道 22050Hz、頭尾 50ms 交叉淡化可無縫循環；響度壓在 −30～−24 dBFS RMS（環境組）。
用法（專案根目錄）：PYTHONPATH=build/pylibnp python3 tools/gen/room_ambience.py <輸出資料夾>"""
import sys, os, wave, struct
import numpy as np

SR = 22050
DUR = 24.0
N = int(SR * DUR)

def env_hit(n, decay):
    t = np.arange(n) / SR
    return np.exp(-t / decay)

def tone(freq, n, decay, rng, partials=((1.0, 1.0), (2.76, 0.4), (5.4, 0.15))):
    t = np.arange(n) / SR
    s = np.zeros(n)
    for mul, amp in partials:
        s += amp * np.sin(2 * np.pi * freq * mul * t + rng.uniform(0, 6.28))
    return s * env_hit(n, decay)

def place(buf, at, snd, gain):
    i = int(at * SR)
    j = min(len(buf), i + len(snd))
    if i < len(buf):
        buf[i:j] += snd[: j - i] * gain

def pink(n, rng):
    w = rng.standard_normal(n)
    f = np.fft.rfft(w)
    k = np.arange(len(f)); k[0] = 1
    f /= np.sqrt(k)
    return np.fft.irfft(f, n)

def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f[(fr < lo) | (fr > hi)] = 0
    return np.fft.irfft(f, len(x))

def loop_fade(x):
    m = int(0.05 * SR)
    head = x[:m].copy()
    x[-m:] = x[-m:] * np.linspace(1, 0, m) + head * np.linspace(0, 1, m)
    return x[:-m] if False else x

def norm_rms(x, db):
    r = np.sqrt(np.mean(x ** 2)) + 1e-12
    for _ in range(4):   # 軟限幅（tanh）會讓 RMS 掉一點：反覆校正到目標（Codex cat09 #5：原本整段縮小、實測低 3～8 dB）
        y = 0.6 * np.tanh(x * (10 ** (db / 20) / r) / 0.6)
        got = np.sqrt(np.mean(y ** 2)) + 1e-12
        r *= got / (10 ** (db / 20))
    return y

def near(rng):
    b = np.zeros(N)
    t = rng.uniform(1.0, 3.0)
    while t < DUR - 1:
        f = rng.uniform(2300, 3100)
        place(b, t, tone(f, int(0.5 * SR), 0.09, rng), 0.5)          # 茶蓋碰碗
        if rng.random() < 0.5:
            place(b, t + rng.uniform(0.08, 0.14), tone(f * 1.04, int(0.4 * SR), 0.06, rng), 0.3)
        t += rng.uniform(5.0, 9.0)
    t = 0.3
    while t < DUR - 0.2:
        click = rng.standard_normal(int(0.004 * SR)) * env_hit(int(0.004 * SR), 0.001)
        place(b, t, bandpass(np.pad(click, (0, 400)), 1500, 6000), 0.25)   # 線香微劈啪
        t += rng.exponential(1.4)
    return norm_rms(b, -30)

def mid(rng):
    b = np.zeros(N)
    t = rng.uniform(1.5, 4.0)
    while t < DUR - 2:
        k = rng.integers(3, 7)
        for i in range(k):
            f = rng.uniform(900, 1300)
            place(b, t + i * rng.uniform(0.07, 0.13), tone(f, int(0.12 * SR), 0.018, rng, ((1, 1), (3.1, 0.3))), 0.6)   # 木珠
        t += rng.uniform(3.5, 7.0)
    return norm_rms(b, -28)

def far(rng):
    rain = bandpass(pink(N, rng), 600, 5000)
    sw = 0.75 + 0.25 * np.sin(2 * np.pi * np.arange(N) / N * 3 + 1.0)
    b = rain * sw * 0.6
    for at in (6.0, 18.5):
        for d in (0.0, 0.42):
            place(b, at + d, tone(330, int(0.35 * SR), 0.05, rng, ((1, 1), (2.3, 0.5), (4.1, 0.2))), 2.2)   # 更夫木梆
    return norm_rms(b, -27)

def write(path, x):
    x = loop_fade(x)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, fn, seed in (("near", near, 1301), ("mid", mid, 1302), ("far", far, 1303)):
        write(os.path.join(out, "amb_room_%s.wav" % name), fn(np.random.default_rng(seed)))
        print("ok", name)
