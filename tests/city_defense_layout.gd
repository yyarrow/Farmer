extends SceneTree

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	_check(DefenseLayout.MICRO_GRID_SIZE == Vector2i(30, 24), "defense uses a stable 2x micro-grid")
	_check(DefenseLayout.wall_micro_cells(0).is_empty(), "unbuilt defense has no invisible wall occupancy")
	var gate: Dictionary = DefenseLayout.primary_gate()
	_check(str(gate.id) == "south_gate", "primary gate identity is deterministic")
	_check(gate.road_root == Vector2i(15, 22), "road network receives a stable inner root")
	_check(gate.boundary_cell == Vector2i(15, 23), "gate root reaches the city boundary")
	_check(gate.outside_cell == Vector2i(15, 24), "gate exposes an exterior continuation")

	var road_cells := {}
	for cell in DefenseLayout.gate_road_micro_cells():
		road_cells[cell] = true
	for level in range(1, DefenseLayout.MAX_LEVEL + 1):
		var wall_cells := DefenseLayout.wall_micro_cells(level)
		_check(not wall_cells.is_empty(), "wall level %d owns edge micro-cells" % level)
		for cell in wall_cells:
			_check(not road_cells.has(cell), "wall level %d never blocks the gate road" % level)
		_check(DefenseLayout.wall_segments(level).size() == 104, "wall level %d leaves exactly a four-micro-cell gate opening" % level)

	_check(DefenseLayout.tower_nodes(1).is_empty(), "first palisade has no premature towers")
	_check(DefenseLayout.tower_nodes(2).size() == 2, "level two marks the two forward corners")
	_check(DefenseLayout.tower_nodes(3).size() == 4, "level three completes four corner towers")
	_check(DefenseLayout.tower_nodes(4).size() == 6, "level four adds flank towers")
	_check(DefenseLayout.tower_nodes(5).size() == 7, "level five adds a rear command tower")

	_check(DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(0, 4)), "ordinary building cannot occupy the wall easement")
	_check(DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(7, 9)), "ordinary building cannot block the gate approach")
	_check(not DefenseLayout.ordinary_conflicts_with_defense("house", Vector2i(3, 4)), "interior ordinary building remains legal")

	var legacy := [
		{"id": "home", "type": "house", "level": 2, "grid_origin": [3, 4]},
		{"id": "old_wall", "type": "wall", "level": 4, "grid_origin": [0, 5]},
	]
	var migrated := DefenseLayout.split_legacy_wall_instances(legacy, 3)
	_check(int(migrated.defense_level) == 4, "legacy wall level becomes the perimeter defense level")
	_check(migrated.ordinary_instances.size() == 1, "legacy wall leaves the ordinary building list")
	_check(migrated.removed_wall_instance_ids == ["old_wall"], "migration reports the retired slot instance")
	_check(DefenseLayout.conflicting_instance_ids(legacy).is_empty(), "legacy wall itself is not treated as an ordinary conflict")

	if failures.is_empty():
		print("CITY_DEFENSE_LAYOUT_OK levels=6 wall_segments=104 gate_root=%s" % gate.road_root)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
