extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state = root.get_node("State")
	_check(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "Android back is handled in game")
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
	ui.current_tab = 2
	state.enemy_army.scouted = false
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "军情不足") and not _has_label_containing(ui.content_box, "胜算约"), "unscouted military view does not leak exact forecast")
	state.enemy_army.scouted = true
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "胜算约") and _has_label_containing(ui.content_box, "预计伤亡"), "scouting unlocks exact battle forecast")
	state.enemy_army.scouted = false
	state.resources.grain = 12.0
	_check(ui._event_option_caption("drought", 1, "赈济").contains("粮-12石 民心-4"), "event button exposes stock-limited disaster outcome")
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
	ui._show_settings()
	await process_frame
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer == null, "back closes settings")
	_check(state.get_effective_time_speed() == 1.0, "back from settings restores selected speed")
	ui._show_settings()
	await process_frame
	ui._confirm_action("测试确认", "测试危险操作返回。", "确认", func(): pass)
	await process_frame
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer != null and _has_label(ui.modal_layer, "城邑设置"), "back cancels nested confirmation to settings")
	ui._close_settings()
	await process_frame
	ui._show_modal("强制决策", "需要明确选择。", [{"text": "处理", "callback": func(): pass}], ui.GOLD)
	await process_frame
	var compulsory_modal = ui.modal_layer
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer == compulsory_modal and is_instance_valid(compulsory_modal), "back cannot bypass compulsory decisions")
	ui._dismiss_modal()
	await process_frame
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer != null and _has_label(ui.modal_layer, "暂离青禾？"), "back on main opens save-and-exit confirmation")
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer == null, "back cancels exit confirmation")
	_check(state.get_effective_time_speed() == 1.0, "canceling exit restores selected speed")
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
	var level_signatures := {}
	for level in 6:
		state.buildings.farm = level
		visuals._refresh_buildings()
		var signature := "%d/%.2f/%s/%s" % [visuals.displayed_stages.farm, visuals.building_views.farm.scale.x, visuals.veteran_banners.farm.visible, visuals.master_banners.farm.visible]
		level_signatures[signature] = true
	_check(level_signatures.size() == 6, "all six building levels have distinct persistent appearances")
	state.buildings.farm = 3
	state.changed.emit()
	await process_frame
	_check(visuals.displayed_stages.farm == 2 and visuals.veteran_banners.farm.visible and not visuals.master_banners.farm.visible, "level three has distinct veteran appearance")
	_check(absf(float(visuals.building_views.farm.scale.x) - 1.02) < 0.001, "each building level has a distinct scale")
	state.buffs = {"farm_until": state.current_day + 2, "all_until": state.current_day + 2}
	state.units = {"militia": 35, "archer": 10, "chariot": 5}
	state.wounded = {"militia": 5, "archer": 0, "chariot": 0}
	state.enemy_army.scouted = true
	state.next_attack_day = state.current_day + 2
	visuals._refresh_buildings()
	_check(bool(visuals.world_state.irrigation) and bool(visuals.world_state.all_buff), "active production policies remain visible in the city")
	_check(int(visuals.world_state.soldier_markers) >= 3 and int(visuals.world_state.wounded_markers) == 1, "army and wounded state remain visible in the city")
	_check(bool(visuals.world_state.enemy_warning), "scouted or nearby enemy remains visible at the wall")
	visuals.effects.clear()
	visuals.play_event("policy", {"policy": "irrigate"})
	_check(_has_effect_kind(visuals.effects, "water"), "irrigation policy has specific water feedback")
	visuals.effects.clear()
	visuals.play_event("trade", {"trade": "sell_grain"})
	_check(_has_effect_velocity(visuals.effects, "caravan", -1), "selling sends caravans outward")
	visuals.effects.clear()
	visuals.play_event("trade", {"trade": "buy_grain"})
	_check(_has_effect_velocity(visuals.effects, "caravan", 1), "buying brings caravans inward")
	visuals.effects.clear()
	visuals.play_event("day", {"ledger": state.get_daily_ledger(), "recovered": 2})
	_check(_has_effect_text(visuals.effects, "2人归队"), "daily settlement reports recovered troops visually")
	visuals.effects.clear()
	visuals.play_event("event_choice", {"id": "merchant", "choice": 2})
	_check(not _has_effect_kind(visuals.effects, "caravan"), "declining a merchant does not show a false caravan journey")
	visuals.effects.clear()
	visuals.play_event("storage_full", {"resource": "grain"})
	_check(_has_effect_text(visuals.effects, "仓容不足"), "blocked full-storage trade has visible feedback")
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

func _has_label(parent: Node, text_value: String) -> bool:
	for node in parent.find_children("*", "Label", true, false):
		if node.text == text_value:
			return true
	return false

func _has_label_containing(parent: Node, text_value: String) -> bool:
	for node in parent.find_children("*", "Label", true, false):
		if str(node.text).contains(text_value):
			return true
	return false

func _has_effect_kind(effects: Array[Dictionary], kind: String) -> bool:
	for effect in effects:
		if str(effect.get("kind", "")) == kind:
			return true
	return false

func _has_effect_velocity(effects: Array[Dictionary], kind: String, direction: int) -> bool:
	for effect in effects:
		if str(effect.get("kind", "")) == kind and signf(float(effect.vel.x)) == float(direction):
			return true
	return false

func _has_effect_text(effects: Array[Dictionary], text_value: String) -> bool:
	for effect in effects:
		if str(effect.get("text", "")) == text_value:
			return true
	return false
