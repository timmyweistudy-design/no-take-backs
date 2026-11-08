#!/usr/bin/env python3
"""V1.4 #17：把簡中、日文寫進遊戲資料。
用法：PYTHONPATH=build/pylib17 python3 tools/gen/l10n_build.py <日文譯稿資料夾（ja_*.json）>
- 簡中：OpenCC tw2sp（台灣正體→大陸簡體＋慣用詞），再套 FIX 修正遊戲用語。
- 日文：Codex 譯稿（{id: 日文}）；缺的、佔位符對不上的退回英文並列出來。
- 寫入：strings.csv 加 zh_CN、ja 兩欄；puzzles/trials/codex.json 加 *_sc、*_ja；data/l10n_extra.csv（程式裡的二元陣列）。
重跑會覆蓋舊的簡中／日文欄位。翻譯是 AI 產生、未經母語校對（設定頁有標示）。
"""
import csv, io, json, re, sys
from pathlib import Path
from opencc import OpenCC

sys.path.insert(0, str(Path(__file__).resolve().parent))
import l10n_extract as X

ROOT = Path(__file__).resolve().parents[2]
G = ROOT / "game"
cc = OpenCC("tw2sp")
FIX = [("拷贝", "复制"), ("缺省", "预设"), ("接口", "界面"), ("手把", "手柄"), ("全屏幕", "全屏"), ("殘局", "残局"), ("土豆", "马铃薯")]
LANG_NAME = {"zh_CN": "简体中文", "ja": "日本語"}
OVERRIDE = {("ja", "title"): "落子無悔",
    ("ja", "pf_none"): "未出撃", ("ja", "ct_clean_d"): "戦力6割以上で勝利", ("ja", "pt_call"): "勝敗が見えた", ("ja", "rv_moved"): "%sを%dマス動かしました", ("ja", "rv_you_free"): "自軍陣形（兵を選んで編集）",
    ("ja", "lb_pinfo_fantasy"): "傭兵ギルド解禁：魔物軍全10種が参戦。調整中のお遊びルールです。", ("ja", "err_locked"): "このユニットは固定です",
    # 簡中「預設＝默認值」的地方（「我的预设」是存下來的配置，保留）（Codex v140-i4）
    ("zh_CN", "set_speed"): "默认观战速度", ("zh_CN", "set_rule"): "双人默认规则",
    ("zh_CN", "sd_set_plain_titles"): "标题改用一般的黑体字（默认是毛笔风格的标题字）。",
    # 日文用語統一與不自然的譯法（Codex v140-i4）
    ("ja", "paint_wash"): "ウォッシュ", ("ja", "paint_dry"): "ドライブラシ", ("ja", "rv_remove"): "外す", ("ja", "rv_removed"): "%sを外した",
    # 版面檢查（日文 150%）抓到的太長字串，手動縮短
    ("ja", "sd_set_lang"): "表示言語。日本語はAI翻訳で、まだ校正していません。", ("zh_CN", "sd_set_lang"): "界面语言。简体中文是 AI 翻译，尚未校对。",
    ("ja", "lb_cmd_quick"): "技：%s", ("ja", "lb_deck_random"): "ランダム", ("ja", "lb_roster_title"): "出撃（%d／10）",
    ("ja", "tm_btn"): "時を戻して1体変更", ("ja", "pf_ach_hint"): "触れると条件表示", ("ja", "menu_daily"): "日替わり",
    ("ja", "rv_hint"): "マスを選んで種類変更・撤去・移動。変更は1体まで、戦績には残りません。",
    ("ja", "rv_hint_free"): "ユニットを選んで種類変更・撤去・移動。変更は1体まで、戦績には残りません。",
    ("ja", "rw_recruit_d"): "%s加入、%s離脱（この遠征のみ）", ("ja", "ph_locked"): "星を1つ取ると、星3解答のユニット構成が見られます。",
    ("ja", "pr_wager_d"): "AI同士の陣形を見て、勝者と差を予想。当てて眼力アップ。",
    ("ja", "pr_draft_d"): "8枚からAIと交互に4枚ずつ取り、そのカードで勝負。",
    ("ja", "pr_waves_d"): "一度の配置で三連戦。生き残りはその場に残り、15 G追加。",
    ("ja", "pr_sealed_d"): "2人が陣形を3つ封印。1戦ごとに1通開封、2勝先取。"}
DATA_OVERRIDE = {"落子無悔（ノー・テイクバック）": "落子無悔"}
JA_FIX = [("モンスター兵団", "魔物兵団"), ("モンスター軍", "魔物軍")]   # 用語統一（短、和中文一樣是漢字）
PH = re.compile(r"%[-+0-9.]*[sdf]|\{[A-Z0-9_]+\}")


def sc(s):
    t = cc.convert(s.replace("隻", "個"))   # 兵的量詞：大陸遊戲用「个」，不用「只」（「这只是」會被讀成「僅僅是」，Antigravity v140-i4）
    for a, b in FIX:
        t = t.replace(a, b)
    return t


def load_ja(d):
    ja = {}
    for f in sorted(Path(d).glob("ja_*.json")):
        txt = f.read_text(encoding="utf-8").strip()
        txt = re.sub(r"^```(?:json)?\s*|\s*```$", "", txt)
        try:
            ja.update(json.loads(txt))
        except Exception as e:
            print("讀不到", f.name, e)
    return ja


def main():
    ja = load_ja(sys.argv[1])
    bad = []

    def jp(item):
        v = ja.get(item["id"], "")
        if not isinstance(v, str) or not v.strip():
            bad.append((item["id"], "沒翻"))
            return item["en"] or item["zh"]
        stray = lambda x: PH.sub("", x.replace("%%", "")).count("%")   # 落單的 %（例如把 %d%% 寫成 %d%）
        if sorted(PH.findall(v)) != sorted(PH.findall(item["zh"])) or stray(v) != stray(item["zh"]):
            bad.append((item["id"], "佔位符不同"))
            return item["en"] or item["zh"]
        for a, b in JA_FIX:
            v = v.replace(a, b)
        return v

    # strings.csv
    p = G / "data/strings.csv"
    rows = list(csv.reader(open(p, encoding="utf-8", newline="")))
    head = rows[0][:3]
    out = [head + ["zh_CN", "ja"]]
    for r in rows[1:]:
        if not r:
            continue
        k, zh, en = r[0], r[1], r[2]
        if k == "lang_name":
            out.append([k, zh, en, LANG_NAME["zh_CN"], LANG_NAME["ja"]])
            continue
        out.append([k, zh, en, OVERRIDE.get(("zh_CN", k), sc(zh)), OVERRIDE.get(("ja", k)) or jp({"id": "s:" + k, "zh": zh, "en": en})])
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(out)
    p.write_text(buf.getvalue(), encoding="utf-8")
    # 資料檔
    for fn in X.DATA:
        fp = G / "data" / fn
        d = json.load(open(fp, encoding="utf-8"))
        items = []
        X.walk(d, "", fn, items)
        for it in items:
            _, _, path, base = it["id"].split(":", 3)
            o = d
            for seg in [s for s in path.split(".") if s != ""]:
                o = o[int(seg)] if isinstance(o, list) else o[seg]
            pre = base + "_" if base else ""
            o[pre + "sc"] = sc(it["zh"])
            v = jp(it) if it["zh"].strip() else ""
            o[pre + "ja"] = DATA_OVERRIDE.get(v, v)
        json.dump(d, open(fp, "w", encoding="utf-8"), ensure_ascii=False, indent=2 if fn == "trials.json" else 1)
    # 程式裡的二元陣列
    ex = X.extra()
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(["zh_TW", "zh_CN", "ja"])
    for it in ex:
        w.writerow([it["zh"], sc(it["zh"]), jp(it)])
    (G / "data/l10n_extra.csv").write_text(buf.getvalue(), encoding="utf-8")
    print("簡中、日文寫入完成；日文退回英文 %d 筆" % len(bad))
    for i, why in bad[:40]:
        print("  ", why, i)


if __name__ == "__main__":
    main()
