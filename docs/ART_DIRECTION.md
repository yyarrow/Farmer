# 青禾邑美术方向

主场景使用内置图像生成工具制作，项目内成品位于 `assets/art/city_spring.png`。

最终提示词：

> Use case: historical-scene. Asset type: portrait mobile strategy game environment background. A beautiful healing ancient Chinese settlement during the Spring and Autumn / Warring States inspired era, designed as the main playable city view for a farming management and warfare strategy game. A small fortified riverside settlement among soft green mountains; fields and irrigation in the foreground; earthen walls, wooden watchtowers, tiled hall, granary, market and homes in the middle; misty mountains and peach trees in the distance. Premium hand-painted 2D mobile game background, Chinese mineral-pigment watercolor and delicate ink linework. Portrait 9:16, elevated three-quarter view, clear building plots, warm spring sunrise. Jade green, ochre, muted cinnabar and rice-paper cream. Period-inspired pre-imperial Chinese details only; no modern objects, European medieval elements, fantasy magic, text, logos or watermark.

界面遵循同一套玉青、赭石、朱砂、宣纸色板，图标和应用图标使用项目内可编辑的矢量图形。

## 建筑成长素材

八套建筑成长图通过内置图像生成工具逐套生成，再使用项目标准色键工具移除纯色背景。最终素材位于 `assets/art/buildings/*_stages.png`，包含农田、林场、石场、民居、市集、仓廪、兵营与城垣。

每套最终提示词使用同一结构，仅替换建筑和四阶段细节：

> Use case: stylized-concept. Asset type: 2D mobile strategy game building progression sprite sheet. Four clearly different growth stages of an ancient Chinese [BUILDING], ordered as an exact 2 by 2 grid: empty foundation, humble initial building, organized expanded compound, prosperous but historically grounded final compound. One isolated isometric three-quarter top-down sprite centered in each equal quadrant, with identical camera angle, ground footprint, scale, lighting and generous padding. Premium hand-painted 2D game sprite, Chinese mineral-pigment watercolor with delicate ink linework, matching a warm healing Spring and Autumn / Warring States inspired game. Perfectly flat solid #ff00ff chroma-key background with no shadows, gradients, texture, borders, labels or lighting variation. Crisp silhouettes; no readable text, visible people, modern objects, fantasy magic, logos or watermark.

各建筑第四阶段分别加入水车与金色谷物、成规模木料场、多层采石吊架、桃树庭院、市集商车、密封粮瓮、军鼓战车棚、烽火城楼等可辨识细节。所有最终透明素材均保存在工程内，色键源图位于忽略导出的 `assets/art/buildings/source/`。
