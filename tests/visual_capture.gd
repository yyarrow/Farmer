extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("visual_capture requires a rendered display driver")
		quit(1)
		return
	root.get_node("Audio").shutdown()
	var state = root.get_node("State")
	root.get_node("Telemetry").previous_unclean_exit = false
	state.reset_game()
	state.tutorial_seen = true
	for id in state.BUILDINGS:
		state.buildings[id] = 5
	var scene: PackedScene = load("res://main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	for capture in [[1, "spring"], [25, "autumn"], [37, "winter"]]:
		state.current_day = int(capture[0])
		state.next_attack_day = state.current_day + 6
		state.changed.emit()
		await create_timer(0.9).timeout
		var image := root.get_viewport().get_texture().get_image()
		if image.is_empty() or image.get_width() != 540 or image.get_height() != 960:
			failures.append("invalid %s frame" % capture[1])
			continue
		var path := "res://.qa/visual_%s_max.png" % capture[1]
		if image.save_png(path) != OK:
			failures.append("cannot save %s" % path)
	ui._handle_back_request()
	await create_timer(0.5).timeout
	var modal_image := root.get_viewport().get_texture().get_image()
	if modal_image.is_empty() or modal_image.get_width() != 540 or modal_image.get_height() != 960:
		failures.append("invalid exit confirmation frame")
	elif modal_image.save_png("res://.qa/visual_exit_confirm.png") != OK:
		failures.append("cannot save exit confirmation frame")
	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("VISUAL_CAPTURE_OK seasons=3 modals=1 size=540x960")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
