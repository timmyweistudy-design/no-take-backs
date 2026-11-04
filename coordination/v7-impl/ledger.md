# SDD ledger — plan: docs/2026-11-04-grand-optimization-plan-v7.md
使用者 11/04 指令：照整合後順序全做到底、Next Fest 目標 2027-06。順序：第一批 → 第二批 → O2 其餘 → O3 → O4 → O5 → O6。
Ruling: 直接在 main 上做 — 這個 repo 全部 70 個 commit 都在 main、沒有 remote、使用者明說做到底 — 如果錯，用 tag v7-base 還原
Ruling: 引擎固定 4.6.2 — Windows exe、匯出模板、CI、文件都是 4.6.2，只有 WSL 的 headless 是 4.6 — 如果錯，改一行版本常數
Ruling: Linux 匯出驗證放到 CI 的 export job — 本機只有 Windows 模板，下載引擎二進位被自動權限擋下；export_check 明講 SKIPPED 不算通過 — 如果錯，CI 建好前 Linux 匯出沒人驗過
Ruling: 字型原檔重新取自 notofonts/noto-cjk（scratchpad/fonts）— 原本的 scratchpad 已清掉 — 新版子集的字形若有差異會出現在截圖
