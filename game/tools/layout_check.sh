#!/usr/bin/env bash
# 版面檢查（第三輪 T4）：用 Windows 版 Godot 跑截圖模式，兩種語言 × 三種字級，彙整 layout.jsonl。
# 用法：tools/layout_check.sh <Godot 執行檔> <輸出資料夾（WSL 路徑）>
set -uo pipefail
cd "$(dirname "$0")/.."
EXE="$1"; OUT="$2"
# 第七輪 I5：只准清自己產生的輸出夾（有記號檔），或空資料夾；其他一律拒絕，不再無條件 rm -rf
MARK=".ntb-layout-output"
if [ -d "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ]; then
  if [ ! -f "$OUT/$MARK" ]; then
    echo "LAYOUT FAIL：$OUT 已有內容但不是版面檢查的輸出夾，不會刪除。請換一個新資料夾。"; exit 2
  fi
  rm -rf "$OUT"
fi
mkdir -p "$OUT"; : > "$OUT/$MARK"
# Windows／WSL／Linux 都能跑：有 wslpath 才轉路徑
winpath() { if command -v wslpath >/dev/null 2>&1 && [[ "$EXE" == *.exe ]]; then wslpath -w "$1"; else printf '%s' "$1"; fi; }
# WSL 的 timeout 只殺得到包裝程序，Windows 上的視窗會留著繼續跑：逾時要連它一起關（只關這次輸出夾的）
kill_win() { if [[ "$EXE" == *.exe ]]; then powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*--shot=$(winpath "$1")*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1; fi; }
# 第九輪 P0：LAYOUT_QUICK=1 只跑中文 100%＋英文 150%（最容易出事的兩組）＋一組狀態；里程碑跑 8 組
# V1.2.1：第三欄是狀態（plain＝簡化介面、cb＝色盲、pad＝手把焦點），固定在這組全部截圖
# 完整：兩語 × 三字級，加上四種狀態（簡化、色盲、手把、停用）各在兩語的 150%（最容易擠）各跑一次＝14 組
# V1.4 #17：加簡中、日文各 100％／150％（共 18 組）；快速版多跑日文 150％
COMBOS="zh_TW:100 zh_TW:125 zh_TW:150 en:100 en:125 en:150 zh_TW:150:plain en:150:plain zh_TW:150:cb en:150:cb zh_TW:150:pad en:150:pad zh_TW:150:dis en:150:dis zh_CN:100 zh_CN:150 ja:100 ja:150"
[ "${LAYOUT_QUICK:-0}" = "1" ] && COMBOS="zh_TW:100 en:150 en:150:plain,cb,pad zh_TW:150:dis ja:150"
export LAYOUT_N=$(echo $COMBOS | wc -w)
for combo in $COMBOS; do
  IFS=: read -r lang sc st <<< "$combo"
  {
    d="$OUT/${lang}_${sc}${st:+_${st//,/-}}"; mkdir -p "$d"
    timeout 600 "$EXE" --path "$(winpath .)" --resolution 1280x800 -- --shot="$(winpath "$d")" --shot-lang=$lang --shot-text=$sc ${st:+--shot-state=$st} --layout-check > "$d/run.log" 2>&1 \
      || { echo "LAYOUT FAIL：$lang $sc% 截圖程式 exit 非 0"; kill_win "$d"; exit 1; }
    grep -E "SCRIPT ERROR|Parse Error" "$d/run.log" >/dev/null && { echo "LAYOUT FAIL：$lang $sc% 有腳本錯誤"; exit 1; }
    grep -q "PADWALK OK" "$d/run.log" || { echo "LAYOUT FAIL：$lang $sc% 手把流程：$(grep PADWALK "$d/run.log" | cut -c1-400)"; exit 1; }
  }
done
EXPECT=$(grep -o '_snap("[^"]*")' tools/dev_main.gd | wc -l)
NAMES=$(grep -o '_snap("[^"]*")' tools/dev_main.gd | sed 's/_snap("//; s/")//' | sort | tr '\n' ',')
python3 - "$OUT" "$EXPECT" "$NAMES" <<'PY'
import json,sys,glob,os
out=sys.argv[1]; expect=int(sys.argv[2]); names=set(x for x in sys.argv[3].split(',') if x); total=0; rows=[]
for f in sorted(glob.glob(os.path.join(out,'*','layout.jsonl'))):
    for line in open(f,encoding='utf-8'):
        d=json.loads(line); total+=len(d['violations']); rows.append(d)
warns=sum(len(d.get('warnings',[])) for d in rows)
# 第五輪：每組都要剛好是 dev_main.gd 列出的那些畫面（不能用重複畫面湊張數）
for f2 in sorted(glob.glob(os.path.join(out,'*','layout.jsonl'))):
    got=[json.loads(l)['shot'] for l in open(f2,encoding='utf-8')]
    if sorted(got)!=sorted(names) or len(set(got))!=len(got):
        print('LAYOUT FAIL：%s 的畫面集合不對（少了 %s、多了 %s）' % (f2, sorted(names-set(got)), sorted(set(got)-names))); sys.exit(1)
by={}
for d in rows: by.setdefault((d['lang'],d['scale']),[]).append(d['median_size'])
print('LAYOUT 截圖 %d 張、違規 %d' % (len(rows), total))
for d in rows:
    for v in d['violations']: print('  %s %s %d%%：%s' % (d['shot'], d['lang'], d['scale'], v))
for lang in ['zh_TW','en','zh_CN','ja']:
    if (lang,100) in by and (lang,150) in by:
        a=sorted(by[(lang,100)]); b=sorted(by[(lang,150)])
        print('  %s 中位字級 100%%=%s 150%%=%s' % (lang, a[len(a)//2], b[len(b)//2]))
runs=glob.glob(os.path.join(out,'*','layout.jsonl'))
want=int(os.environ.get('LAYOUT_N','14'))
if len(runs)!=want or len(rows)!=want*expect:
    print('LAYOUT FAIL：應有 %d 組 × %d 張，實得 %d 組、%d 張（截圖沒跑完也算失敗）' % (want, expect, len(runs), len(rows))); sys.exit(1)
sys.exit(1 if total else 0)
PY
