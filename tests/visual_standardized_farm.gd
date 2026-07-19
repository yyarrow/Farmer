extends SceneTree

const CityLayout = preload("res://src/data/city_layout.gd")
const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("visual_standardized_farm requires a rendered display driver")
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
	state._configure_era("warring_states")
	state.chapter = 5
	state.current_day = 16
	state.next_attack_day = 22
	var types := ["farm", "woodcut", "quarry", "house", "market", "warehouse"]
	var instances := []
	for index in types.size():
		instances.append({
			"id": "pilot_%02d" % (index + 1),
			"type": types[index],
			"level": 5,
		})
	var arranged: Array = CityLayout.arrange_visual_layout(instances, 12)
	if arranged.size() != instances.size():
		failures.append("pilot layout dropped a building")
	state._normalize_building_instances(arranged)
	ui.current_tab = 0
	ui._update_tab_buttons()
	ui.city_visual_layer.set_standardized_art_pilot_enabled(true)
	ui._render_tab()
	state.changed.emit()
	await create_timer(0.45).timeout
	var farm_view: TextureRect = ui.city_visual_layer.building_views.get("pilot_01")
	_check(farm_view != null and farm_view.texture != null, "pilot farm has a rendered atlas frame")
	var farm_instance: Dictionary = state.get_building_instance("pilot_01")
	var layout: Dictionary = ui.city_visual_layer._layout_for_instance(farm_instance)
	var plot := CityLayout.footprint_polygon(CityLayout.instance_origin(farm_instance), "farm")
	var source_quad := FootprintTemplates.source_quad(Vector2i(3, 3))
	var frame_scale := Vector2(layout.art_size) / Vector2(FootprintTemplates.FRAME_SIZE)
	for corner in 4:
		var rendered_corner := Vector2(layout.art_rect.position) + source_quad[corner] * frame_scale
		_check(rendered_corner.distance_to(plot[corner]) <= 1.0, "pilot farm corner %d matches its logical plot" % corner)
	_save_frame("res://.qa/standardized_warring_farm_pilot.png")
	ui.city_visual_layer.set_debug_geometry_enabled(true)
	await process_frame
	_save_frame("res://.qa/standardized_warring_farm_pilot_debug.png")
	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("VISUAL_STANDARDIZED_FARM_OK buildings=6 size=540x960")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _save_frame(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.get_size() != Vector2i(540, 960):
		failures.append("invalid frame %s" % path)
	elif image.save_png(path) != OK:
		failures.append("cannot save %s" % path)
