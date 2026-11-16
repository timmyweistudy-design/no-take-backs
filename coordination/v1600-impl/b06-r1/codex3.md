 static func paper_white(lum: float, dis: bool, field: bool, gc: Vector2, faces: Array, fz: int) -> bool:
 	if lum <= 0.45 or dis or field:
 		return false
diff --git a/game/scripts/ui/map_art.gd b/game/scripts/ui/map_art.gd
index 38d06b3..1782e23 100644
--- a/game/scripts/ui/map_art.gd
+++ b/game/scripts/ui/map_art.gd

codex
1. [paper_tone.py:63](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/paper_tone.py:63)：降採樣後才比尺寸；1280×800 與 1279×799 會同形狀，漏擋尺寸不符。須先比原圖尺寸。

2. [dev_main.gd:152](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/dev_main.gd:152)：暗斑取樣不足會改取框外點，未維持紙面交集及低彩度限制，可能漏報；紙面模式應禁止此回退。

3. [dark_spot_diff.py:17](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/dark_spot_diff.py:17)：比對鍵未含位置；同頁同字在另一處新增暗斑，會被既有警告掩蓋。須納入位置。

結論：有條件
tokens used
56,925
1. [paper_tone.py:63](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/paper_tone.py:63)：降採樣後才比尺寸；1280×800 與 1279×799 會同形狀，漏擋尺寸不符。須先比原圖尺寸。

2. [dev_main.gd:152](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/dev_main.gd:152)：暗斑取樣不足會改取框外點，未維持紙面交集及低彩度限制，可能漏報；紙面模式應禁止此回退。

3. [dark_spot_diff.py:17](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/dark_spot_diff.py:17)：比對鍵未含位置；同頁同字在另一處新增暗斑，會被既有警告掩蓋。須納入位置。

結論：有條件
