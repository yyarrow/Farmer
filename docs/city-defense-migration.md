# 城防建筑化迁移约定

城防不再是普通城内建筑，而是城市边界上的独立、唯一、可升级基础设施。经济和战斗层继续使用 `buildings.wall` 的 0–5 等级，因此不需要改变既有数值平衡。

## 存档迁移

1. 以 `max(buildings.wall, wall 实例的 level)` 作为新城防等级。
2. 从 `building_instances` 删除 `type == "wall"` 的旧实例；保留其等级，不保留位置。
3. 城防不再占用 6/9/12 个普通建筑容量之一。迁移释放的槽位可供玩家营造普通建筑。
4. 普通建筑若挡住城门通道，使用 `arrange_ordinary()` 重新排布；城墙位于城域外圈，不吞占边缘普通地块。
5. 存档只保存城防等级。墙段、塔段、城门和道路根节点均由 `DefenseLayout` 确定性重建。

`DefenseLayout.split_legacy_wall_instances()` 提供第 1–2 步的纯函数结果，最终应在下一次存档格式升级中调用。

## 道路接口

所有边界 API 均接收 6/9/12 的 `unlocked_count`，随城池扩建确定性重建外圈。`DefenseLayout.primary_gate(unlocked_count)` 的 `road_root` 与 `RoadNetwork.default_gate()` 完全相同，`boundary_cell` 是城内门洞微格，`outside_cell` 为未来世界地图道路预留。道路可以穿过门洞，但不得占用城域外的 `wall_micro_cells()`；普通建筑不得占用 `reserved_ordinary_cells()` 返回的城门通道。

## 视觉分层

背景只保留远山、河流、自然地貌和无人工道路的可建设地表。墙段和塔段携带独立的 `sort_depth`，生产渲染必须按深度与普通建筑穿插；不能把整圈城防固定放在所有建筑之下：

`terrain-only 背景 → 自动道路 → 按深度交错的城防/普通建筑 → 人物与特效`

标准化城门使用 4×2 `FootprintTemplates` 的 `source_socket` 贴到门洞锚点；旧素材才通过 `ArtAlignment` 测量接地点。四阶段 atlas 行号必须使用整数除法。

城防 0 级完全不可见；1 级木栅；2 级土垒和前角望楼；3 级连续墙体和四角楼；4 级强化城门与侧塔；5 级完整堡垒边界。具体名称和材质由时代配置覆盖，几何与门洞位置保持不变。
