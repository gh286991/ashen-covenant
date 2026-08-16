# Godot 模組化地下城編輯

請開啟 `levels/dungeon_grid_map.tscn`，在場景樹選取 `FloorGridMap`、`StructureGridMap`、`BoundaryGridMap` 或 `PropGridMap`。這是 Godot 的 `GridMap` 筆刷地圖，不是程式執行時產生的內容。

- `FloorGridMap`：快速鋪地板。
- `StructureGridMap`：鋪房間的上／下邊界與門洞。
- `BoundaryGridMap`：鋪房間的左／右邊界；它和 `StructureGridMap` 分層，避免 GridMap 四角互相覆蓋。
- `PropGridMap`：快速鋪柱子、祭壇與火盆。

選取其中一個 GridMap 後，在 3D 視窗底部的 GridMap 面板選取素材，再以滑鼠繪製、旋轉或擦除。日常編輯請使用這個場景；`dungeon_3d.tscn` 會直接使用它。

- `FloorBlocks`：一塊為 3.9m 方形地板；複製後用約 3.95m 間距排列。
- `Stone Floor - Tripo Cleaned`：由 Tripo GLB 清除外牆、封平底面後的 3.946m 方形石板；目前 `FloorGridMap` 的房間與走廊都使用這個項目。
- `Walls`：一段直牆；旋轉 Y 軸 90 度可改成側牆。名稱有 `Cutaway` 的項目為了俯視鏡頭而預設隱藏，可在 Inspector 開啟 `Visible` 觀看或使用。
- `Wall - User Stone`：由外部 GLB 對齊完整 3.946m 格子後匯入的直牆；牆中心線位於格子邊界，厚度跨過邊界，可與相鄰牆直接拼接。旋轉 Y 軸 90 度可改成另一方向的邊界牆。
- `Corners`：L 形轉角牆；可旋轉 Y 軸 0、90、180、270 度。
- `Doorways`：僅門洞模型。若需實際切換區域，也要在主場景 `Doors` 新增對應的 `Area3D` 觸發器與出生點。
- `Props`：柱子、祭壇、火盆；選取後 Ctrl+D 即可複製擺放。

每個基本單元都是獨立場景，位於 `levels/kit/`，可個別開啟並修改碰撞、尺寸資訊或材質。Blender 原始模組包在 `assets/dungeon_modular_kit.blend`，匯入後的 GLB 位於 `assets/3d_dungeon/kit/`。

`dungeon_3d.tscn` 的 `GridMapDungeon` 是這個筆刷地圖的實例。舊的 `Modules` 節點保留既有門流程與碰撞相容性，並設為不可見；不要刪除它，直到新地圖的門設計完成替換為止。
