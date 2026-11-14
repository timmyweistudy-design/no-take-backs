#!/usr/bin/env python3
"""1.5.0 §12：固定時鐘美感基線（棋子輪廓對比）。
美感指標只在 LAYOUT_FIXED=1（固定幀時間）下比；一般版面檢查是真實時間，每次跑會浮動，不能比（1.4.0 收尾教訓）。
用法（game/ 下）：
  python3 tools/art_baseline.py save  <版面輸出夾> <基線檔>   # 逐畫面×組記 low_units／units
  python3 tools/art_baseline.py check <版面輸出夾> <基線檔>   # 任一畫面×組 low_units 高於基線＝失敗（exit 1）
  python3 tools/art_baseline.py merge <版面輸出夾> <基線檔>   # 新畫面補進基線（舊畫面不覆蓋）
"""
import json, os, sys, glob

def read(out_dir):
    """回傳 (有棋子的畫面×組 → [low, units], 這輪實際拍到的 畫面×組 集合)"""
    r, seen = {}, set()
    for f in sorted(glob.glob(os.path.join(out_dir, '*', 'layout.jsonl'))):
        combo = os.path.basename(os.path.dirname(f))
        for line in open(f, encoding='utf-8'):
            x = json.loads(line)
            key = '%s|%s' % (x['shot'], combo)
            seen.add(key)
            a = x.get('art') or {}
            if int(a.get('units', 0)) <= 0:
                continue
            r[key] = [int(a.get('low_units', 0)), int(a['units'])]
    return r, seen

def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ('save', 'check', 'merge'):
        print(__doc__); sys.exit(2)
    cmd, out_dir, base = sys.argv[1:]
    cur, seen = read(out_dir)
    if not seen:
        print('ART FAIL：%s 沒有任何版面輸出（空的輸出不能當通過）' % out_dir); sys.exit(1)
    if cmd == 'save':
        json.dump(cur, open(base, 'w', encoding='utf-8'), ensure_ascii=False, indent=0, sort_keys=True)
        print('ART 基線寫入 %d 筆（%s）' % (len(cur), base)); return
    old = json.load(open(base, encoding='utf-8')) if os.path.exists(base) else {}
    if cmd == 'merge':
        n = 0
        for k, v in cur.items():
            if k not in old:
                old[k] = v; n += 1
        json.dump(old, open(base, 'w', encoding='utf-8'), ensure_ascii=False, indent=0, sort_keys=True)
        print('ART 基線補進 %d 筆新畫面' % n); return
    worse, new, lo_c, lo_b = [], [], 0, 0
    # 這輪有拍到的畫面×組，基線有棋子、這輪卻沒有美感資料＝探針消失（不能靜靜通過；Codex v150 cat01 #1）
    lost = [k for k in sorted(old) if k in seen and k not in cur]
    # 判定單位＝畫面（24 組加總）：單一棋子在 3:1 門檻上下跳動會在組之間換位置，逐組比會誤判（1.5.0 第 1 批量測）；逐組差異只列出參考
    by_c, by_b, flips = {}, {}, []
    for k, v in sorted(cur.items()):
        if k not in old:
            new.append(k); continue
        shot = k.split('|')[0]
        by_c[shot] = by_c.get(shot, 0) + v[0]; by_b[shot] = by_b.get(shot, 0) + old[k][0]
        lo_c += v[0]; lo_b += old[k][0]
        if v[0] > old[k][0]:
            flips.append('%s：%d → %d（/%d）' % (k, old[k][0], v[0], v[1]))
    for shot in sorted(by_c):
        if by_c[shot] > by_b[shot]:
            worse.append('%s：%d → %d（24 組加總）' % (shot, by_b[shot], by_c[shot]))
    print('ART 固定時鐘棋子低對比 %d（基線 %d）；比基線差的畫面 %d 張、探針消失 %d 筆、新畫面 %d 筆（沒有基線，不算）；單組上下跳動 %d 筆（只列參考）' % (lo_c, lo_b, len(worse), len(lost), len(new), len(flips)))
    for w in worse[:40]:
        print('  ' + w)
    for k in lost[:20]:
        print('  探針消失 ' + k)
    sys.exit(1 if (worse or lost) else 0)

if __name__ == '__main__':
    main()
