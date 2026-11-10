#!/usr/bin/env python3
"""V1.2 E：把 CC0 錄音素材轉成遊戲用的 Ogg Vorbis（取代程式合成的音樂與部分音效）。
來源都在 OpenGameArt、逐頁確認是 CC0（原始頁面存在 build/dl/oga/<頁面>/page.html），授權登記在 THIRD_PARTY_LICENSES.md。
處理：轉單聲道（音效）／保留立體聲（音樂）、去頭尾靜音、峰值正規化、尾端 15ms 淡出；同名多個變體存成 名稱、名稱__2、名稱__3…
（sfx.gd 會隨機挑變體、避免連續抽到同一個）。
用法（需要 soundfile、numpy；用專案的 venv）：build/venv-audio/bin/python tools/gen/import_audio.py
"""
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "build", "dl", "oga")
OUT = os.path.join(ROOT, "game", "audio")

SW = "20-sword-sound-effects-attacks-and-clashes/x"
MW = "100-cc0-metal-and-wood-sfx/x"
RPG = "50-rpg-sound-effects/x/OGG"

# 遊戲裡的音效名稱 → 來源檔（多個＝變體）
SFX = {
    "slash": [f"{SW}/sword - StarNinjas/sword.{i}.ogg" for i in (1, 2, 3, 4, 5)],
    "block": [f"{SW}/sword_clash.{i}.ogg" for i in (1, 2, 3, 4)],
    "hit": [f"{RPG}/chop.ogg", f"{RPG}/knifeSlice.ogg", f"{RPG}/knifeSlice2.ogg"],
    "hit_metal": [f"{MW}/metal_hit_0{i}.ogg" for i in (1, 2, 3, 4)],
    "hit_wood": [f"{MW}/wood_hit_0{i}.ogg" for i in (1, 2, 3, 4)],
    "place_light": [f"{RPG}/bookPlace{i}.ogg" for i in (1, 2, 3)],
    "place_mid": [f"{MW}/wood_hit_0{i}.ogg" for i in (1, 3)],
    "place_heavy": [f"{RPG}/dropLeather.ogg", f"{MW}/wood_close_01.ogg"],
    "k_tab": [f"{RPG}/bookFlip{i}.ogg" for i in (1, 2, 3)],
    "k_open": [f"{RPG}/bookOpen.ogg"],
    "k_close": [f"{RPG}/bookClose.ogg"],
    "k_place": [f"{RPG}/bookPlace{i}.ogg" for i in (2, 3)],
    "k_star": [f"{RPG}/handleCoins.ogg", f"{RPG}/handleCoins2.ogg"],
    "k_unlock": [f"{RPG}/metalLatch.ogg"],
    "step_grass": [f"{RPG}/footstep0{i}.ogg" for i in (0, 1, 2, 3)],
    "step_stone": [f"{RPG}/footstep0{i}.ogg" for i in (4, 5, 6)],
    "step_wood": [f"{RPG}/footstep0{i}.ogg" for i in (7, 8, 9)],
}
# 音樂：（名稱, 來源, 長度上限秒）
MUSIC = [
    ("music_title", "medieval-the-bards-tale/Loop_The_Bards_Tale.wav"),
    ("music_place", "medieval-the-old-tower-inn/Loop_The_Old_Tower_Inn.wav"),
    ("music_battle", "medieval-minstrel-dance/Loop_Minstrel_Dance_0.wav"),
    ("music_codex", "medieval-exploration/Exploration.wav"),          # V1.0.0 A1：圖鑑、大廳、收藏
    ("music_puzzle", "medieval-kings-feast/Loop_Kings_Feast.wav"),    # V1.0.0 A1：殘局、教學擺陣
]


def trim(x, sr, thr=0.01):
    a = np.abs(x if x.ndim == 1 else x.max(axis=1))
    idx = np.nonzero(a > thr)[0]
    if idx.size == 0:
        return x
    s = max(0, idx[0] - int(sr * 0.003))
    e = min(len(x), idx[-1] + int(sr * 0.03))
    return x[s:e]


def finish(x, sr, peak):
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (peak / m)
    n = min(len(x), int(sr * 0.015))
    if n > 0:
        fade = np.linspace(1.0, 0.0, n)
        x[-n:] = (x[-n:].T * fade).T
    return x


def write(name, data, sr):
    p = os.path.join(OUT, name + ".ogg")
    sf.write(p, data, sr, format="OGG", subtype="VORBIS")
    return os.path.getsize(p)


def main():
    total = 0
    only_music = "--music" in sys.argv
    for name, srcs in ({} if only_music else SFX).items():
        for k, rel in enumerate(srcs):
            x, sr = sf.read(os.path.join(SRC, rel), always_2d=False, dtype="float32")
            if x.ndim == 2:
                x = x.mean(axis=1)
            x = finish(trim(x, sr), sr, 0.8)
            total += write(name if k == 0 else f"{name}__{k + 1}", x, sr)
        print("音效", name, len(srcs), "個變體")
    for name, rel in MUSIC:
        x, sr = sf.read(os.path.join(SRC, rel), always_2d=True, dtype="float32")
        x = x * (0.85 / max(1e-6, np.max(np.abs(x))))
        p = os.path.join(OUT, name + ".ogg")
        # 一次寫整首會讓 libsndfile 的 Vorbis 編碼崩潰（大檔），分塊寫
        with sf.SoundFile(p, "w", samplerate=sr, channels=x.shape[1], format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(x), 32768):
                f.write(np.ascontiguousarray(x[i:i + 32768]))
        total += os.path.getsize(p)
        print("音樂", name, round(len(x) / sr, 1), "秒", os.path.getsize(p) // 1024, "KB")
    print("合計", total // 1024, "KB")


if __name__ == "__main__":
    sys.exit(main())
