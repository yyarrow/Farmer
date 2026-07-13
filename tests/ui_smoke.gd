extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("State")
	state.reset_game()
	state.tutorial_seen = true
	var scene: PackedScene = load("res://main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	_check(ui.content_box != null, "main content built")
	_check(ui.time_buttons.size() == 3 and ui.advance_day_button != null, "time controls built")
	state.set_time_speed(1.0)
	for tab in range(4):
		ui.current_tab = tab
		ui._update_tab_buttons()
		ui._render_tab()
		await process_frame
		_check(ui.content_box.get_child_count() > 0, "tab %d renders" % tab)
	ui._show_settings()
	await process_frame
	await process_frame
	_check(ui.modal_layer != null and is_instance_valid(ui.modal_layer), "settings modal opens")
	_check(ui.modal_layer.get_child_count() >= 2, "settings modal content")
	_check(state.time_speed == 1.0 and state.get_effective_time_speed() == 0.0, "settings temporarily pauses time")
	ui._close_settings()
	await process_frame
	_check(state.get_effective_time_speed() == 1.0, "closing settings restores selected speed")
	state.set_time_speed(0.0)
	for id in state.BUILDINGS:
		state.buildings[id] = 5
	state.changed.emit()
	state.visual_event.emit("chapter", {"chapter": 3})
	await process_frame
	await process_frame
	_check(state.get_prosperity() > 100, "city visuals accept max state")
	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("UI_SMOKE_OK tabs=4 settings=ok city_visuals=ok")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
