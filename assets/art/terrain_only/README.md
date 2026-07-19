# Terrain-only 城景底图

这里的成品只包含自然远景、时代色调和可建设地表。近景城墙、城门、栅栏、道路、建筑、旗帜及施工痕迹必须全部移除；它们由城防、道路和建筑状态实时渲染。

## 严格复用流程

1. 以对应 `city_<era>_terrain.png` 为唯一编辑目标，先按原始分辨率目视检查近景人工结构。
2. 使用内置 imagegen 的 `precise-object-edit`，只删除人工结构及其阴影；明确锁定构图、透视、远山、河流、植被、光照、纸纹和时代色调。
3. 删除区域必须按相邻自然地表重建。禁止用代码遮罩、纯色块、模糊层或裁切隐藏旧城防。
4. 不允许生成新的道路、围栏、房屋、人物、文字或 UI。成品需保持广阔、安静、可读的营造区域。
5. 将输出无损归一到源文件的精确宽高，逐张在 100% 尺寸检查接缝、重复纹理和残留阴影。
6. 只有通过人工检查的文件才能在 `manifest.json` 标为 `ready` 并加入 `TerrainOnlyCatalog.READY`；其余必须保留 `pending`。

## 标准提示词骨架

```text
Use case: precise-object-edit
Asset type: portrait mobile game terrain-only city background, <ERA>
Input images: Image 1 is the edit target and composition/style authority
Primary request: remove every fixed man-made defensive structure, road, gate,
tower, building, flag, fence and construction footprint. Reconstruct removed
areas as continuous natural terrain matching the adjacent buildable field.
Constraints: change only man-made structures and their shadows; preserve exact
composition, camera, natural scenery, palette, lighting, paper texture and empty
foreground. No new paths, structures, people, text, UI, logos or watermark.
```

春秋至清共十四个时代的地形底图均已按上述流程完成并逐张复核；各时代移除内容与保留景观记录在 `manifest.json`。
