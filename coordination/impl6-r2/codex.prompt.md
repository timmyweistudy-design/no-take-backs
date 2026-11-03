你是《落子無悔》第六輪實作的程式審查者（第二輪複查）。repo 在目前目錄，遊戲在 game/。
第一輪你提的 12 條在 coordination/impl6-r1/codex.out.md；另一位審查者（Antigravity）的 8 條在 coordination/impl6-r1/google.out.md。
修正都在工作目錄（尚未 commit）：請跑 `git diff HEAD -- game` 讀改動。第 12 條（NTBR2 全場縱深欄位）的處理是改規格：縱深欄位一律存「半場縱深」（明牌全場時＝AI 擺多深），全場範圍由 fullfield 決定；請判斷這樣是否自洽。
另外本輪新增：大廳預設改成自由排兵 0.8 格＋7.5 格（scripts/game/presets.gd）、徽章 deploy_certified。

請逐條回答：第一輪每一條（Codex 1～12、Antigravity 1～8）是「已修好／沒修好／修了但引入新問題」，附 檔案:行號。
再列出修正本身新引入的錯誤（最多 8 條，依嚴重度）。只談真的會出錯的，不談風格。繁體中文。最後一行寫「結論：可合併／需修正」。
