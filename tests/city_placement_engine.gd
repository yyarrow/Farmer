extends SceneTree

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const BuildingProfiles = preload("res://src/city_placement/building_profiles.gd")
const PlacementSolver = preload("res://src/city_placement/placement_solver.gd")
const CityViewTransform = preload("res://src/city_placement/city_view_transform.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var anchor := PlacementEngine.art_anchor(Vector2i(4, 4), "house")
	var first_level := BuildingProfiles.render_rect(anchor, "house", 1)
	var maximum_level := BuildingProfiles.maximum_render_rect(anchor, "house")
	_check(maximum_level.encloses(first_level), "maximum-stage envelope reserves every lower building level")

	var crowded := [
		{"id": "farm", "type": "farm", "grid_origin": [8, 1]},
		{"id": "quarry", "type": "quarry", "grid_origin": [11, 1]},
		{"id": "market", "type": "market", "grid_origin": [11, 4]},
		{"id": "barracks", "type": "barracks", "grid_origin": [4, 4]},
	]
	for instance in crowded:
		_check(PlacementEngine.can_place(str(instance.type), PlacementEngine.instance_origin(instance), crowded.filter(func(other): return other != instance), 9), "fixture remains logically grid-valid")
	var crowded_metrics := PlacementEngine.layout_visual_metrics(crowded)
	_check(int(crowded_metrics.conflicts) > 0 or float(crowded_metrics.max_overlap) > 0.18, "visual engine detects the grid-valid crowding visible in player saves")

	var separated := [
		{"id": "wall", "type": "wall", "grid_origin": [0, 5]},
		{"id": "farm", "type": "farm", "grid_origin": [9, 4]},
	]
	var separated_metrics := PlacementEngine.layout_visual_metrics(separated)
	_check(int(separated_metrics.conflicts) == 0, "visually separated buildings have no base-envelope conflicts")
	_check(float(separated_metrics.outside) < 0.05, "separated buildings remain inside the city HUD-safe rectangle")
	_check(is_equal_approx(CityViewTransform.scale_for_capacity(6, 1.16), 1.0), "six-building settlement keeps the full city in view")
	_check(is_equal_approx(CityViewTransform.scale_for_capacity(9, 1.16), 1.04), "nine-building city adds restrained horizontal inspection")
	_check(is_equal_approx(CityViewTransform.scale_for_capacity(12, 1.16), 1.08), "twelve-building city expands without the old 1.16 edge clipping")

	var showcase_types := ["farm", "woodcut", "quarry", "house", "market", "warehouse", "barracks", "wall", "farm", "house", "warehouse", "barracks"]
	for capacity in [6, 9, 12]:
		var raw := []
		for index in capacity:
			raw.append({"id": "solver_%02d" % index, "type": showcase_types[index], "level": 5})
		var arranged := PlacementSolver.arrange(raw, capacity)
		_check(arranged.size() == capacity, "solver arranges all %d buildings without dropping an instance" % capacity)
		if arranged.size() == capacity:
			var metrics := PlacementEngine.layout_visual_metrics(arranged)
			_check(int(metrics.conflicts) == 0, "%d-building solver layout has no base-envelope conflict" % capacity)
			_check(float(metrics.outside) < 0.08, "%d-building solver layout stays clear of HUD and city edges" % capacity)
			_check(PlacementEngine.road_cells().is_empty(), "%d-building geometry reserves no fixed avenue" % capacity)

	if failures.is_empty():
		print("CITY_PLACEMENT_ENGINE_OK profiles=%d crowded_conflicts=%d" % [BuildingProfiles.PROFILES.size(), int(crowded_metrics.conflicts)])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
