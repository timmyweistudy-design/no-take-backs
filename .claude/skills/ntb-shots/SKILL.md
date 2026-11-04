---
name: ntb-shots
description: 落子無悔要截圖、看版面或把畫面送審時用
---
1. `LAYOUT_QUICK=1 tools/layout_check.sh "<exe>" build/tmp/layout`：快速 2 組；里程碑才跑 6 組。
2. 結論看 `LAYOUT 截圖 N 張、違規 M`。違規明細在 `layout.jsonl`。
3. 版面檢查不懂美感：用 PIL 把多張拼成一張接觸表再看；英文 150% 一定要看。
4. 角色：`tools/atlas_check.gd`、動畫：`tools/anim_lint.py`。
