extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state = root.get_node("State")
	state.reset_game()
	state.tutorial_seen = true
	var scene: PackedScene = load("res://main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	_check(ui.theme != null and ui.theme.default_font != null, "bundled UI font is active")
	for glyph in "敌军稳定伤亡粮木石币":
		_check(ui.theme.default_font.has_char(glyph.unicode_at(0)), "bundled UI font covers %s" % glyph)
	var missing_glyphs := {}
	for file_name in DirAccess.get_files_at("res://src"):
		if not file_name.ends_with(".gd"):
			continue
		for glyph in FileAccess.get_file_as_string("res://src/" + file_name):
			var codepoint := glyph.unicode_at(0)
			if codepoint >= 128 and not ui.theme.default_font.has_char(codepoint):
				missing_glyphs[glyph] = true
	_check(missing_glyphs.is_empty(), "bundled UI font covers every source glyph: %s" % str(missing_glyphs.keys()))
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
	var settings_toggles: Array[Node] = ui.modal_layer.find_children("*", "CheckButton", true, false)
	_check(settings_toggles.size() == 3, "settings exposes mute, haptics and diagnostics toggles")
	for toggle in settings_toggles:
		_check(toggle.get_theme_color("font_pressed_color").is_equal_approx(ui.INK), "%s pressed text stays readable" % toggle.text)
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
	var visuals = ui.city_visual_layer
	_check(visuals.displayed_stages.farm == 3 and visuals.master_banners.farm.visible, "level five building has final art and master banner")
	state.buildings.farm = 3
	state.changed.emit()
	await process_frame
	_check(visuals.displayed_stages.farm == 2 and visuals.veteran_banners.farm.visible and not visuals.master_banners.farm.visible, "level three has distinct veteran appearance")
	_check(absf(float(visuals.building_views.farm.scale.x) - 1.02) < 0.001, "each building level has a distinct scale")
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
