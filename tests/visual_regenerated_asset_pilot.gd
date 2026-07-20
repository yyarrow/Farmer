extends SceneTree

const CityLayout = preload("res://src/data/city_layout.gd")
const ArtAlignment = preload("res://src/city_placement/art_alignment.gd")
const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("visual_regenerated_asset_pilot requires a rendered display driver")
		quit(1)
		return
	var era_id := _argument("era", "spring_autumn")
	var building_type := _argument("building", "farm")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.qa/building_standardization"))
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
	state._configure_era(era_id)
	state.chapter = 5
	state.current_day = 16
	state.next_attack_day = 22
	var instances := []
	for stage in 4:
		instances.append({"id": "pilot_%s_%d" % [building_type, stage], "type": building_type, "level": 1})
	var arranged: Array = CityLayout.arrange_visual_layout(instances, 12)
	_check(arranged.size() == instances.size(), "pilot keeps all stage samples")
	state._normalize_building_instances(arranged)
	ui.current_tab = 0
	ui._update_tab_buttons()
	ui._render_tab()
	state.changed.emit()
	await process_frame
	await process_frame
	for instance in state.get_building_instances():
		var stage := int(str(instance.id).get_slice("_", 2))
		_apply_standardized_view(ui.city_visual_layer, instance, stage, era_id)
	var stem := "%s_%s" % [era_id, building_type]
	await process_frame
	_save_frame("res://.qa/building_standardization/%s_city.png" % stem)
	ui.city_visual_layer.set_debug_geometry_enabled(true)
	await process_frame
	_save_frame("res://.qa/building_standardization/%s_city_debug.png" % stem)
	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("VISUAL_REGENERATED_ASSET_PILOT_OK era=%s building=%s stages=4 size=540x960" % [era_id, building_type])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _argument(key: String, fallback: String) -> String:
	var prefix := "--%s=" % key
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback

func _apply_standardized_view(city_visuals: Control, instance: Dictionary, stage: int, era_id: String) -> void:
	var instance_id := str(instance.id)
	var building_type := str(instance.type)
	var path := "res://assets/art/buildings/eras/%s/%s_stages_standardized.png" % [era_id, building_type]
	var texture: Texture2D = load(path)
	_check(texture != null, "%s atlas loads" % building_type)
	if texture == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2((stage % 2) * 384, int(stage / 2) * 384, 384, 384)
	var origin := CityLayout.instance_origin(instance)
	var footprint := CityLayout.footprint(building_type)
	var anchor := CityLayout.art_anchor(origin, building_type)
	var art_size := FootprintTemplates.frame_display_size(footprint)
	var source_socket := FootprintTemplates.source_socket(footprint)
	var alignment := ArtAlignment.frame_layout(texture, stage, art_size, anchor, source_socket)
	var button: Button = city_visuals.building_buttons[instance_id]
	var view: TextureRect = city_visuals.building_views[instance_id]
	var visible_rect := Rect2(alignment.visible_rect)
	button.position = visible_rect.position
	button.size = visible_rect.size
	button.z_index = 20 + CityLayout.depth(origin, building_type)
	view.texture = atlas
	view.size = art_size
	view.position = Vector2(alignment.frame_rect.position) - button.position
	view.pivot_offset = Vector2(alignment.ground_socket)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _save_frame(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.get_size() != Vector2i(540, 960):
		failures.append("invalid frame %s" % path)
	elif image.save_png(path) != OK:
		failures.append("cannot save %s" % path)
