extends SceneTree

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const BuildingProfiles = preload("res://src/city_placement/building_profiles.gd")

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
