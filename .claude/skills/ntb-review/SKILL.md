---
name: ntb-review
description: 落子無悔要三方審查（Codex 看程式、Antigravity 看美術與手感）時用；每批最多三輪
---
放在 `coordination/<批次>-rN/`，提示檔只給檔名與問題，回覆限字。
- Codex：`timeout 590 codex --ask-for-approval never exec -m gpt-6.1-sol -c model_reasoning_effort=medium --skip-git-repo-check --sandbox read-only - < prompt.md > codex.out.md 2> codex.err`；要上網加 `--search`。
- Antigravity：先把要看的檔案複製進子資料夾，`timeout 560 agy --model gemini-4-argon-medium --add-dir "$PWD" -p="$(cat prompt.md)" > ../google.out.md`。不能跑指令也不能寫檔，答案走 stdout；限 700～1200 字。圖先拼成接觸表。
- 兩邊都要求「最多 N 條必改、最後一行結論：可／有條件／不可」。
- 結論用程式查核（Antigravity 的美術說法、Codex 的行號）；不採納的寫進裁決紀錄。第三輪後的修正要標「未經複查」。
