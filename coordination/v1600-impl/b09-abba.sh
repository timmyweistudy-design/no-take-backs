#!/bin/bash
# B09 S7 第二版：ABBA（A＝--no-pack 即時烘、B＝離線包）。blank：每塊 5 個程序×8 塊＝每邊 20 冷、每程序 20 熱；scene 同樣每邊 20（Codex B09 r3 #3）
cd /mnt/c/Users/timmy/projects/no-take-backs/game
G="/mnt/c/Users/timmy/OneDrive/桌面/godot/Godot_v4.6.2-stable_win64.exe"
W=$(wslpath -w "$PWD")
for mode in blank scene; do
  O=$(wslpath -w "$PWD/../build/tmp/b09/abba2_$mode"); mkdir -p ../build/tmp/b09/abba2_$mode
  per=5
  i=0
  for side in A B B A A B B A; do
    for k in $(seq 1 $per); do
      i=$((i+1)); extra=""; [ $side = A ] && extra="--no-pack"; [ $mode = blank ] && extra="$extra --bench-blank"
      timeout 300 "$G" --path "$W" --resolution 1280x800 -- --pack-bench="$O\\${side}_$i.json" $extra </dev/null >/dev/null 2>&1
    done
  done
done
echo ABBA2_DONE
