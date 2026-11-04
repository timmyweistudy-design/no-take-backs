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

# ───── 技能專屬音效（第二輪方案 R8、J）：用獨立的亂數，不改動既有音效與音樂的輸出 ─────
rnd8 = random.Random(20261108)

def n8():
    return rnd8.uniform(-1, 1)

def sfx_r8():
    # 破盾：金屬碎裂（高頻噪音爆＋幾個不和諧的金屬泛音快速衰減）
    burst = lowpass([n8() * env(i / SR, 0.001, 0.12, 0.14) for i in range(int(SR * 0.14))], 0.75)
    write("shatter", mix(burst, tone(2310, 0.18, "sine", 0.35, d=0.16), tone(3170, 0.14, "sine", 0.28, d=0.12),
                         tone(4420, 0.1, "sine", 0.2, d=0.08), tone(180, 0.08, "square", 0.3, d=0.07, bend=-0.4)))
    # 頂住：鐘鳴（基音＋非整數泛音，長尾）
    write("bell", mix(tone(660, 0.6, "sine", 0.7, d=0.58), tone(660 * 2.76, 0.45, "sine", 0.3, d=0.42),
                      tone(660 * 5.4, 0.25, "sine", 0.15, d=0.22), tone(110, 0.12, "square", 0.25, d=0.1)))
    # 衝鋒：號角三連音（G-C-E 上行，鋸齒波＋低通）
    tot = int(SR * 0.42)
    horn = mix(at(tone(392, 0.11, "saw", 0.45, a=0.01, d=0.1), 0.0, tot), at(tone(523, 0.11, "saw", 0.45, a=0.01, d=0.1), 0.12, tot),
               at(tone(659, 0.2, "saw", 0.5, a=0.01, d=0.19), 0.24, tot))
    write("bugle", lowpass(horn, 0.3))
    # 背刺：氣切（快速上滑的嘶聲）
    write("aircut", mix(lowpass([n8() * env(i / SR, 0.004, 0.1, 0.11) for i in range(int(SR * 0.11))], 0.9),
                        tone(900, 0.1, "sine", 0.25, d=0.09, bend=1.6)))
    # 警覺：輕亮的叮
    write("alert", mix(tone(1760, 0.12, "sine", 0.5, d=0.11), tone(2637, 0.08, "sine", 0.25, d=0.07)))
    # 絆馬：繩子繃斷（彈撥＋短噪音）
    write("snap", mix(tone(320, 0.14, "tri", 0.55, d=0.13, bend=-0.6), lowpass([n8() * env(i / SR, 0.001, 0.03, 0.035) for i in range(int(SR * 0.035))], 0.5)))
    # 嘲諷：低沉的「嘿！」（方波短促下滑）
    write("taunt", lowpass(tone(170, 0.16, "square", 0.5, a=0.01, d=0.15, bend=-0.25), 0.25))
    # 現形：一小團「噗」
    write("reveal", lowpass([n8() * env(i / SR, 0.005, 0.12, 0.13) for i in range(int(SR * 0.13))], 0.12))

# ───── 戰鬥音樂分軌（第三輪 S1）：低音／鼓／旋律三軌同長度、同一個增益，遊戲依戰況即時混音 ─────
def battle_stems():
    C, F, G, Am = 262, 349, 392, 220
    chords = [Am, F, C, G]
    bpm, bars = 132, 8
    beat = 60.0 / bpm
    total = int(SR * beat * 4 * bars)
    bass = [0.0] * total; drums = [0.0] * total; mel = [0.0] * total
    def add(dst, src, t0):
        o = int(t0 * SR)
        for i, v in enumerate(src):
            if o + i < total: dst[o + i] += v
    for b in range(bars):
        root = chords[b % len(chords)]
        for k in range(4):
            t0 = (b * 4 + k) * beat
            add(bass, tone(root / 2, beat * 0.9, "tri", 0.35, d=beat * 0.8), t0)
            add(drums, tone(65, 0.18, "sine", 0.9 if k % 2 == 0 else 0.0, d=0.17, bend=-0.5), t0)
            if k % 2 == 1:
                add(drums, [n8() * 0.35 * env(i / SR, 0.001, 0.08, 0.09) for i in range(int(SR * 0.09))], t0)
            add(drums, [n8() * 0.08 * env(i / SR, 0.001, 0.03, 0.04) for i in range(int(SR * 0.04))], t0 + beat * 0.5)   # 反拍小鈸
            notes = [(root * 2, 0, 0.5), (root * 2.5, 0.5, 0.45)] if k % 2 == 0 else [(root * 3, 0, 0.3)]
            for f, off, ln in notes:
                add(mel, tone(f, beat * ln, "square", 0.28, d=beat * ln * 0.9), t0 + off * beat)
    m = max(1e-9, max(abs(x + y + z) for x, y, z in zip(bass, drums, mel)))
    g = 0.6 / m
    for name, data in (("music_battle_bass", bass), ("music_battle_drums", drums), ("music_battle_mel", mel)):
        with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in data))

# ───── 第四輪新兵種音效 ─────
def sfx_v4():
    # 爆炸「碰」：低頻下滑＋噪音尾巴
    boom_noise = lowpass([noise() * env(i / SR, 0.002, 0.28, 0.3) for i in range(int(SR * 0.3))], 0.08)
    write("boom", mix(tone(90, 0.3, "sine", 1.0, d=0.28, bend=-0.6), boom_noise, tone(55, 0.22, "sine", 0.6, d=0.2)))
    # 補血「叮」：兩個高音輕輕往上
    write("heal", mix(tone(1320, 0.18, "sine", 0.45, d=0.17), at(tone(1760, 0.2, "sine", 0.4, d=0.19), 0.07, int(SR * 0.3))), peak=0.6)

def sfx_v8():
    # 第八輪奇幻軍（全部程式合成）
    write("poison", mix(tone(320, 0.16, "sine", 0.35, d=0.15, bend=-0.3), lowpass([noise() * env(i / SR, 0.01, 0.12, 0.16) * 0.3 for i in range(int(SR * 0.16))], 0.2)), peak=0.5)
    write("baa", mix(tone(420, 0.3, "saw", 0.5, d=0.28, bend=-0.15), tone(630, 0.3, "tri", 0.3, d=0.28, bend=-0.1)), peak=0.7)
    write("chomp", mix(lowpass([noise() * env(i / SR, 0.002, 0.07, 0.09) for i in range(int(SR * 0.09))], 0.5), tone(150, 0.1, "square", 0.5, d=0.09, bend=-0.4), at(tone(120, 0.1, "square", 0.4, d=0.09), 0.1, int(SR * 0.22))), peak=0.9)
    write("squish", mix(tone(240, 0.16, "sine", 0.7, d=0.15, bend=1.0), lowpass([noise() * env(i / SR, 0.005, 0.1, 0.14) * 0.3 for i in range(int(SR * 0.14))], 0.15)), peak=0.7)
    write("charge_up", tone(220, 0.5, "tri", 0.45, a=0.2, d=0.3, bend=1.4), peak=0.5)
    write("timestop", mix(tone(1568, 0.7, "sine", 0.4, d=0.7, bend=-0.6), tone(784, 0.7, "tri", 0.3, d=0.7, bend=-0.6), at(tone(392, 0.5, "sine", 0.3, d=0.5), 0.15, int(SR * 0.85))), peak=0.8)
    write("raise", mix(tone(196, 0.6, "tri", 0.5, a=0.1, d=0.45, bend=0.5), tone(294, 0.6, "sine", 0.35, a=0.1, d=0.45, bend=0.5), lowpass([noise() * env(i / SR, 0.2, 0.3, 0.6) * 0.2 for i in range(int(SR * 0.6))], 0.1)), peak=0.8)
    write("vacuum", mix(lowpass([noise() * env(i / SR, 0.05, 0.5, 0.65) * 0.7 for i in range(int(SR * 0.65))], 0.35), tone(180, 0.65, "saw", 0.3, a=0.05, d=0.55, bend=1.5)), peak=0.8)
    write("stomp", mix(tone(70, 0.32, "sine", 1.0, d=0.3, bend=-0.5), lowpass([noise() * env(i / SR, 0.002, 0.2, 0.25) for i in range(int(SR * 0.25))], 0.06)), peak=0.95)

if __name__ == "__main__":
    import sys
    if "--v8" in sys.argv:
        sfx_v8()
        print("audio v8 done")
        raise SystemExit
    if "--v4" in sys.argv:
        sfx_v4()
        print("audio v4 done")
        raise SystemExit
    if "--stems" in sys.argv:
        battle_stems()
        print("stems done")
        raise SystemExit
    if "--r8" in sys.argv:
        sfx_r8()
        print("audio r8 done")
        raise SystemExit
    sfx()
    music()
    sfx_r8()
    battle_stems()
    sfx_v4()
    print("audio:", sorted(os.listdir(OUT)))
