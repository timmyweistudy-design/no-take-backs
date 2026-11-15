#!/usr/bin/env python3
"""1.6.0 B01（P11.4）差分擴驗：從改動的檔案推出開發時要重拍哪些畫面。
用法：python3 tools/affected_shots.py [git 範圍，預設 HEAD]   （在 game/ 下；看工作目錄＋暫存區對該範圍的差異）
輸出：最後一行 `AFFECTED FULL <理由>` 或 `AFFECTED <n> <逗號分隔的截圖名>`；後者可直接給 LAYOUT_SHOTS。
規則（寧可多拍）：
- 共用的東西（字型、字串、色票、介面底層、整個畫面腳本的入口、模擬、截圖腳本、版面檢查）→ FULL（24 組全量）。
- 已知只影響某類畫面的檔案 → 依 screens.json 的 entry 關鍵字挑。
- 不認得的 scripts/ui 檔 → FULL（依賴不明就擴大）。
- 只改 tests/、docs/、coordination/ → 不用重拍（輸出 0 張）。
發版一律全量；這只是開發回饋。"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # game/
FULL = [
    ("data/", "遊戲資料（殘局、字串、譯稿、地圖…）"), ("tools/screens.json", "截圖登記"), ("fonts/", "字型"), ("scripts/ui/palette.gd", "色票"), ("scripts/ui/ui_base.gd", "介面底層"),
    ("scripts/ui/game_screens.gd", "畫面入口"), ("scripts/ui/layout_rules.gd", "版面規則"), ("scripts/ui/art.gd", "角色繪製"),
    ("scripts/ui/sprite_cache.gd", "圖集"), ("scripts/core/", "模擬"), ("scripts/game/save.gd", "存檔"), ("tools/dev_main.gd", "截圖腳本"),
    ("tools/layout_check.sh", "版面檢查"), ("scripts/ui/screens/game_v16.gd", "跨很多畫面的混合腳本"), ("art/", "素材"), ("shaders/", "shader"), ("project.godot", "專案設定"), ("scripts/ui/table_seats.gd", "桌位表"),
]
# 檔案 → screens.json entry 開頭關鍵字（任一命中就拍）
ENTRY = {
    "scripts/ui/screens/game_place.gd": ["擺陣", "自由排兵", "殘局", "主題試煉"],
    "scripts/ui/free_place.gd": ["擺陣", "自由排兵"],
    "scripts/ui/lobby_view.gd": ["對 AI 大廳", "雙人", "標題"],
    "scripts/ui/screens/game_result.gd": ["結果", "結果頁", "遠征總結"],
    "scripts/ui/screens/game_menus.gd": ["標題", "設定", "收藏", "殘局列表", "確認窗", "第一次開遊戲", "代碼", "離開確認"],
    "scripts/ui/screens/game_modes.gd": ["主題試煉", "戰績", "遠征", "宿敵", "極速賽", "一陣三考"],
    "scripts/ui/screens/game_playroom.gd": ["遊戲間", "塗裝室", "合作接力", "裂隙"],
    "scripts/ui/codex_view.gd": ["圖鑑"],
    "scripts/ui/replay_view.gd": ["重播", "覆盤", "結果"],
    "scripts/ui/battle_view.gd": ["戰鬥", "重播"],
    "scripts/ui/battle/battle_units.gd": ["戰鬥", "重播", "擺陣"],
    "scripts/ui/battle/battle_fx.gd": ["戰鬥", "重播"],
    "scripts/ui/battle/battle_state.gd": ["戰鬥", "重播"],
}
QUIET = ("tests/", "../docs/", "docs/", "../coordination/", "coordination/", "tools/affected_shots.py")

def changed(rng):
    out = subprocess.run(["git", "diff", "--name-only", rng], cwd=ROOT, capture_output=True, text=True).stdout.split()
    out += subprocess.run(["git", "ls-files", "--others", "--exclude-standard", "--full-name"], cwd=ROOT, capture_output=True, text=True).stdout.split()
    return sorted(set(f[len("game/"):] if f.startswith("game/") else "../" + f for f in out))

def decide(files, screens):
    shots = set()
    for f in files:
        if f.startswith(QUIET) or f.endswith((".md", ".txt")) and not f.startswith("data/"):
            continue
        for pre, why in FULL:
            if f.startswith(pre):
                return "FULL", "%s（%s）" % (why, f)
        if f in ENTRY:
            keys = ENTRY[f]
            for n, v in screens.items():
                e = v.get("entry", "")
                if any(e.startswith(k) for k in keys):
                    shots.add(n)
            # 沒被任何對照表認領的畫面（入口名不在表裡）也一起拍——依賴不明就擴大（Codex v1600 B01 #2）
            allk = [k for ks in ENTRY.values() for k in ks]
            for n, v in screens.items():
                if not any(v.get("entry", "").startswith(k) for k in allk):
                    shots.add(n)
            continue
        if f.startswith(("scripts/", "tools/", "../tools/")) and f.endswith((".gd", ".py", ".sh")):
            if f.startswith("tools/") and not f.endswith(".gd"):
                continue   # 其他工具腳本不影響畫面
            return "FULL", "依賴不明（%s）" % f
    return "LIST", sorted(shots)

if __name__ == "__main__":
    rng = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
    screens = json.load(open(os.path.join(ROOT, "tools/screens.json"), encoding="utf-8"))
    kind, v = decide(changed(rng), screens)
    if kind == "FULL":
        print("AFFECTED FULL", v)
    else:
        print("AFFECTED %d %s" % (len(v), ",".join(v)))
