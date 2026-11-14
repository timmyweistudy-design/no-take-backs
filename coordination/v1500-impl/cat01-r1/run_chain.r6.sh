#!/usr/bin/env bash
# 1.5.0 §12：背景驗收鏈。整條鏈綁 run ID 與提交雜湊、跑在自己的程序群；中止時整條停（含這條鏈開的 Windows Godot），確認退出才准開新輪。
# 用法（game/ 下）：
#   tools/run_chain.sh <名稱> '<步驟1>' '<步驟2>' …     # 依序跑，任一步失敗就停；紀錄 ../build/tmp/chains/<名稱>/<run>/
#   tools/run_chain.sh --stop <名稱>                     # 停掉整條鏈（Linux 程序群＋這條鏈開始之後啟動的 Windows Godot），確認退出
#   tools/run_chain.sh --status <名稱>
# 互斥：所有「看狀態→改狀態」（啟動登記、停止、子程序收尾）都在同一個 flock 裡（../build/tmp/chains/<名稱>.mutex），
# 「誰在跑」只看 <名稱>.active（內容＝run ID）；沒有 mkdir 鎖、沒有回收競態（Codex v150 cat01 r3／r4）。
set -u
cd "$(dirname "$0")/.." || exit 2
D="$(cd .. && pwd)/build/tmp/chains"
mkdir -p "$D"
runinfo() { sed -n "s/^$2=//p" "$D/$1/$3/run" 2>/dev/null | head -1; }
alive_pg() { [ -n "$1" ] && kill -0 -- "-$1" 2>/dev/null; }
win_godot_since() {   # 這條鏈開始之後啟動的 Windows Godot（WSL 砍不到 Windows 程序，只能從這邊找）。
  # 查詢失敗＝回傳非零（不能當成「沒有」）：PowerShell 退出碼要是 0、而且輸出 QUERY_OK；「沒有 Godot」不是錯誤
  local raw rc
  raw=$(powershell.exe -NoProfile -c "\$ErrorActionPreference='Stop'; try { \$t=[datetime]::Parse('$1', \$null, [Globalization.DateTimeStyles]::RoundtripKind); Get-Process | Where-Object { \$_.ProcessName -like 'Godot*' -and \$_.StartTime -ge \$t } | ForEach-Object { \$_.Id }; 'QUERY_OK'; exit 0 } catch { 'QUERY_FAIL'; exit 1 }" 2>/dev/null); rc=$?
  raw=$(printf '%s' "$raw" | tr -d '\r')
  [ $rc -eq 0 ] && printf '%s\n' "$raw" | grep -q '^QUERY_OK$' || return 1
  printf '%s\n' "$raw" | grep -v '^QUERY_OK$' | grep -v '^$' || true
}
leftover() {   # 這一輪是否還有殘留：程序群裡除了收尾者自己以外的程序、或這輪開始後啟動的 Windows Godot（查詢失敗也算有殘留）
  local pg="$1" st="$2" self="${3:-}" others w
  others=$(ps -o pid= -g "$pg" 2>/dev/null | tr -d ' ' | grep -v "^${self:-x}$" | grep -v '^$' || true)
  w=$(win_godot_since "$st") || { echo "Windows 查詢失敗"; return 0; }
  [ -n "$others$w" ] && { echo "程序群：$others Windows：$w"; return 0; }
  return 1
}
case "${1:-}" in
--finish)   # 子程序收尾（內部用）：在互斥裡核對 active＝自己，確認整輪沒有殘留才清 active
  name="$2"; rid="$3"; self="$4"
  exec 9>"$D/$name.mutex"; flock -x 9
  [ "$(cat "$D/$name.active" 2>/dev/null)" = "$rid" ] || exit 0
  pg=$(runinfo "$name" pgid "$rid"); st=$(runinfo "$name" started_win "$rid")
  for i in $(seq 1 20); do why=$(leftover "$pg" "$st" "$self") || break; sleep 0.5; done
  if why=$(leftover "$pg" "$st" "$self"); then echo "leftover=$why" >> "$D/$name/$rid/run"; exit 1; fi   # 有殘留：active 留著，要 --stop
  echo "$rid" > "$D/$name.last"; rm -f "$D/$name.active"; exit 0 ;;
--status)
  rid=$(cat "$D/$2.active" 2>/dev/null); last=$(cat "$D/$2.last" 2>/dev/null)
  r=${rid:-$last}; [ -n "$r" ] && cat "$D/$2/$r/run" || echo "CHAIN 沒有 $2"; exit 0 ;;
--stop)
  name="$2"
  exec 9>"$D/$name.mutex"; flock -x 9   # 停止全程持有互斥：啟動與收尾都得等
  rid=$(cat "$D/$name.active" 2>/dev/null)
  [ -n "$rid" ] || { echo "CHAIN $name 沒有在跑"; exit 0; }
  pg=$(runinfo "$name" pgid "$rid"); st=$(runinfo "$name" started_win "$rid")
  [ -n "$pg" ] || { echo "CHAIN $name 紀錄缺程序群（$rid）"; exit 1; }
  kill -TERM -- "-$pg" 2>/dev/null
  for i in $(seq 1 20); do alive_pg "$pg" || break; sleep 0.5; done
  alive_pg "$pg" && kill -KILL -- "-$pg" 2>/dev/null
  ids=$(win_godot_since "$st") || { echo "CHAIN $name 查不到 Windows 程序（查詢失敗），沒有確認退出"; exit 1; }
  for id in $ids; do powershell.exe -NoProfile -c "Stop-Process -Id $id -Force" >/dev/null 2>&1; done
  sleep 1
  left=$(win_godot_since "$st") || { echo "CHAIN $name 查不到 Windows 程序（查詢失敗），沒有確認退出"; exit 1; }
  if alive_pg "$pg" || [ -n "$left" ]; then echo "CHAIN $name 還沒停乾淨（Linux 程序群 $pg、Windows Godot：$left）"; exit 1; fi
  echo "state=stopped" >> "$D/$name/$rid/run"
  echo "$rid" > "$D/$name.last"; rm -f "$D/$name.active"
  echo "CHAIN $name 已停（run $rid）"; exit 0 ;;
esac
name="$1"; shift
[ $# -ge 1 ] || { echo "用法：tools/run_chain.sh <名稱> '<步驟>' …"; exit 2; }
exec 9>"$D/$name.mutex"; flock -x 9   # 啟動登記：看有沒有人在跑→開新輪→寫 active，全部在互斥裡
old=$(cat "$D/$name.active" 2>/dev/null)
if [ -n "$old" ]; then
  opg=$(runinfo "$name" pgid "$old")
  if alive_pg "$opg"; then echo "CHAIN $name 還在跑（run $old），先 --stop"; exit 1; fi
  if why=$(leftover "$opg" "$(runinfo "$name" started_win "$old")"); then echo "CHAIN $name 上一輪還有殘留（$why），先 --stop"; exit 1; fi
  echo "$old" > "$D/$name.last"; rm -f "$D/$name.active"   # 上一輪異常結束、也確認沒有殘留
fi
rid="$(date +%Y%m%d-%H%M%S)-$$"
R="$D/$name/$rid"; mkdir -p "$R"
commit="$(git rev-parse --short HEAD 2>/dev/null)$(git diff --quiet 2>/dev/null || echo +dirty)"
stw=$(powershell.exe -NoProfile -c "(Get-Date).ToString('o')" 2>/dev/null | tr -d '\r')   # 精確起點（不倒退、不截斷）
[ -n "$stw" ] || { echo "CHAIN $name 取不到 Windows 時間"; exit 1; }
printf 'run=%s\ncommit=%s\nstarted=%s\nstarted_win=%s\n' "$rid" "$commit" "$(date '+%F %T')" "$stw" > "$R/run"
SELF="$(pwd)/tools/run_chain.sh"; export SELF
setsid bash -c '
  R="$1"; D="$2"; name="$3"; rid="$4"; shift 4
  exec 9>&-   # 不繼承啟動者的互斥
  echo "pgid=$(ps -o pgid= $$ | tr -d " ")" >> "$R/run"
  for i in $(seq 1 50); do [ "$(cat "$D/$name.active" 2>/dev/null)" = "$rid" ] && break; sleep 0.2; done
  [ "$(cat "$D/$name.active" 2>/dev/null)" = "$rid" ] || { echo "state=aborted_unregistered" >> "$R/run"; exit 3; }   # 啟動者沒登記成功：不跑（Codex v150 cat01 r5 #1）
  n=0; rc=0
  for step in "$@"; do
    n=$((n+1)); echo "step$n=$step" >> "$R/run"
    bash -c "$step" > "$R/step$n.log" 2>&1; rc=$?
    echo "step${n}_rc=$rc" >> "$R/run"
    [ $rc -ne 0 ] && break
  done
  [ $rc -ne 0 ] && echo "state=failed@$n" >> "$R/run" || echo "state=done" >> "$R/run"
  "$SELF" --finish "$name" "$rid" $$' _ "$R" "$D" "$name" "$rid" "$@" 9>&- &
for i in $(seq 1 25); do grep -q '^pgid=' "$R/run" && break; sleep 0.2; done
grep -q '^pgid=' "$R/run" || { echo "CHAIN $name 子程序沒有登記程序群"; exit 1; }
echo "$rid" > "$D/$name.active"   # 子程序已登記程序群之後才算「在跑」，還在互斥裡
echo "CHAIN $name 開始（run $rid、$commit）：$R"
