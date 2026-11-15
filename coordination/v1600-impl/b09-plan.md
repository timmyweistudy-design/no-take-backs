# B09 圖集不卡（S7；P10.2、P10.3）

## 起點（1.5.0，同機：i7-12700H／RTX 3060 Laptop／Godot 4.6.2 Compatibility／Windows，1280×800）
`--perf`：圖集掃描烘焙最長幀 46.6 ms（歷史值重現）；分段：讀回最長 17.8 ms、上傳 5.8 ms、單段畫格（含等 GPU）190 ms；色盲重建 163 ms；戰鬥整幀 max 154／p99 101 ms。

## 做法
- 預設外觀離線包 `scripts/ui/atlas_pack.gd`：`--bake-pack` 烘預設塗裝 × 一般／色盲的全部 22 種（兵種條、轉身、待機、走路轉身、轉身出手、背面走路、腳底圈），存壓縮 Image 資源 `art/pack/cb{0,1}/*.res`（140 張、61.5 MiB），清冊記來源雜湊（畫法、姿勢、色票、後處理 shader、烘焙程式）、引擎、渲染路徑、格式、每張圖像素雜湊、自我核對（兵種條拼回整頁＝畫出來的頁）。
- 執行時 `sprite_cache._baked(key, 做法, 尺寸)`：預設塗裝＋包能用＝背景執行緒讀包（`load_threaded_request`），新兵種頁由兵種條在 WorkerThreadPool 拼頁，主執行緒只上傳；尺寸不對／讀失敗＝整包停用退回即時烘；特殊塗裝＝即時烘；開發環境來源改過＝包過期不用。
- 一頁 6 種 → 2 種（容量不變，`MAX_PAGES` 5→15）。
- 包不進 git（.gitignore）；`tools/export_check.sh` 匯出前一定重烘、成品自我檢查回報 `pack`；`NO_PACK=1` 可略。
- 量測：`--pack-bench`（冷＝開機到就緒，熱＝同程序 20 次重建；`--bench-blank` 只量烘焙、`--no-pack` 對照）；`LAYOUT_NOPACK=1`。

## 驗收（S7 判決）
最長幀 <40 ms（冷熱各 20、ABBA）、解碼像素差 0、來源變更／壞包錯命中 0、容量在預算內。
