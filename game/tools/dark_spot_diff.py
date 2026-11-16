#!/usr/bin/env python3
"""1.6.0 B06（Codex B06 r2 #2）：紙面暗斑對比——桌燈紙打開 vs 關掉（同一份程式、同組合）比名單。
版面檢查把「紙面暗斑對比」記在 layout.jsonl 的 warnings：取字底最接近字色那側的 2% 分位（只取紙色像素、紙面內縮 6px）。
「未量」＝紙面模式取樣不足（不退回字框外圍）。亮紙時就有的（多半是元件自己的框線、鍵帽框）不算 B06 造成；桌燈紙新增的＝失敗。
用法：python3 tools/dark_spot_diff.py <開：版面輸出夾> <關：LAYOUT_NO_DESK_PAPER=1 的輸出夾>   最後一行 DARKSPOT OK／FAIL"""
import glob, json, os, sys

def load(out):
    spots, combos = {}, set()
    for f in sorted(glob.glob(os.path.join(out, "*", "layout.jsonl"))):
        combo = os.path.basename(os.path.dirname(f))
        combos.add(combo)
        for ln in open(f, encoding="utf-8"):
            d = json.loads(ln)
            for w in d.get("warnings", []):
                if w.get("type") in ("紙面暗斑對比", "紙面暗斑未量"):
                    # 鍵含位置（Codex B06 r3 #3：同頁同字別處新增的暗斑不會被既有那筆蓋掉）；「未量」＝取樣不足，桌燈紙新增的也算失敗
                    spots[(combo, d["shot"], w.get("s", ""), tuple(w.get("at", ())), w["type"])] = float(w.get("ratio", 0))
    return spots, combos

on, c_on = load(sys.argv[1])
off, c_off = load(sys.argv[2])
fails = []
# 對照（關）可以只拍幾組（四語、三字級各涵蓋）：只在對照有的組合上比；對照的組合開的那邊一定要有
if not c_off or not c_off <= c_on:
    fails.append("對照組合不在新版裡或是空的（開 %s／關 %s）" % (sorted(c_on), sorted(c_off)))
on = {k: v for k, v in on.items() if k[0] in c_off}
added = sorted(k for k in on if k not in off)
for k in added:
    print("  新增%s：%s %s「%s」@%s %.2f" % (k[4][2:], k[0], k[1], k[2], list(k[3]), on[k]))
if added:
    fails.append("桌燈紙新增 %d 筆" % len(added))
print(("DARKSPOT OK" if not fails else "DARKSPOT FAIL " + "；".join(fails)) + "（%d 組；桌燈紙 %d 筆、亮紙 %d 筆、新增 %d）" % (len(c_off), len(on), len(off), len(added)))
sys.exit(1 if fails else 0)
