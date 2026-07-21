extends SceneTree

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const RoadNetwork = preload("res://src/city_placement/road_network.gd")
const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")
const DefenseVisuals = preload("res://src/city_defense_visuals.gd")
const DefensePrimitive = preload("res://src/city_defense_primitive.gd")
const CityViewTransform = preload("res://src/city_placement/city_view_transform.gd")

var failures: Array[String] = []
var south_overlap_pairs := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	_check(DefenseLayout.MICRO_SCALE == RoadNetwork.MICRO_SCALE, "defense and roads share one micro-grid scale")
	_check(DefenseLayout.micro_cell_to_grid(Vector2i.ZERO) == Vector2(-0.25, -0.25), "micro cell zero has the canonical half-child offset")
	_check(DefenseLayout.micro_vertex_to_grid(Vector2i.ZERO) == Vector2(-0.5, -0.5), "outer vertex zero is half a macro cell outside")
	for cell in [Vector2i.ZERO, Vector2i(15, 22), Vector2i(29, 23), Vector2i(4, 2)]:
		_check(DefenseLayout.micro_cell_to_screen(cell) == RoadNetwork.micro_to_screen(cell), "defense cell %s exactly matches RoadNetwork" % cell)
	for building_type in PlacementEngine.BUILDING_FOOTPRINTS:
		if building_type == "wall":
			continue
		var origin := Vector2i(4, 3)
		var contact := PlacementEngine.front_contact_grid(origin, building_type)
		_check(
			PlacementEngine.grid_point_to_screen(contact) == PlacementEngine.art_anchor(origin, building_type),
			"%s z-depth contact is the real front art socket" % building_type
		)
		_check(
			PlacementEngine.depth(origin, building_type) == PlacementEngine.depth_at_grid_point(contact),
			"%s depth is derived from its front contact" % building_type
		)
		var size := PlacementEngine.footprint(building_type)
		var legacy_depth := (origin.x + size.x + origin.y + size.y) * 10 + origin.x
		_check(
			legacy_depth - PlacementEngine.depth(origin, building_type) in [7, 8, 9],
			"%s removes the legacy +7..9 depth drift" % building_type
		)

	var expected_segments := {6: 88, 9: 104, 12: 112}
	for capacity in [6, 9, 12]:
		var region := DefenseLayout.micro_region(capacity)
		var perimeter := DefenseLayout.perimeter_region(capacity)
		var gate: Dictionary = DefenseLayout.primary_gate(capacity)
		_check(region == RoadNetwork.micro_region(capacity), "%d-lot perimeter uses RoadNetwork's unlocked region" % capacity)
		_check(perimeter.position == region.position - Vector2i.ONE, "%d-lot wall expands one micro cell beyond the road grid" % capacity)
		_check(perimeter.end == region.end + Vector2i.ONE, "%d-lot expanded wall is symmetric on all four sides" % capacity)
		_check(region.has_point(gate.road_root), "%d-lot gate root stays inside the road region" % capacity)
		_check(gate.road_root == RoadNetwork.default_gate(capacity), "%d-lot gate is the road network default root" % capacity)
		_check(gate.boundary_cell == gate.road_root, "%d-lot gate root occupies its interior boundary cell" % capacity)
		_check(not region.has_point(gate.outside_cell), "%d-lot gate exposes an exterior continuation" % capacity)
		_check(gate.outside_cell == perimeter.end, "%d-lot gate anchor is the isometric front vertex" % capacity)
		_check(gate.layer == DefenseLayout.LAYER_FOREGROUND, "%d-lot gate explicitly belongs to the foreground layer" % capacity)
		var approach: Array = gate.approach_cells
		_check(approach == [gate.road_root + Vector2i.RIGHT, gate.road_root + Vector2i.RIGHT + Vector2i.DOWN], "%d-lot road bends through two micro cells to the front gate" % capacity)
		var root_polygon := RoadNetwork.micro_cell_polygon(gate.road_root)
		var approach_polygon := RoadNetwork.micro_cell_polygon(approach[0])
		var final_polygon := RoadNetwork.micro_cell_polygon(approach[1])
		_check(root_polygon[1] == approach_polygon[0] and root_polygon[2] == approach_polygon[3], "%d-lot interior road and first approach share an exact edge" % capacity)
		_check(approach_polygon[2] == final_polygon[1] and approach_polygon[3] == final_polygon[0], "%d-lot two approach cells share an exact edge" % capacity)
		_check(final_polygon[2] == gate.screen_anchor, "%d-lot exterior approach lands exactly on the gate socket" % capacity)
		_check(DefenseLayout.wall_micro_cells(0, capacity).is_empty(), "%d-lot unbuilt defense is visually empty" % capacity)

		var road_cells := {}
		for cell in DefenseLayout.gate_road_micro_cells(capacity):
			road_cells[cell] = true
		var clearance := DefenseLayout.defense_clearance_micro_cells(capacity)
		_check(not clearance.is_empty(), "%d-lot defense owns an inner micro-grid safety ribbon" % capacity)
		_check(clearance.all(func(cell): return perimeter.has_point(cell) and not region.has_point(cell)), "%d-lot safety ribbon lies between the road grid and expanded wall" % capacity)
		for macro_cell in DefenseLayout.reserved_ordinary_cells(capacity):
			_check(PlacementEngine.unlocked_region(capacity).has_point(macro_cell), "%d-lot reserved building cell stays in the unlocked city" % capacity)
		for level in range(1, DefenseLayout.MAX_LEVEL + 1):
			var wall_cells := DefenseLayout.wall_micro_cells(level, capacity)
			_check(not wall_cells.is_empty(), "%d-lot wall level %d owns edge micro-cells" % [capacity, level])
			for cell in wall_cells:
				_check(not road_cells.has(cell), "%d-lot wall level %d never blocks the gate road" % [capacity, level])
			var segments := DefenseLayout.wall_segments(level, capacity)
			_check(segments.size() == int(expected_segments[capacity]), "%d-lot converging front walls leave one four-cell gate opening" % capacity)
			_check(not segments.filter(func(segment): return segment.side == "east").any(func(segment): return segment.from.y >= perimeter.end.y - DefenseLayout.GATE_WIDTH / 2), "%d-lot east wall stops at the gate opening" % capacity)
			_check(not segments.filter(func(segment): return segment.side == "south").any(func(segment): return segment.from.x > perimeter.end.x - DefenseLayout.GATE_WIDTH / 2), "%d-lot south wall stops at the gate opening" % capacity)
			_check(segments.all(func(segment): return segment.has("sort_depth")), "%d-lot wall segments expose interleave depth" % capacity)
		_check(DefenseLayout.tower_nodes(1, capacity).is_empty(), "%d-lot first palisade has no premature towers" % capacity)
		_check(DefenseLayout.tower_nodes(2, capacity).size() == 2, "%d-lot level two marks two forward corners" % capacity)
		_check(DefenseLayout.tower_nodes(3, capacity).size() == 4, "%d-lot level three completes corner towers" % capacity)
		_check(DefenseLayout.tower_nodes(4, capacity).size() == 6, "%d-lot level four adds flank towers" % capacity)
		_check(DefenseLayout.tower_nodes(5, capacity).size() == 7, "%d-lot level five adds rear command tower" % capacity)
		var segments := DefenseLayout.wall_segments(5, capacity)
		var north_depths := segments.filter(func(segment): return segment.side == "north").map(func(segment): return int(segment.sort_depth))
		var south_depths := segments.filter(func(segment): return segment.side == "south").map(func(segment): return int(segment.sort_depth))
		_check(segments.filter(func(segment): return segment.side == "north").all(func(segment): return segment.layer == DefenseLayout.LAYER_BACKGROUND), "%d-lot north wall is explicitly background" % capacity)
		_check(segments.filter(func(segment): return segment.side == "south").all(func(segment): return segment.layer == DefenseLayout.LAYER_FOREGROUND), "%d-lot south wall is explicitly foreground" % capacity)
		_check(segments.filter(func(segment): return segment.side in ["east", "west"]).all(func(segment): return segment.layer == DefenseLayout.LAYER_DEPTH), "%d-lot side walls retain contact-point depth sorting" % capacity)
		_check(south_depths.max() > north_depths.max(), "%d-lot front wall sorts in front of the rear wall" % capacity)
		_validate_capacity(capacity)

	var gate_anchor := Vector2(240, 420)
	var standardized_gate := DefenseVisuals.standardized_gate_layout(3, gate_anchor)
	_check(standardized_gate.source_rect.position == Vector2(384, 384), "fourth atlas stage uses integer row one")
	_check(DefenseVisuals.GATE_SOURCE_SOCKET.x == DefenseVisuals.FRAME_SIZE.x * 0.5, "gate passage socket stays on the atlas centreline")
	_check(standardized_gate.frame_rect.position + standardized_gate.ground_socket == gate_anchor, "standardized 4x2 gate socket pins exactly to the perimeter")
	var defense_visual := DefenseVisuals.new()
	defense_visual.configure(5, "warring_states", {}, 12)
	var primitive_depths := defense_visual.get_children().map(func(child): return int(child.z_index))
	_check(defense_visual.get_child_count() == expected_segments[12] + 7 + 1, "production defense creates one depth-sorted primitive per segment, tower and gate")
	_check(primitive_depths.max() > primitive_depths.min(), "production defense interleaves rear and front primitives by city depth")
	var background_primitives := defense_visual.get_children().filter(func(child): return child.semantic_layer == DefenseLayout.LAYER_BACKGROUND)
	var foreground_primitives := defense_visual.get_children().filter(func(child): return child.semantic_layer == DefenseLayout.LAYER_FOREGROUND)
	_check(not background_primitives.is_empty() and background_primitives.all(func(child): return child.z_index == DefenseLayout.BACKGROUND_Z), "production rear wall stays above terrain at the explicit background z")
	_check(not foreground_primitives.is_empty() and foreground_primitives.all(func(child): return child.z_index >= DefenseLayout.FOREGROUND_Z_BASE), "production south wall and gate use the explicit foreground layer")
	var defense_bounds := defense_visual.visual_bounds()
	var content_bounds := Rect2(0, 0, CityViewTransform.CANVAS_SIZE.x, 1).merge(defense_bounds)
	var pan_bounds := CityViewTransform.horizontal_bounds(540.0, 1.08, content_bounds)
	print("DEFENSE_CANVAS_METRICS bounds=", defense_bounds, " pan=", pan_bounds)
	_check(defense_bounds.position.x * 1.08 + pan_bounds.y >= -0.01, "rightmost pan reveals the expanded defense's left edge without clipping")
	_check(defense_bounds.end.x * 1.08 + pan_bounds.x <= 540.01, "leftmost pan reveals the expanded defense's right edge without clipping")
	_check(CityViewTransform.CANVAS_SIZE.x >= defense_bounds.end.x, "terrain canvas covers the expanded defense at maximum tier")
	defense_visual.free()

	_check(not DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(2, 4), 6), "expanded shell preserves edge lots and full city capacity")
	_check(DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(13, 10), 12), "ordinary building cannot block the full-city gate approach")
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
		print("CITY_DEFENSE_LAYOUT_OK capacities=6/9/12 gate12=%s south_overlaps=%d" % [DefenseLayout.primary_gate(12).road_root, south_overlap_pairs])
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
		var footprint_micro := RoadNetwork.footprint_cells(
			PlacementEngine.instance_origin(instance), str(instance.type)
		)
		for safety_cell in DefenseLayout.defense_clearance_micro_cells(capacity):
			_check(not footprint_micro.has(safety_cell), "%d-lot %s never enters the wall setback" % [capacity, instance.id])
	var road := RoadNetwork.build(arranged, capacity, DefenseLayout.primary_gate(capacity).road_root)
	_check(bool(road.success), "%d ordinary buildings retain a gate-connected road network (%s)" % [capacity, road.code])
	_validate_wall_occlusion(arranged, capacity)

func _validate_wall_occlusion(arranged: Array, capacity: int) -> void:
	var building_depths := []
	var south_overlaps := 0
	var north_overlaps := 0
	var south_buildings := {}
	for instance in arranged:
		var building_type := str(instance.type)
		var origin := PlacementEngine.instance_origin(instance)
		var building_depth := 20 + PlacementEngine.depth(origin, building_type)
		building_depths.append(building_depth)
		var building_rect := PlacementEngine.visual_rect(origin, building_type, 5)
		for segment in DefenseLayout.wall_segments(5, capacity):
			var wall_rect := DefensePrimitive.segment_render_bounds(segment, int(DefenseLayout.level_style(5).wall_tier))
			if not building_rect.intersects(wall_rect):
				continue
			if segment.side == "south":
				south_overlaps += 1
				south_buildings[str(instance.id)] = true
				_check(int(segment.sort_depth) > building_depth, "%d-lot south wall occludes overlapping %s" % [capacity, instance.id])
			elif segment.side == "north":
				north_overlaps += 1
				_check(int(segment.sort_depth) < building_depth, "%d-lot north wall stays behind overlapping %s" % [capacity, instance.id])
	var side_depths := DefenseLayout.wall_segments(5, capacity) \
		.filter(func(segment): return segment.side in ["east", "west"]) \
		.map(func(segment): return int(segment.sort_depth))
	_check(side_depths.min() < building_depths.max() and side_depths.max() > building_depths.min(), "%d-lot side walls interleave across building contact depths" % capacity)
	if capacity == 12:
		south_overlap_pairs = south_overlaps
		print("DEFENSE_OCCLUSION_METRICS south_pairs=", south_overlaps, " south_buildings=", south_buildings.size(), " north_pairs=", north_overlaps)
		_check(south_overlaps > 0, "twelve-lot fixture exercises real south-wall/building geometry overlap")
		_check(south_buildings.size() <= 7, "expanded twelve-lot perimeter does not increase the seven-building south-wall baseline")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
