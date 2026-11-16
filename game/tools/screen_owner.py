#!/usr/bin/env python3
"""1.6.0 B06：200 畫面批次歸屬表（方案 §5「六把尺全站覆蓋」）。
依 tools/screens.json 的 entry（入口）與檔名逐頁歸屬；每頁一定要有主批次，沒有＝非零結束（新畫面登記時要補規則）。
用法：python3 tools/screen_owner.py [輸出.md]"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
B03_DONE = {"01_title", "02_place", "05_result"}   # S2 三代表頁
B07_EN = {"08f_settings_controls", "23_lobby_pool", "58_trials", "89_trials_p2", "10_codex", "60_reward", "01_title"}   # 方案 P2.3 英文 150% 重災頁
# (樣式, 主批次, 說明)；依序比對 entry，再比檔名；第一個中的算
RULES = [
    (r"開發用", "—", "開發用展示頁（不上架；只要 24 組 0 違規）"),
    (r"^標題→卡片面板|第一次開遊戲|^標題$|^標題（「更多」|試玩版結束|主畫面", "B05", "第一幕：首開便條、卡片面板主牌"),
    (r"放大鏡", "B08", "放大鏡進槽、戰鬥 HUD"),
    (r"大廳|^雙人(→禁牌)?$", "B04", "大廳挑戰簿、木撥片"),
    (r"宣紙戰報|棋譜本", "B16", "宣紙戰報＋棋譜本"),
    (r"覆盤|時光機", "B15", "覆盤帳本"),
    (r"出題台|競猜", "B21", "舊器物精修"),
    (r"^戰鬥|^對戰|重播|手動技能|謝幕|^奇幻", "B08", "混戰可讀、戰鬥 HUD（桌面與盤外已在 B03／B06）"),
    # B06 明確清單（Codex B06 r1 #3：不用萬用規則——新入口沒列在任何一條＝失敗，登記時要決定歸屬）
    (r"^(結果|設定|圖鑑|戰績|宿敵|殘局|主題試煉|試煉第|遠征|遊戲間|擺陣|自由排兵|自由部署|軍令時間軸|雙人盲擺|確認窗|離開確認|代碼|回報分類|"
     r"塗裝室|實驗簿|接力殘局|合作接力|教練|新玩法導覽|極速賽|一陣三考|裂隙|每日挑戰)", "B06", "全站同一張桌：紙面灰階、接觸影、盤外桌面"),
]
TERRAIN = re.compile(r"^(5[0-6]_map_|82_place_terrain|87_battle_terrain|87b_quarry|87c_quarry|87d_boss|v120_07_editor_map)")

def owner(name: str, entry: str):
    if name in B03_DONE:
        return "B03", "代表頁（S2 已做）"
    if TERRAIN.match(name):
        return "B06", "地形微縮（P1.4）" + ("；戰鬥 HUD 屬 B08" if "battle" in name else "")
    for pat, b, why in RULES:
        if re.search(pat, entry):
            return b, why
    return None, ""

def main():
    d = json.load(open(os.path.join(HERE, "screens.json"), encoding="utf-8"))
    rows, miss, cnt = [], [], {}
    for fn, v in d.items():
        name = fn[:-4]
        b, why = owner(name, v.get("entry", ""))
        if b is None:
            miss.append(name)
            continue
        extra = "；英文 150% 改寫屬 B07" if name in B07_EN else ""
        cnt[b] = cnt.get(b, 0) + 1
        rows.append(f"| `{name}` | {v.get('entry','')} | {b} | {why}{extra} |")
    out = ["# 1.6.0 畫面批次歸屬表（`tools/screen_owner.py` 產生，勿手改）", "",
           "方案 §5：200 畫面逐頁歸屬。主批次＝這一頁的桌面、材質、版面由哪一批負責；B06 以外的頁在 B06 只保證不退步（24 組 0、固定時鐘容差內）。", "",
           "合計：" + "、".join(f"{k} {cnt[k]}" for k in sorted(cnt)) + f"（共 {sum(cnt.values())}）", "",
           "| 畫面 | 入口 | 主批次 | 說明 |", "|---|---|---|---|"] + rows
    if len(sys.argv) > 1:
        open(sys.argv[1], "w", encoding="utf-8").write("\n".join(out) + "\n")
    if miss:
        print("SCREEN_OWNER FAIL 沒有歸屬：" + "、".join(miss))
        sys.exit(1)
    print(f"SCREEN_OWNER OK {sum(cnt.values())} 頁：" + "、".join(f"{k} {cnt[k]}" for k in sorted(cnt)))

if __name__ == "__main__":
    main()
