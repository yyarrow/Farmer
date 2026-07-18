extends SceneTree

const EraRegistry = preload("res://src/data/era_registry.gd")
const CityLayout = preload("res://src/data/city_layout.gd")

var failures: Array[String] = []
var showcase_types := ["farm", "woodcut", "quarry", "house", "market", "warehouse", "barracks", "wall", "farm", "house", "warehouse", "barracks"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("visual_city_slots requires a rendered display driver")
		quit(1)
		return
	root.get_node("Audio").shutdown()
	root.get_node("Telemetry").previous_unclean_exit = false
	var state = root.get_node("State")
	state.reset_game()
	state.tutorial_seen = true
	var scene: PackedScene = load("res://main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	ui._finish_startup()
	ui.current_tab = 0
	ui._update_tab_buttons()

	for era_id in EraRegistry.ORDER:
		state._configure_era(era_id)
		state.chapter = 5
		for density in [0, 6, 12]:
			var instances := []
			for index in density:
				instances.append({
					"id": "visual_%02d" % (index + 1),
					"type": showcase_types[index],
					"level": 1 + (index % 3) * 2,
					"slot_id": "slot_%02d" % (index + 1),
				})
			state._normalize_building_instances(instances)
			ui._render_tab()
			state.changed.emit()
			await create_timer(0.35).timeout
			var image := root.get_viewport().get_texture().get_image()
			var suffix: String = {0: "empty", 6: "mid", 12: "full"}[density]
			var path := "res://.qa/slots_%s_%s.png" % [era_id, suffix]
			if image.is_empty() or image.get_width() != 540 or image.get_height() != 960:
				failures.append("invalid %s %s frame" % [era_id, suffix])
			elif image.save_png(path) != OK:
				failures.append("cannot save %s" % path)

	# Placement-mode acceptance frames: the drawn footprint uses the same road
	# and collision rules as the save validator.
	state._configure_era("tang")
	state.chapter = 5
	var placement_instances := []
	for index in 6:
		placement_instances.append({
			"id": "placement_%02d" % (index + 1),
			"type": showcase_types[index],
			"level": 3,
			"slot_id": "slot_%02d" % (index + 1),
		})
	state._normalize_building_instances(placement_instances)
	ui._render_tab()
	state.changed.emit()
	await process_frame
	var moving_id := "placement_01"
	ui.city_visual_layer.set_move_mode(moving_id)
	ui.city_visual_layer.hovered_cell = Vector2i(CityLayout.ROAD_COLUMN, 4)
	ui.city_visual_layer.queue_redraw()
	await process_frame
	_save_frame("res://.qa/grid_tang_road_blocked.png")
	var valid_origin := CityLayout.first_open_origin(state.get_building_instances(), 12, "farm", CityLayout.INVALID_ORIGIN, moving_id)
	ui.city_visual_layer.hovered_cell = valid_origin
	ui.city_visual_layer.queue_redraw()
	await process_frame
	_save_frame("res://.qa/grid_tang_valid.png")

	state._configure_era("spring_autumn")
	state.chapter = 3
	var broken_instances := []
	for index in 8:
		var building_type: String = showcase_types[index]
		var origin := CityLayout.first_open_origin(broken_instances, 12, building_type)
		broken_instances.append({
			"id": "migrated_%02d" % index, "type": building_type, "level": 2,
			"grid_origin": CityLayout.encode_origin(origin), "slot_id": CityLayout.cell_id(origin),
		})
	state._normalize_building_instances(CityLayout.repair_instance_layout(broken_instances, 12))
	ui.city_visual_layer.clear_move_mode()
	ui.city_visual_layer.set_selected("")
	ui._render_tab()
	state.changed.emit()
	await process_frame
	_save_frame("res://.qa/grid_migrated_eight.png")

	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("VISUAL_CITY_SLOTS_OK eras=%d densities=3 placement=2 migration=1 size=540x960" % EraRegistry.ORDER.size())
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _save_frame(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.get_width() != 540 or image.get_height() != 960:
		failures.append("invalid %s frame" % path)
	elif image.save_png(path) != OK:
		failures.append("cannot save %s" % path)
