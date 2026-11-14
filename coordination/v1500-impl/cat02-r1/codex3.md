- **P2** [game_result.gd:320](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:320)：走勢頁裁切事實時仍只預留到底部 y=632，未扣除隨後 `_star_row` 的圖示與條件文字高度。殘局／試煉在 150% 字級、事實較多時，星級條件仍會壓到底列按鈕。須預留星級實際高度，或只在摘要頁顯示。

結論：有條件
