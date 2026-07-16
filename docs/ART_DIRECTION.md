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

游戏内六个建筑等级复用四张手绘阶段，但不会出现无反馈升级：0/1/2/4 级切换主体图，3 级增加朱砂旗与占地成长，5 级再增加金旗并达到最大体量。春、夏、秋、冬使用不同的地图色调与花瓣、萤火、落叶、飞雪粒子；不会改变建筑坐标或触控热区。

城景还持续映射经营状态：水利生效时田间可见流渠，全邑增产时建筑出现金色工事光点，民居旁的人影、兵营列阵、伤营帐与城外敌旗分别随民口、军队、伤员和已侦察/临近敌军变化。持重、坚壁、雁行、锋矢会改变兵营旁的旗色和士卒队形，切换时另有军令浮字与列阵动效。日结会从田、林、石场与市集浮出真实净收支；买入与售出的商队方向相反，三项政令、巡剿胜负和不同事件选择也使用各自的水流、人群、军阵、商队或烟尘反馈。

`tests/visual_capture.gd` 使用真实渲染器输出春、秋、冬、“水利、军队、伤营、近敌、政令动效”组合状态、侦察前后与不同阵令的军务页，以及最长事件、战报等弹窗的 540×960 画面到 `.qa/`，用于检查地图构图、建筑遮挡、季节色调、情报边界、状态反馈和文字布局。
