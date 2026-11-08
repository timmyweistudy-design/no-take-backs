#!/usr/bin/env python3
"""V1.4 #7：把 ghost_forge.gd 的 30 個幽靈陣寫成 game/data/ghosts.json，依 AI 模板取名（每個模板兩個名號）。
用法：python3 tools/gen/ghost_merge.py <forge 輸出>"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAMES = {
    "均衡軍": [("北境老將", "The Northern Veteran"), ("無名棋手", "The Nameless Player")],
    "鐵壁弓陣": [("霧谷弓手會", "Mistvale Archers' Guild"), ("雙橋守將", "Warden of Twin Bridges")],
    "鐵騎突擊": [("黃沙遊騎", "The Dune Riders"), ("石橋騎士", "Knights of the Stone Bridge")],
    "暗影刺殺": [("夜梟", "The Night Owls"), ("無聲的客人", "The Silent Guests")],
    "劍海": [("紅鬍子傭兵團", "Redbeard Company"), ("千劍廣場", "Square of a Thousand Swords")],
    "騎射混編": [("邊境巡林隊", "The Border Rangers"), ("冬營獵團", "Winter Camp Hunters")],
    "槍盾方陣": [("長槍老兵團", "The Old Pike Brigade"), ("銀盾騎士團", "Order of the Silver Shield")],
    "砲擊陣": [("煙火匠公會", "The Fireworks Guild"), ("東風砲台", "East Wind Battery")],
    "醫療鐵壁": [("修道院醫護隊", "The Abbey Infirmary"), ("不倒的牆", "The Wall That Won't Fall")],
    "戰鼓衝陣": [("雷鼓樂隊", "The Thunder Drums"), ("凱旋遊行", "The Victory Parade")],
    "破陣突擊": [("王室近衛", "The Royal Guard"), ("破城錘", "The Battering Ram")],
    "黏黏大軍": [("沼澤黏黏會", "The Bog Slime Society"), ("果凍節", "Jelly Festival")],
    "幽靈奇襲": [("幽靈船員", "The Phantom Crew"), ("午夜鐘聲", "The Midnight Bell")],
    "亡靈法陣": [("骨匠工坊", "The Bonewright Workshop"), ("灰塔法團", "The Grey Tower Circle")],
    "吸塵爆破": [("貓神信徒", "Cult of the Cat"), ("大掃除", "Spring Cleaning")],
    "石魔要塞": [("巨石守衛", "The Boulder Watch"), ("山中之城", "City in the Mountain")],
    "混編傭兵": [("老兵酒館", "The Veterans' Tavern"), ("流浪劇團", "The Wandering Troupe")],
    "陷阱弓陣": [("陷阱大師", "The Trapmasters"), ("寶箱商隊", "The Mimic Caravan")],
    "羊群衝鋒": [("牧羊人起義", "The Shepherds' Uprising"), ("羊毛大逃亡", "The Great Wool Escape")],
}


def main():
    cands = []
    for line in open(sys.argv[1], encoding="utf-8", errors="ignore"):
        if line.startswith("CAND "):
            cands.append(json.loads(line[5:]))
    # 勝率高的在前（同分照模板、成本），每個模板最多 2 個，取 30 個
    cands.sort(key=lambda c: (-c["wr"], c["t"], c["cost"]))
    per, rows = {}, []
    for c in cands:
        if len(rows) >= 30:
            break
        if per.get(c["tpl"], 0) >= 2 or any(c["units"] == r["units"] for r in rows):
            continue
        per[c["tpl"]] = per.get(c["tpl"], 0) + 1
        rows.append(c)
    used = {}
    out = []
    for i, r in enumerate(rows):
        k = used.get(r["tpl"], 0)
        used[r["tpl"]] = k + 1
        zh, en = NAMES.get(r["tpl"], [("無名陣", "Nameless Host")] * 2)[min(k, 1)]
        out.append({"id": "g%02d" % (i + 1), "zh": zh, "en": en, "tpl": r["tpl"], "wr": r["wr"], "cost": r["cost"],
                    "units": [{"type": u["type"], "col": u["col"], "row": u["row"]} for u in r["units"]]})
    json.dump(out, open(ROOT / "game/data/ghosts.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("幽靈", len(out), "個；勝率", [g["wr"] for g in out][:10], "…")


if __name__ == "__main__":
    main()
