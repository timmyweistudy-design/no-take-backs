#!/usr/bin/env python3
"""程式合成音效與音樂（優化方案 H）。只用標準函式庫，輸出 22050Hz 16-bit 單聲道 WAV 到 game/audio/。
全部是自己合成的聲音，沒有任何外部素材，授權乾淨（本專案原創）。
用法：python3 tools/gen_audio.py
"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rnd = random.Random(20261101)

def write(name, samples, peak=0.85):
    m = max(1e-9, max(abs(s) for s in samples))
    g = peak / m
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples))

def env(t, a, d, total):
    if t < a:
        return t / a
    return max(0.0, 1.0 - (t - a) / max(1e-6, d)) if t < total else 0.0

def noise():
    return rnd.uniform(-1, 1)

def lowpass(xs, k):
    y = 0.0; out = []
    for x in xs:
        y += k * (x - y); out.append(y)
    return out

def tone(freq, dur, wave_="sine", vol=1.0, a=0.005, d=None, bend=0.0):
    n = int(SR * dur); d = d or dur; out = []; ph = 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1 + bend * t / dur)
        ph += 2 * math.pi * f / SR
        if wave_ == "sine": v = math.sin(ph)
        elif wave_ == "square": v = 1.0 if math.sin(ph) >= 0 else -1.0
        elif wave_ == "tri": v = 2 / math.pi * math.asin(math.sin(ph))
        else: v = ((ph / math.pi) % 2) - 1
        out.append(v * vol * env(t, a, d, dur))
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]

def at(track, offset, total):
    out = [0.0] * total
    o = int(offset * SR)
    for i, v in enumerate(track):
        if o + i < total: out[o + i] += v
    return out

# ───── 音效 ─────
def sfx():
    # 落子：木頭棋子敲棋盤（短促的共振＋點擊）；三種重量
    for name, f in [("place_light", 900), ("place_mid", 620), ("place_heavy", 420)]:
        click = [noise() * env(i / SR, 0.0005, 0.01, 0.012) for i in range(int(SR * 0.012))]
        body = mix(tone(f, 0.12, "sine", 0.9, d=0.11), tone(f * 2.76, 0.06, "sine", 0.3, d=0.05))
        write(name, mix(click, body))
    # 揮砍：高頻噪音掃過
    xs = [noise() * env(i / SR, 0.01, 0.12, 0.14) for i in range(int(SR * 0.14))]
    write("slash", lowpass(xs, 0.35))
    # 命中：低沉悶響
    write("hit", mix(tone(140, 0.09, "sine", 1, d=0.08, bend=-0.5), lowpass([noise() * env(i / SR, 0.001, 0.04, 0.05) for i in range(int(SR * 0.05))], 0.2)))
    # 弓箭：放弦＋破風
    string = tone(220, 0.06, "tri", 0.5, d=0.05, bend=-0.3)
    whoosh = lowpass([noise() * env(i / SR, 0.03, 0.15, 0.2) for i in range(int(SR * 0.2))], 0.15)
    write("arrow", mix(string, whoosh))
    # 盾擋：金屬鏗鏘
    write("block", mix(tone(1250, 0.25, "sine", 0.6, d=0.24), tone(1870, 0.2, "sine", 0.4, d=0.18), tone(2650, 0.12, "sine", 0.25, d=0.1),
                       [noise() * env(i / SR, 0.0005, 0.02, 0.02) for i in range(int(SR * 0.02))]))
    # 衝鋒：馬蹄連擊＋撞擊
    total = int(SR * 0.45)
    hooves = [0.0] * total
    for k, off in enumerate([0.0, 0.07, 0.16, 0.23]):
        hooves = [a + b for a, b in zip(hooves, at(tone(180 - k * 10, 0.05, "sine", 0.6, d=0.04), off, total))]
    impact = at(mix(tone(90, 0.15, "sine", 1, d=0.14, bend=-0.4), lowpass([noise() * env(i / SR, 0.001, 0.08, 0.1) for i in range(int(SR * 0.1))], 0.3)), 0.32, total)
    write("charge", [a + b for a, b in zip(hooves, impact)])
    # 背刺：尖銳的刃聲＋紫色閃（上滑音）
    write("backstab", mix(tone(1600, 0.12, "saw", 0.4, d=0.1, bend=0.8), lowpass([noise() * env(i / SR, 0.002, 0.06, 0.07) for i in range(int(SR * 0.07))], 0.6)))
    # 頂住／拒馬：厚重木盾撞擊
    write("brace", mix(tone(110, 0.2, "square", 0.5, d=0.18), tone(330, 0.1, "sine", 0.4, d=0.09)))
    # 死亡：「噗」＋小靈魂上升音
    poof = lowpass([noise() * env(i / SR, 0.005, 0.12, 0.14) for i in range(int(SR * 0.14))], 0.08)
    soul = at(tone(660, 0.25, "sine", 0.35, a=0.02, d=0.23, bend=0.7), 0.06, int(SR * 0.32))
    write("death", mix(poof, soul))
    # 狂熱：大鼓兩下
    total = int(SR * 0.6)
    drum = [0.0] * total
    for off in (0.0, 0.25):
        drum = [a + b for a, b in zip(drum, at(tone(70, 0.3, "sine", 1, d=0.28, bend=-0.6), off, total))]
    write("frenzy", drum)
    # 最後時刻：心跳
    total = int(SR * 0.7)
    hb = [0.0] * total
    for off, f in ((0.0, 60), (0.18, 55)):
        hb = [a + b for a, b in zip(hb, at(tone(f, 0.16, "sine", 1, d=0.15), off, total))]
    write("clutch", hb)
    # 開戰號角
    write("start", mix(tone(392, 0.25, "saw", 0.4, a=0.02, d=0.25), at(tone(523, 0.45, "saw", 0.45, a=0.02, d=0.42), 0.22, int(SR * 0.7))))
    # 勝利／失敗
    notes = [523, 659, 784, 1046]
    total = int(SR * 1.2)
    win = [0.0] * total
    for k, f in enumerate(notes):
        win = [a + b for a, b in zip(win, at(tone(f, 0.5, "tri", 0.6, d=0.48), k * 0.12, total))]
    write("win", win)
    total = int(SR * 1.2)
    lose = [0.0] * total
    for k, f in enumerate([392, 349, 311, 262]):
        lose = [a + b for a, b in zip(lose, at(tone(f, 0.45, "tri", 0.6, d=0.43), k * 0.16, total))]
    write("lose", lose)
    # 介面
    write("ui_click", tone(1200, 0.04, "sine", 0.6, d=0.035))
    write("ui_deny", mix(tone(200, 0.12, "square", 0.4, d=0.11), tone(190, 0.12, "square", 0.3, d=0.11)))
    write("turn", mix(tone(784, 0.1, "tri", 0.5, d=0.09), at(tone(1046, 0.12, "tri", 0.5, d=0.11), 0.08, int(SR * 0.22))))

# ───── 音樂（簡單循環）─────
def bar_loop(name, bpm, bars, chords, melody_fn, drum=True, lead="tri", tempo_scale=1.0):
    beat = 60.0 / (bpm * tempo_scale)
    total = int(SR * beat * 4 * bars)
    out = [0.0] * total
    for b in range(bars):
        root = chords[b % len(chords)]
        for k in range(4):
            t0 = (b * 4 + k) * beat
            # 撥弦（擺放）／低音
            out = [a + c for a, c in zip(out, at(tone(root / 2, beat * 0.9, "tri", 0.35, d=beat * 0.8), t0, total))]
            if drum:
                kick = tone(65, 0.18, "sine", 0.9 if k % 2 == 0 else 0.0, d=0.17, bend=-0.5)
                snare = [noise() * 0.35 * env(i / SR, 0.001, 0.08, 0.09) for i in range(int(SR * 0.09))] if k % 2 == 1 else []
                out = [a + c for a, c in zip(out, at(kick, t0, total))]
                if snare:
                    out = [a + c for a, c in zip(out, at(snare, t0, total))]
            for f, off, ln in melody_fn(b, k, root):
                out = [a + c for a, c in zip(out, at(tone(f, beat * ln, lead, 0.28, d=beat * ln * 0.9), t0 + off * beat, total))]
    write(name, out, peak=0.6)

def music():
    C, F, G, Am = 262, 349, 392, 220
    def pizz(b, k, root):
        scale = [1, 1.25, 1.5, 2]
        return [(root * scale[(b + k) % 4], 0, 0.45), (root * scale[(b + k + 2) % 4], 0.5, 0.4)]
    bar_loop("music_place", 96, 8, [C, Am, F, G], pizz, drum=False, lead="sine")
    def battle(b, k, root):
        if k % 2 == 0:
            return [(root * 2, 0, 0.5), (root * 2.5, 0.5, 0.45)]
        return [(root * 3, 0, 0.3)]
    bar_loop("music_battle", 132, 8, [Am, F, C, G], battle, drum=True, lead="square")
    def frenzy(b, k, root):
        return [(root * 2, 0, 0.25), (root * 3, 0.25, 0.25), (root * 2.5, 0.5, 0.25), (root * 4, 0.75, 0.2)]
    bar_loop("music_frenzy", 132, 4, [Am, G, F, G], frenzy, drum=True, lead="square", tempo_scale=1.15)
    def title(b, k, root):
        return [(root * [2, 2.5, 3, 2.5][k], 0, 0.9)]
    bar_loop("music_title", 84, 8, [C, G, Am, F], title, drum=False, lead="tri")

if __name__ == "__main__":
    sfx()
    music()
    print("audio:", sorted(os.listdir(OUT)))
