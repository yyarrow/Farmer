extends SceneTree

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const RoadNetwork = preload("res://src/city_placement/road_network.gd")
const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")
const DefenseVisuals = preload("res://src/city_defense_visuals.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	_check(DefenseLayout.MICRO_SCALE == RoadNetwork.MICRO_SCALE, "defense and roads share one micro-grid scale")
	_check(DefenseLayout.micro_cell_to_grid(Vector2i.ZERO) == Vector2(-0.25, -0.25), "micro cell zero has the canonical half-child offset")
	_check(DefenseLayout.micro_vertex_to_grid(Vector2i.ZERO) == Vector2(-0.5, -0.5), "outer vertex zero is half a macro cell outside")
	for cell in [Vector2i.ZERO, Vector2i(15, 22), Vector2i(29, 23), Vector2i(4, 2)]:
		_check(DefenseLayout.micro_cell_to_screen(cell) == RoadNetwork.micro_to_screen(cell), "defense cell %s exactly matches RoadNetwork" % cell)

	var expected_segments := {6: 80, 9: 96, 12: 104}
	for capacity in [6, 9, 12]:
		var region := DefenseLayout.micro_region(capacity)
		var gate: Dictionary = DefenseLayout.primary_gate(capacity)
		_check(region == RoadNetwork.micro_region(capacity), "%d-lot perimeter uses RoadNetwork's unlocked region" % capacity)
		_check(region.has_point(gate.road_root), "%d-lot gate root stays inside the road region" % capacity)
		_check(gate.road_root == RoadNetwork.default_gate(capacity), "%d-lot gate is the road network default root" % capacity)
		_check(gate.boundary_cell == gate.road_root, "%d-lot gate root occupies its open boundary cell" % capacity)
		_check(not region.has_point(gate.outside_cell), "%d-lot gate exposes an exterior continuation" % capacity)
		_check(DefenseLayout.wall_micro_cells(0, capacity).is_empty(), "%d-lot unbuilt defense is visually empty" % capacity)

		var road_cells := {}
		for cell in DefenseLayout.gate_road_micro_cells(capacity):
			road_cells[cell] = true
		for level in range(1, DefenseLayout.MAX_LEVEL + 1):
			var wall_cells := DefenseLayout.wall_micro_cells(level, capacity)
			_check(not wall_cells.is_empty(), "%d-lot wall level %d owns edge micro-cells" % [capacity, level])
			for cell in wall_cells:
				_check(not road_cells.has(cell), "%d-lot wall level %d never blocks the gate road" % [capacity, level])
			var segments := DefenseLayout.wall_segments(level, capacity)
			_check(segments.size() == int(expected_segments[capacity]), "%d-lot wall leaves one four-cell gate opening" % capacity)
			_check(segments.all(func(segment): return segment.has("sort_depth")), "%d-lot wall segments expose interleave depth" % capacity)
		_check(DefenseLayout.tower_nodes(1, capacity).is_empty(), "%d-lot first palisade has no premature towers" % capacity)
		_check(DefenseLayout.tower_nodes(2, capacity).size() == 2, "%d-lot level two marks two forward corners" % capacity)
		_check(DefenseLayout.tower_nodes(3, capacity).size() == 4, "%d-lot level three completes corner towers" % capacity)
		_check(DefenseLayout.tower_nodes(4, capacity).size() == 6, "%d-lot level four adds flank towers" % capacity)
		_check(DefenseLayout.tower_nodes(5, capacity).size() == 7, "%d-lot level five adds rear command tower" % capacity)
		var segments := DefenseLayout.wall_segments(5, capacity)
		var north_depths := segments.filter(func(segment): return segment.side == "north").map(func(segment): return int(segment.sort_depth))
		var south_depths := segments.filter(func(segment): return segment.side == "south").map(func(segment): return int(segment.sort_depth))
		_check(south_depths.max() > north_depths.max(), "%d-lot front wall sorts in front of the rear wall" % capacity)
		_validate_capacity(capacity)

	var gate_anchor := Vector2(240, 420)
	var standardized_gate := DefenseVisuals.standardized_gate_layout(3, gate_anchor)
	_check(standardized_gate.source_rect.position == Vector2(384, 384), "fourth atlas stage uses integer row one")
	_check(standardized_gate.frame_rect.position + standardized_gate.ground_socket == gate_anchor, "standardized 4x2 gate socket pins exactly to the perimeter")

	_check(not DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(2, 4), 6), "edge lots may touch the exterior defense shell")
	_check(DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(7, 9), 12), "ordinary building cannot block the full-city gate approach")
	_check(not DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(3, 4), 12), "interior ordinary building remains legal")

	var legacy := [
		{"id": "home", "type": "house", "level": 2, "grid_origin": [3, 4]},
		{"id": "old_wall", "type": "wall", "level": 4, "grid_origin": [0, 5]},
	]
	var migrated := DefenseLayout.split_legacy_wall_instances(legacy, 3)
	_check(int(migrated.defense_level) == 4, "legacy wall level becomes the perimeter defense level")
	_check(migrated.ordinary_instances.size() == 1, "legacy wall leaves the ordinary building list")
	_check(migrated.removed_wall_instance_ids == ["old_wall"], "migration reports the retired slot instance")
	_check(DefenseLayout.conflicting_instance_ids(legacy, 12).is_empty(), "legacy wall itself is not treated as an ordinary conflict")

	if failures.is_empty():
		print("CITY_DEFENSE_LAYOUT_OK capacities=6/9/12 gate12=%s" % DefenseLayout.primary_gate(12).road_root)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _validate_capacity(capacity: int) -> void:
	var types := ["farm", "woodcut", "quarry", "house", "market", "warehouse", "barracks", "farm", "house", "warehouse", "barracks", "market"]
	var raw := []
	for index in capacity:
		raw.append({"id": "ordinary_%02d" % index, "type": types[index], "level": 5})
	var arranged := DefenseLayout.arrange_ordinary(raw, capacity)
	_check(arranged.size() == capacity, "defense-aware solver preserves all %d ordinary building slots" % capacity)
	if arranged.size() != capacity:
		return
	for instance in arranged:
		_check(
			not DefenseLayout.ordinary_conflicts_with_defense(str(instance.type), PlacementEngine.instance_origin(instance), capacity),
			"%d-lot solver keeps %s outside the defense easement" % [capacity, instance.id]
		)
	var road := RoadNetwork.build(arranged, capacity, DefenseLayout.primary_gate(capacity).road_root)
	_check(bool(road.success), "%d ordinary buildings retain a gate-connected road network (%s)" % [capacity, road.code])

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
