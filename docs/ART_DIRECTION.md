# 青禾邑美术方向

十四个时代的主场景均使用内置图像生成工具制作。当前可交互版本使用 `assets/art/terrain_only/city_*_terrain_only.png` 纯地形骨架：只保留远景、自然地貌与时代气氛，不预绘道路、建筑、城墙或城门。道路和城防均由运行时布局派生，旧 `city_*_skeleton.png` 仅作美术参考，并从发行包排除。

最终提示词：

> Edit the supplied [ERA] city skeleton into a clean buildable terrain background. Preserve the exact portrait dimensions, elevated three-quarter camera, premium Chinese mineral-pigment watercolor style, distant landscape and era-specific atmosphere. Remove every building, field, lot, pad, marker, canal, curb, road, crossroads, wall, tower and gate from the playable ground. Heal the middle and foreground into one continuous broad packed-earth courtyard with only subtle sparse grass and natural texture, suitable for a programmatic 15 by 12 isometric placement grid. No text, UI, readable signs, modern objects, fantasy effects, logos or watermark.

界面遵循同一套玉青、赭石、朱砂、宣纸色板，图标和应用图标使用项目内可编辑的矢量图形。

## 建筑成长素材

十四个时代各有八套建筑成长图，通过内置图像生成工具以对应时代纯地形骨架作为首要构图与透视参考，再使用项目标准色键工具移除纯色背景。发行素材位于 `assets/art/buildings/eras/<时代>/*_stages_standardized.png`。全部 112 套图集统一为 384×384 阶段框、2×2/3×2/3×3/4×2 标准菱形占地、可见落地点和朝南入口；只允许等比缩放与平移，不允许横纵拉伸。城垣素材只供独立城防的城门与墙段表现，不再作为普通建筑占用槽位。

每套最终提示词使用同一结构，仅替换建筑和四阶段细节：

> Use case: stylized-concept. Asset type: 2D mobile strategy game building progression sprite sheet. Use the supplied [ERA] empty-city skeleton as the authoritative camera, ground-plane, palette and architectural reference. Four clearly different growth stages of an ancient Chinese [BUILDING], ordered as an exact 2 by 2 grid: empty foundation, humble initial building, organized expanded compound, prosperous but historically grounded final compound. One isolated elevated three-quarter sprite centered in each equal quadrant, with identical camera angle, ground footprint, scale, lighting and generous padding. Premium hand-painted 2D game sprite, Chinese mineral-pigment watercolor with delicate ink linework, historically grounded for [ERA]. Perfectly flat solid #ff00ff chroma-key background with no shadows, gradients, texture, borders, labels or lighting variation. Crisp silhouettes; no readable text, visible people, modern objects, fantasy magic, logos or watermark.

各建筑第四阶段分别加入水车与金色谷物、成规模木料场、多层采石吊架、桃树庭院、市集商车、密封粮瓮、军鼓战车棚、烽火城楼等可辨识细节。所有最终透明素材均保存在工程内，色键源图位于忽略导出的 `assets/art/buildings/source/`。

游戏内六个建筑等级复用四张手绘阶段，但不会出现无反馈升级：0/1/2/4 级切换主体图，3 级增加朱砂旗与占地成长，5 级再增加金旗并达到最大体量。建造与升级先覆盖脚手架，再以回弹动画揭示新外观并显示收益；每座建筑都有独立触控热区，可选中、移动或升级。春、夏、秋、冬使用不同的地图色调与花瓣、萤火、落叶、飞雪粒子。

城景还持续映射经营状态：水利生效时田间可见流渠，全邑增产时建筑出现金色工事光点，民居旁的人影、兵营列阵、伤营帐与城外敌旗分别随民口、军队、伤员和已侦察/临近敌军变化。持重、坚壁、雁行、锋矢会改变兵营旁的旗色和士卒队形，切换时另有军令浮字与列阵动效。日结会从田、林、石场与市集浮出真实净收支；买入与售出的商队方向相反，三项政令、巡剿胜负和不同事件选择也使用各自的水流、人群、军阵、商队或烟尘反馈。

`tests/visual_capture.gd` 使用真实渲染器输出存档启动首页、十二建筑满城、春秋冬季、“水利、军队、伤营、近敌、政令动效”组合状态、十四时代城景与军务页，以及最长事件、战报等弹窗的 540×960 画面到 `.qa/`。`tests/visual_city_slots.gd` 另为十四时代分别输出空城、六建筑和十二建筑三种密度，共 42 张验收图，并输出城门禁建、有效迁建、自动接路、独立城防、旧档修复、战国九座最高阶段普通图及几何调试图；调试图同时标示绿色逻辑占地、橙色院落安全带、蓝色最高等级贴图框、紫色可见素材框、朱色格子锚点与黄色素材接点，用于检查透视、贴地、拥挤、HUD遮挡与边缘巡视。`tests/art_alignment.gd` 另外逐帧验证十四时代×八建筑×四阶段共448帧的可见底边均落在对应格子锚点上。
