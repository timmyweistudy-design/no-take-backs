#!/usr/bin/env bash
# 版面檢查（第三輪 T4）：用 Windows 版 Godot 跑截圖模式，兩種語言 × 三種字級，彙整 layout.jsonl。
# 用法：tools/layout_check.sh <Godot 執行檔> <輸出資料夾（WSL 路徑）>
set -uo pipefail
cd "$(dirname "$0")/.."
EXE="$1"; OUT="$2"
rm -rf "$OUT"; mkdir -p "$OUT"
for lang in zh_TW en; do
  for sc in 100 125 150; do
    d="$OUT/${lang}_${sc}"; mkdir -p "$d"
    timeout 300 "$EXE" --path "$(wslpath -w .)" --resolution 1280x800 -- --shot="$(wslpath -w "$d")" --shot-lang=$lang --shot-text=$sc --layout-check > "$d/run.log" 2>&1 \
      || { echo "LAYOUT FAIL：$lang $sc% 截圖程式 exit 非 0"; exit 1; }
    grep -E "SCRIPT ERROR|Parse Error" "$d/run.log" >/dev/null && { echo "LAYOUT FAIL：$lang $sc% 有腳本錯誤"; exit 1; }
  done
done
EXPECT=$(grep -o '_snap("[^"]*")' scripts/ui/main.gd | wc -l)
python3 - "$OUT" "$EXPECT" <<'PY'
import json,sys,glob,os
out=sys.argv[1]; expect=int(sys.argv[2]); total=0; rows=[]
for f in sorted(glob.glob(os.path.join(out,'*','layout.jsonl'))):
    for line in open(f,encoding='utf-8'):
        d=json.loads(line); total+=len(d['violations']); rows.append(d)
by={}
for d in rows: by.setdefault((d['lang'],d['scale']),[]).append(d['median_size'])
print('LAYOUT 截圖 %d 張、違規 %d' % (len(rows), total))
for d in rows:
    for v in d['violations']: print('  %s %s %d%%：%s' % (d['shot'], d['lang'], d['scale'], v))
for lang in ['zh_TW','en']:
    if (lang,100) in by and (lang,150) in by:
        a=sorted(by[(lang,100)]); b=sorted(by[(lang,150)])
        print('  %s 中位字級 100%%=%s 150%%=%s' % (lang, a[len(a)//2], b[len(b)//2]))
runs=glob.glob(os.path.join(out,'*','layout.jsonl'))
if len(runs)!=6 or len(rows)!=6*expect:
    print('LAYOUT FAIL：應有 6 組 × %d 張，實得 %d 組、%d 張（截圖沒跑完也算失敗）' % (expect, len(runs), len(rows))); sys.exit(1)
sys.exit(1 if total else 0)
PY
