#!/usr/bin/env python3
"""把量產結果併進 game/data/puzzles.json（第十三輪）。

python3 tools/gen/puzzle_merge.py <草稿.json> <FORGE 輸出檔...>
- 草稿＋forge 算出的 star2、star3、solutions、best（三星解）→ "extra"，章內依難度排序（隨機擺法過關率高的在前）。
- 舊 25 關的 "best" 從 tests/golden/star_solutions.json 帶入（提示第二、三層用）。
- 寫入章節名稱與開場小故事。
- 沒找到解、或什麼都不放就過的關卡不併，印出來。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game/data/puzzles.json"
STARS = ROOT / "game/tests/golden/star_solutions.json"

CHAPTERS = [
    ("王國基礎", "Kingdom Basics",
     "公會剛開張，只招得到王國的老兵。先學會盾、弓、騎、劍、刺客怎麼互相剋。",
     "The guild has just opened and only kingdom veterans have signed up. Learn how shields, bows, horses, swords and assassins beat each other."),
    ("王國新兵", "Kingdom Recruits",
     "長槍兵、投彈兵、醫者、鼓手、狂戰士來報到了。每一位都有一招別人學不來的。",
     "Pikes, bombers, medics, drummers and berserkers report for duty. Each has one trick nobody else can do."),
    ("魔物報到", "Monsters Apply",
     "連魔物都來應徵了。牠們不懂規矩，但很好用。",
     "Even monsters want the job. They don't follow the rules, but they get results."),
    ("跨界連鎖", "Strange Partners",
     "王國兵和魔物一起上場。有些組合放在一起，會發生意想不到的事。",
     "Soldiers and monsters side by side. Some pairs do things neither could alone."),
    ("連鎖大作戰", "Chain Reactions",
     "三四種兵一起配合，敵人也開始混搭了。",
     "Three or four kinds working together, and now the enemy mixes too."),
    ("護送・死守・斬首", "Escort, Hold, Strike",
     "委託不再只是打贏：有人要保護、有時間要撐、有頭目要拿下。",
     "Contracts get specific: someone to protect, a clock to beat, a leader to take down."),
    ("地利", "Lay of the Land",
     "河、樹林、冰湖、熔岩、峽谷。地形會擋路、會拖慢、也會加速。",
     "Rivers, woods, ice, lava and canyons. Terrain blocks, slows and speeds."),
    ("限制與借力", "Less Is More",
     "兵不能多帶，或乾脆借敵人的力。",
     "Bring fewer units, or turn the enemy's tricks against them."),
    ("時序", "Timing",
     "公會發下技能卷軸。戰前寫好第幾秒放，開打後就改不了。",
     "The guild hands out skill scrolls. Write down when to cast before battle; once it starts, no changes."),
    ("宗師", "Grandmaster",
     "最後的委託，什麼都可能出現。落子無悔。",
     "The final contracts. Anything goes. No take-backs."),
]


# 第 7 章原本叫 t1～t10，和教學關 t1～t3 撞 ID（get_puzzle 會開成教學），改名 d1～d10（m1、m2 已經有人用）；舊量產輸出照這張表換
RENAME = {"t%d" % i: "d%d" % i for i in range(1, 11)}

# 粗跑那時的工具把剩餘門檻下限訂 5%，這幾關三星解只剩 1～3%（全套測試抓到）；工具已修，這裡蓋掉舊輸出
STAR2_FIX = {"x1": 1, "y6": 1, "l1": 1, "b3": 2, "s3": 3, "s10": 1, "z5": 1}


def main():
    drafts = {d["id"]: d for d in json.load(open(sys.argv[1], encoding="utf-8"))}
    order = [d["id"] for d in json.load(open(sys.argv[1], encoding="utf-8"))]
    res = {}
    for f in sys.argv[2:]:
        for line in open(f, encoding="utf-8", errors="ignore"):
            if line.startswith("FORGE "):
                r = json.loads(line[6:])
                r["id"] = RENAME.get(r["id"], r["id"])
                res[r["id"]] = r
    data = json.load(open(DATA, encoding="utf-8"))
    stars = json.load(open(STARS, encoding="utf-8"))
    for key in ("puzzles", "new_units", "fantasy_units"):
        for p in data[key]:
            if p["id"] in stars["puzzles"]:
                p["best"] = {"u": stars["puzzles"][p["id"]], "p": []}
    data["chapters"] = [{"zh": a, "en": b, "story_zh": c, "story_en": d} for a, b, c, d in CHAPTERS]
    extra, skipped = [], []
    for i in order:
        d = dict(drafts[i])
        r = res.get(i)
        if r is None or "best" not in r:
            skipped.append((i, "沒有找到解" if r else "沒有結果"))
            continue
        if r["metrics"].get("empty_ok"):
            skipped.append((i, "什麼都不放就過"))
            continue
        d["star2"] = min(r["star2"], STAR2_FIX.get(i, 999))
        d["star3"] = r["star3"]
        d["solutions"] = r["solutions"]
        d["best"] = r["best"]
        if "sol_plans" in r:
            d["sol_plans"] = r["sol_plans"]
        d["_m"] = {k: r["metrics"][k] for k in ("rand_pct", "kinds", "tol", "ticks") if k in r["metrics"]}
        if "hero_free_ok" in r["metrics"]:
            d["_m"]["hero_free_ok"] = r["metrics"]["hero_free_ok"]
        extra.append(d)
    # 章內依難度：隨機擺法過關率高的在前；同率照草稿順序
    pos = {i: k for k, i in enumerate(order)}
    extra.sort(key=lambda d: (d["ch"], -d["_m"].get("rand_pct", 0), pos[d["id"]]))
    # V1.1：第 11 章（chapter11_merge.py 附加的）原樣保留，重跑前 10 章的合併不會把它洗掉
    keep11 = [p for p in json.load(open(DATA, encoding="utf-8"))["extra"] if int(p.get("ch", 0)) >= 11]
    data["extra"] = extra + keep11
    if keep11:
        data["chapters"] = data["chapters"][:10] + json.load(open(DATA, encoding="utf-8"))["chapters"][10:]
    json.dump(data, open(DATA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("併入", len(extra), "關")
    for i, why in skipped:
        print("略過", i, why)


if __name__ == "__main__":
    main()
