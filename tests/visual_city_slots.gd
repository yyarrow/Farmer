extends SceneTree

const EraRegistry = preload("res://src/data/era_registry.gd")

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
	ui._dismiss_modal()
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

	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("VISUAL_CITY_SLOTS_OK eras=%d densities=3 size=540x960" % EraRegistry.ORDER.size())
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
