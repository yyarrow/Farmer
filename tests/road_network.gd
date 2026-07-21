extends SceneTree

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const RoadNetwork = preload("res://src/city_placement/road_network.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	_check(RoadNetwork.MICRO_SCALE == 2, "road grid has exactly twice the macro-grid resolution")
	_check(
		RoadNetwork.micro_region(12).size == PlacementEngine.unlocked_region(12).size * 2,
		"unlocked macro region maps to micro cells without migrating placement coordinates"
	)
	_validate_micro_subdivision(Vector2i(4, 6))

	var placed := [
		{"id": "farm_a", "type": "farm", "grid_origin": [2, 1]},
		{"id": "house_a", "type": "house", "grid_origin": [10, 1]},
		{"id": "house_b", "type": "house", "grid_origin": [8, 3]},
		{"id": "market_a", "type": "market", "grid_origin": [2, 7]},
		{"id": "barracks_a", "type": "barracks", "grid_origin": [9, 6]},
	]
	var initial := RoadNetwork.build(placed, 12)
	_check(bool(initial.success), "placed buildings receive an automatic road network (%s: %s)" % [initial.code, initial.reason])
	if bool(initial.success):
		_validate_network(initial, placed, "initial placement")
	var injected_root := Vector2i(15, 0)
	var rooted_network := RoadNetwork.build(placed, 12, injected_root)
	_check(bool(rooted_network.success), "defense layout can inject a city-gate root micro-cell")
	if bool(rooted_network.success):
		_check(rooted_network.root == injected_root and rooted_network.gate == injected_root, "network exposes the injected root explicitly")
		_validate_network(rooted_network, placed, "injected gate placement")

	var reordered := placed.duplicate(true)
	reordered.reverse()
	var reordered_network := RoadNetwork.build(reordered, 12)
	_check(bool(reordered_network.success), "reordered input still routes (%s: %s)" % [reordered_network.code, reordered_network.reason])
	if bool(initial.success) and bool(reordered_network.success):
		_check(initial.road_cells == reordered_network.road_cells, "road result is independent of input order")
		_check(initial.connectivity_masks == reordered_network.connectivity_masks, "connectivity masks are deterministic")
		_check(initial.entrances == reordered_network.entrances, "entrance sockets are deterministic")

	var moved := placed.duplicate(true)
	moved[1].grid_origin = [12, 0]
	var moved_network := RoadNetwork.build(moved, 12)
	_check(bool(moved_network.success), "moving a building recomputes a valid route")
	if bool(initial.success) and bool(moved_network.success):
		_check(initial.entrances.house_a != moved_network.entrances.house_a, "moving updates the building entrance")
		_check(initial.road_cells != moved_network.road_cells, "moving derives a changed road layout")
		_validate_network(moved_network, moved, "moved placement")

	var removed := placed.duplicate(true)
	removed.remove_at(1)
	var removed_network := RoadNetwork.build(removed, 12)
	_check(bool(removed_network.success), "removing a building recomputes a valid route")
	if bool(removed_network.success):
		_check(not removed_network.entrances.has("house_a"), "removed buildings leave no serialized road residue")
		_validate_network(removed_network, removed, "removed placement")

	var arranged_twelve := [
		{"id": "building_00", "type": "farm", "grid_origin": [0, 0]},
		{"id": "building_01", "type": "woodcut", "grid_origin": [4, 0]},
		{"id": "building_02", "type": "quarry", "grid_origin": [0, 4]},
		{"id": "building_03", "type": "house", "grid_origin": [4, 3]},
		{"id": "building_04", "type": "market", "grid_origin": [0, 7]},
		{"id": "building_05", "type": "warehouse", "grid_origin": [4, 6]},
		{"id": "building_06", "type": "barracks", "grid_origin": [12, 0]},
		{"id": "building_07", "type": "wall", "grid_origin": [8, 1]},
		{"id": "building_08", "type": "farm", "grid_origin": [12, 4]},
		{"id": "building_09", "type": "house", "grid_origin": [9, 4]},
		{"id": "building_10", "type": "warehouse", "grid_origin": [8, 7]},
		{"id": "building_11", "type": "barracks", "grid_origin": [12, 8]},
	]
	var twelve_network := RoadNetwork.build(arranged_twelve, 12)
	_check(bool(twelve_network.success), "all twelve buildings connect to the gate (%s: %s)" % [twelve_network.code, twelve_network.reason])
	if bool(twelve_network.success):
		_check(twelve_network.entrances.size() == 12, "twelve-building network exposes twelve entrances")
		_validate_network(twelve_network, arranged_twelve, "twelve-building placement")
	var performance_started := Time.get_ticks_msec()
	for unused in 500:
		RoadNetwork.build(arranged_twelve, 12)
	var performance_ms := Time.get_ticks_msec() - performance_started
	_check(performance_ms < 4000, "automatic road rebuilding remains interactive (%d ms / 500)" % performance_ms)

	var access := RoadNetwork.evaluate_access(
		"house", Vector2i(2, 2),
		[{"id": "blocker", "type": "house", "grid_origin": [3, 4]}], 12
	)
	_check(not bool(access.accessible), "placement can reject a blocked building entrance")
	_check(str(access.code) == "entrance_blocked", "blocked entrance returns a stable machine-readable reason")

	var barrier := [
		{"id": "candidate", "type": "house", "grid_origin": [2, 1]},
		{"id": "barrier_0", "type": "wall", "grid_origin": [0, 5]},
		{"id": "barrier_1", "type": "wall", "grid_origin": [4, 5]},
		{"id": "barrier_2", "type": "wall", "grid_origin": [8, 5]},
		{"id": "barrier_3", "type": "market", "grid_origin": [12, 5]},
	]
	var unreachable := RoadNetwork.build(barrier, 12)
	_check(not bool(unreachable.success), "an enclosed entrance cannot silently create a road through buildings")
	_check(str(unreachable.code) == "unreachable", "unreachable placement returns a placement-consumable result")

	if failures.is_empty():
		print("ROAD_NETWORK_OK roads=%d buildings=12 masks=%d perf500=%dms" % [twelve_network.road_cells.size(), twelve_network.connectivity_masks.size(), performance_ms])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _validate_network(network: Dictionary, buildings: Array, label: String) -> void:
	var road_set := {}
	for cell in network.road_cells:
		road_set[cell] = true
	for raw in buildings:
		for occupied in RoadNetwork.footprint_cells(PlacementEngine.instance_origin(raw), str(raw.type)):
			_check(not road_set.has(occupied), "%s has no road through %s" % [label, raw.id])
		var entrance: Vector2i = network.entrances[str(raw.id)]
		_check(road_set.has(entrance), "%s connects %s entrance" % [label, raw.id])
		_check(_can_reach(entrance, network.gate, road_set), "%s gives %s a path to the gate" % [label, raw.id])
	for cell in network.road_cells:
		var expected := 0
		for index in RoadNetwork.DIRECTIONS.size():
			if road_set.has(cell + RoadNetwork.DIRECTIONS[index]):
				expected |= int(RoadNetwork.DIRECTION_MASKS[index])
		_check(int(network.connectivity_masks[cell]) == expected, "%s connectivity mask matches neighboring road cells" % label)

func _can_reach(start: Vector2i, goal: Vector2i, roads: Dictionary) -> bool:
	var pending: Array[Vector2i] = [start]
	var visited := {start: true}
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		if current == goal:
			return true
		for direction in RoadNetwork.DIRECTIONS:
			var next: Vector2i = current + direction
			if roads.has(next) and not visited.has(next):
				visited[next] = true
				pending.append(next)
	return false

func _validate_micro_subdivision(macro_cell: Vector2i) -> void:
	var macro_polygon := PlacementEngine.cell_polygon(macro_cell)
	var child_polygons: Array[PackedVector2Array] = []
	var all_points := PackedVector2Array()
	var center_sum := Vector2.ZERO
	for y in RoadNetwork.MICRO_SCALE:
		for x in RoadNetwork.MICRO_SCALE:
			var micro_cell := macro_cell * RoadNetwork.MICRO_SCALE + Vector2i(x, y)
			var polygon := RoadNetwork.micro_cell_polygon(micro_cell)
			child_polygons.append(polygon)
			center_sum += RoadNetwork.micro_to_screen(micro_cell)
			all_points.append_array(polygon)
	_check(
		center_sum / float(child_polygons.size()) == PlacementEngine.grid_to_screen(macro_cell),
		"four micro-cell centers balance exactly on the macro-cell center"
	)
	var child_area := 0.0
	for index in child_polygons.size():
		child_area += absf(_polygon_area(child_polygons[index]))
		for other_index in range(index + 1, child_polygons.size()):
			var overlap_area := 0.0
			for overlap in Geometry2D.intersect_polygons(child_polygons[index], child_polygons[other_index]):
				overlap_area += absf(_polygon_area(overlap))
			_check(is_zero_approx(overlap_area), "micro-cell polygons have no overlapping interior")
	var macro_area := absf(_polygon_area(macro_polygon))
	var hull_area := absf(_polygon_area(Geometry2D.convex_hull(all_points)))
	_check(is_equal_approx(child_area, macro_area), "four micro-cell areas exactly equal one macro cell")
	_check(is_equal_approx(hull_area, macro_area), "four micro-cell polygons leave no gap inside the macro diamond")
	for macro_corner in macro_polygon:
		var found := false
		for point in all_points:
			if point == macro_corner:
				found = true
				break
		_check(found, "micro-cell outer vertices preserve every macro-cell corner exactly")

func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		var next := (index + 1) % polygon.size()
		area += polygon[index].x * polygon[next].y - polygon[next].x * polygon[index].y
	return area * 0.5

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
