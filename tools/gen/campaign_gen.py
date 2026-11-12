#!/usr/bin/env python3
"""1.2.0 §11.7 戰役資料：5 章 ×（6 戰＋1 殘局），寫 game/data/campaign.json。
每戰：敵方預算（漸增）、AI 種子、目標（win 贏／keep 贏且至少 N 隻活著／time 在 T 秒內贏）、AI 等級。殘局＝該章對應殘局章節的第一關。
敵陣在遊戲裡用 AI.build(1, 敵方預算, 種子) 產生（確定性）。重產：python3 tools/gen/campaign_gen.py"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
chapters = []
for c in range(1, 6):
    stages = []
    for i in range(6):
        n = (c - 1) * 6 + i
        goal = ["win", "keep", "win", "time", "win", "keep"][i]
        st = {"id": "c%d_%d" % (c, i + 1), "enemy_budget": min(200, 80 + n * 4), "seed": 120000 + n * 7919, "ai": 0 if c == 1 else (1 if c <= 3 else 2), "goal": goal}
        if goal == "keep":
            st["keep"] = 2 + c // 2
        if goal == "time":
            st["secs"] = 70 - c * 4
        stages.append(st)
    stages.append({"id": "c%d_p" % c, "puzzle_chapter": min(c, 5), "goal": "puzzle"})
    chapters.append({"n": c, "note": "cmp_note_%d" % c, "stages": stages})
out = {"about": "1.2.0 §11.7 戰役（產生器 tools/gen/campaign_gen.py）", "ver": 1, "chapters": chapters}
json.dump(out, open(ROOT + "/game/data/campaign.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("campaign", sum(len(ch["stages"]) for ch in chapters))
