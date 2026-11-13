#!/usr/bin/env python3
"""1.4.0 §9.4 嘟囔語占位（程序合成、固定種子）：老闆與常客的無意義語音，按情緒 3 種 × 每種 3 個變體。
真錄音到位後用同檔名換掉即可（voice_<情緒>_<n>.wav）。情緒：happy（上揚、快）、sad（下沉、慢）、hmm（平、短）。
做法：聲門脈衝（鋸齒＋抖動）經三個共振峰帶通（隨機母音 a／o／u／e），音高曲線依情緒，3～5 個音節。
用法（專案根目錄）：PYTHONPATH=build/pylibnp python3 tools/gen/mumble_voice.py <輸出資料夾>"""
import sys, os, wave, struct
import numpy as np
SR = 22050
VOWELS = {"a": (730, 1090, 2440), "o": (570, 840, 2410), "u": (300, 870, 2240), "e": (530, 1840, 2480)}

def resonator(x, f, bw):
    r = np.exp(-np.pi * bw / SR)
    a1, a2 = -2 * r * np.cos(2 * np.pi * f / SR), r * r
    y = np.zeros_like(x)
    for n in range(len(x)):
        y[n] = x[n] - a1 * (y[n - 1] if n > 0 else 0) - a2 * (y[n - 2] if n > 1 else 0)
    return y

def syllable(f0a, f0b, dur, vowel, rng):
    n = int(SR * dur)
    f0 = np.linspace(f0a, f0b, n) * (1 + 0.01 * rng.standard_normal(n).cumsum() / np.sqrt(n))
    ph = np.cumsum(f0 / SR)
    src = 2 * (ph % 1.0) - 1.0
    src += 0.05 * rng.standard_normal(n)
    out = np.zeros(n)
    for f, bw in zip(VOWELS[vowel], (80, 100, 140)):
        out += resonator(src, f, bw)
    env = np.minimum(1, np.minimum(np.arange(n) / (0.02 * SR), (n - np.arange(n)) / (0.04 * SR)))
    return out * env

def mumble(mood, seed):
    rng = np.random.default_rng(seed)
    k = rng.integers(3, 6)
    base = {"happy": 210, "sad": 150, "hmm": 170}[mood]
    parts = []
    for i in range(k):
        dur = {"happy": 0.11, "sad": 0.19, "hmm": 0.13}[mood] * rng.uniform(0.8, 1.2)
        prog = i / max(1, k - 1)
        if mood == "happy":
            a, b = base * (1 + 0.25 * prog), base * (1 + 0.32 * prog)
        elif mood == "sad":
            a, b = base * (1 - 0.18 * prog), base * (1 - 0.25 * prog)
        else:
            a, b = base, base * 0.97
        parts.append(syllable(a, b, dur, rng.choice(list(VOWELS)), rng))
        parts.append(np.zeros(int(SR * rng.uniform(0.02, 0.05))))
    y = np.concatenate(parts)
    y /= (np.sqrt(np.mean(y ** 2)) + 1e-9)
    y *= 10 ** (-20 / 20)
    y = 0.7 * np.tanh(y / 0.7)
    return y

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for mood in ("happy", "sad", "hmm"):
        for i in range(3):
            y = mumble(mood, 4200 + i * 7 + len(mood))
            with wave.open(os.path.join(out, "voice_%s_%d.wav" % (mood, i + 1)), "wb") as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
                w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in y))
            print("ok", mood, i + 1)
