extends SceneTree

const CityLayout = preload("res://src/data/city_layout.gd")
const SaveValidator = preload("res://src/persistence/save_validator.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state := root.get_node("State")
	state.persistence_enabled = false
	state.reset_game()

	for y in CityLayout.GRID_SIZE.y:
		for x in CityLayout.GRID_SIZE.x:
			var cell := Vector2i(x, y)
			_check(CityLayout.screen_to_grid(CityLayout.grid_to_screen(cell)) == cell, "grid transform round-trips %s" % cell)
	_check(CityLayout.road_cells().size() == CityLayout.GRID_SIZE.y, "main avenue has one authoritative cell per row")
	_check(not CityLayout.can_place("house", Vector2i(CityLayout.ROAD_COLUMN, 3), [], 12), "building footprints cannot cover the avenue")
	_check(not CityLayout.can_place("farm", Vector2i(-1, 2), [], 12), "building footprints cannot leave the city grid")
	_check(CityLayout.unlocked_region(6).get_area() < CityLayout.unlocked_region(9).get_area(), "second city tier expands the buildable boundary")
	_check(CityLayout.unlocked_region(9).get_area() < CityLayout.unlocked_region(12).get_area(), "third city tier expands to the full buildable boundary")

	var showcase_types := ["farm", "woodcut", "quarry", "house", "market", "warehouse", "barracks", "wall", "farm", "house", "warehouse", "barracks"]
	for capacity in [6, 9, 12]:
		var placed := []
		for index in capacity:
			var building_type: String = showcase_types[index]
			var origin := CityLayout.first_open_origin(placed, capacity, building_type)
			_check(origin != CityLayout.INVALID_ORIGIN, "%d-building city finds a footprint for %s" % [capacity, building_type])
			_check(CityLayout.can_place(building_type, origin, placed, capacity), "%s footprint is in-bounds, off-road and non-overlapping" % building_type)
			placed.append({"id": "grid_%02d" % index, "type": building_type, "grid_origin": CityLayout.encode_origin(origin)})
		for instance in placed:
			for cell in CityLayout.occupied_cells(CityLayout.instance_origin(instance), str(instance.type)):
				_check(not CityLayout.is_road(cell), "placed footprint has zero road intersections")

	var farms := []
	for index in CityLayout.MAX_SLOTS:
		var origin := CityLayout.first_open_origin(farms, 12, "farm")
		_check(origin != CityLayout.INVALID_ORIGIN, "full city can pack twelve maximum-size farms")
		farms.append({"id": "farm_%02d" % index, "type": "farm", "grid_origin": CityLayout.encode_origin(origin)})

	var current: Dictionary = state.get_snapshot()
	_check(SaveValidator.is_valid(current, state._save_validation_context()), "v7 grid snapshot passes cross-field validation")
	var overlap: Dictionary = current.duplicate(true)
	if overlap.building_instances.size() >= 2:
		overlap.building_instances[1].grid_origin = overlap.building_instances[0].grid_origin.duplicate()
		overlap.building_instances[1].slot_id = overlap.building_instances[0].slot_id
		_check(not SaveValidator.is_valid(overlap, state._save_validation_context()), "overlapping saved footprints are rejected")
	var on_road: Dictionary = current.duplicate(true)
	on_road.building_instances[0].grid_origin = [CityLayout.ROAD_COLUMN, 3]
	on_road.building_instances[0].slot_id = CityLayout.cell_id(Vector2i(CityLayout.ROAD_COLUMN, 3))
	_check(not SaveValidator.is_valid(on_road, state._save_validation_context()), "road-crossing saved footprints are rejected")

	var v5: Dictionary = current.duplicate(true)
	v5.format_version = 5
	for index in v5.building_instances.size():
		v5.building_instances[index].erase("grid_origin")
		v5.building_instances[index].slot_id = "slot_%02d" % (index + 1)
	var migrated: Dictionary = state._upgrade_snapshot(v5)
	_check(int(migrated.format_version) == 7, "v5 sockets migrate to v7 repaired grid format")
	_check(SaveValidator.is_valid(migrated, state._save_validation_context()), "migrated grid snapshot remains valid")

	var v6: Dictionary = current.duplicate(true)
	v6.format_version = 6
	v6.city_level = 3
	v6.chapter = 3
	v6.population = 65
	var preserved_resources: Dictionary = v6.resources.duplicate(true)
	var preserved_units: Dictionary = v6.units.duplicate(true)
	var preserved_day := int(v6.current_day)
	for id in v6.buildings:
		v6.buildings[id] = 0
	v6.buildings.farm = 8
	v6.building_instances = []
	var broken_origins := [
		Vector2i(0, 1), Vector2i(3, 1), Vector2i(8, 1), Vector2i(11, 1),
		Vector2i(0, 4), Vector2i(3, 4), Vector2i(8, 4), Vector2i(11, 4),
	]
	for index in broken_origins.size():
		v6.building_instances.append({
			"id": "legacy_%02d" % index, "type": "farm", "level": 1,
			"grid_origin": CityLayout.encode_origin(broken_origins[index]),
			"slot_id": CityLayout.cell_id(broken_origins[index]),
		})
	var repaired_v6: Dictionary = state._upgrade_snapshot(v6)
	_check(SaveValidator.is_valid(repaired_v6, state._save_validation_context()), "already-damaged v6 autosave repairs into a valid v7 snapshot")
	_check(repaired_v6.resources == preserved_resources and repaired_v6.units == preserved_units and int(repaired_v6.current_day) == preserved_day, "v7 repair preserves resources, army and progression")
	for index in repaired_v6.building_instances.size():
		var repaired_instance: Dictionary = repaired_v6.building_instances[index]
		_check(str(repaired_instance.id) == "legacy_%02d" % index and int(repaired_instance.level) == 1, "v7 repair preserves building identity and level %d" % index)
	var repaired_rows := {}
	var repaired_sides := {}
	for instance in repaired_v6.building_instances:
		var origin := CityLayout.instance_origin(instance)
		repaired_rows[origin.y] = true
		repaired_sides["left" if origin.x < CityLayout.ROAD_COLUMN else "right"] = true
	_check(repaired_rows.size() >= 3 and repaired_sides.size() == 2, "v6 repair redistributes existing buildings across rows and both sides of the avenue")

	state.reset_game()
	if failures.is_empty():
		print("CITY_GRID_OK cells=%d road=%d capacity=%d" % [CityLayout.GRID_SIZE.x * CityLayout.GRID_SIZE.y, CityLayout.road_cells().size(), CityLayout.MAX_SLOTS])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
