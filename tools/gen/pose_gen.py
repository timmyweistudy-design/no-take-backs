#!/usr/bin/env python3
"""1.2.0 §7.1 姿勢資料化：把 game/scripts/ui/art.gd 的 POSE_PROFILE（每兵 9 個值的三段式公式）轉成 data/poses/<id>_<name>.json。
關鍵幀和 Art._pose_prof 完全同形：0 → 前搖到底（smooth）→ 命中（ease_out）→ 停頓（step）→ 收回（smooth）。
用法（專案根目錄）：python3 tools/gen/pose_gen.py   會一併重寫 game/scripts/ui/pose_files.gd（兵種 → 檔名）。"""
import json, os, re

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "game")
NAMES = ["sword", "shield", "archer", "cavalry", "assassin", "pike", "bomber", "medic", "drummer", "berserker",
         "spore", "sheep", "mimic", "slime", "ghost", "voodoo", "hourglass", "skelmage", "vacat", "golem", "slimelet", "skeleton"]
WINDUP, STRIKE = 0.3125, 0.53125

src = open(os.path.join(ROOT, "scripts/ui/art.gd"), encoding="utf-8").read()
block = src[src.index("const POSE_PROFILE := {"):]
block = block[:block.index("\n}\n")]
prof = {}
for m in re.finditer(r"^\s*(\d+):\s*\[([^\]]+)\],\s*#\s*(.*)$", block, re.M):
    prof[int(m.group(1))] = ([float(x) for x in m.group(2).split(",")], m.group(3).strip())

out_dir = os.path.join(ROOT, "data/poses")
os.makedirs(out_dir, exist_ok=True)
files = {}
for t in sorted(prof):
    f, about = prof[t]
    hold = STRIKE + f[8] * (1.0 - STRIKE)
    wind = [-1.0, -f[2], f[0], f[1], f[3]]
    hit = [1.0, f[6], f[4], f[5], f[7]]
    keys = [{"t": 0.0, "pose": [0.0, 0.0, 1.0, 1.0, 0.0]},
            {"t": WINDUP, "pose": wind, "ease": "smooth"},
            {"t": STRIKE, "pose": hit, "ease": "ease_out"}]
    if f[8] > 0.0:
        keys.append({"t": hold, "pose": hit, "ease": "step"})
    keys.append({"t": 1.0, "pose": [0.0, 0.0, 1.0, 1.0, 0.0], "ease": "smooth"})
    name = NAMES[t]
    d = {"unit": name, "about": "1.2.0 §7.1 姿勢資料（由 tools/gen/pose_gen.py 從 POSE_PROFILE 產生；之後可直接手調這個檔）：" + about +
         "。每個關鍵幀：t＝攻擊進度 0～1；pose＝[擺臂 w, 軀幹轉角 rot（弧度，正＝前撲）, 橫縮放 sx, 縱縮放 sy, 前後位移 dx]；ease＝從上一幀到這一幀的曲線（linear／smooth／ease_out／back／step）。事件 hit 的時間必須等於模擬的命中點（ATK_STRIKE），演出不能延後。",
         "keys": keys, "events": {"hit": STRIKE}}
    fn = "sword.json" if t == 0 else "%02d_%s.json" % (t, name)   # 劍士沿用試點檔名
    with open(os.path.join(out_dir, fn), "w", encoding="utf-8", newline="\n") as fp:
        json.dump(d, fp, ensure_ascii=False, indent=1)
        fp.write("\n")
    files[t] = fn

lines = ["extends RefCounted", "## 由 tools/gen/pose_gen.py 產生：兵種 → 姿勢資料檔（1.2.0 §7.1）。不要手改。", "const FILES := {"]
for t in sorted(files):
    lines.append('\t%d: "res://data/poses/%s",' % (t, files[t]))
lines.append("}")
with open(os.path.join(ROOT, "scripts/ui/pose_files.gd"), "w", encoding="utf-8", newline="\n") as fp:
    fp.write("\n".join(lines) + "\n")
print("POSES", len(files))
