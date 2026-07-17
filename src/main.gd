extends Control

const UiFont = preload("res://src/ui_font.gd")
const LicenseNotice = preload("res://src/license_notice.gd")
const CityLayout = preload("res://src/data/city_layout.gd")
const UiComponents = preload("res://src/ui/component_factory.gd")
const UiPresentation = preload("res://src/ui/presentation_formatter.gd")
const OpeningAdvisor = preload("res://src/ui/opening_advisor.gd")
const INK := UiComponents.INK
const INK_SOFT := UiComponents.INK_SOFT
const PAPER := UiComponents.PAPER
const PAPER_DARK := UiComponents.PAPER_DARK
const JADE := UiComponents.JADE
const JADE_LIGHT := UiComponents.JADE_LIGHT
const CINNABAR := UiComponents.CINNABAR
const GOLD := UiComponents.GOLD
const SHADOW := UiComponents.SHADOW
const RESOURCE_META := UiPresentation.RESOURCE_META

var resource_labels := {}
var tab_buttons: Array[Button] = []
var time_buttons := {}
var current_tab := 0
var title_label: Label
var day_label: Label
var population_label: Label
var threat_label: Label
var power_label: Label
var threat_bar: ProgressBar
var day_bar: ProgressBar
var advance_day_button: Button
var content_scroll: ScrollContainer
var content_box: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var modal_layer: Control
var _modal_back_action: Callable
var _toast_tween: Tween
var city_world: Control
var city_background: TextureRect
var city_visual_layer: Control
var city_pan_hint: Label
var _displayed_season := ""
var _displayed_era := ""
var _displayed_city_scale := 0.0
var _city_pan_x := 0.0
var _selected_building_instance := ""
var _selected_building_slot := ""
var _moving_building_instance := ""

func _ready() -> void:
	theme = UiFont.make_theme()
	_build_scene()
	State.changed.connect(_refresh_dynamic)
	State.notice.connect(_show_toast)
	State.event_started.connect(_on_event_started)
	State.battle_finished.connect(_on_battle_finished)
	State.visual_event.connect(_on_state_visual_event)
	State.time_state_changed.connect(_refresh_dynamic)
	Telemetry.unexpected_exit_detected.connect(_show_toast)
	_refresh_dynamic()
	_render_tab()
	if not State.offline_report.is_empty():
		call_deferred("_show_toast", State.offline_report)
	if not State.tutorial_seen:
		call_deferred("_show_tutorial")
	elif not State.current_event.is_empty():
		call_deferred("_on_event_started", State.current_event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()

func _unhandled_input(event: InputEvent) -> void:
	if State.get_city_view_scale() <= 1.001 or modal_layer:
		return
	var drag_delta := 0.0
	var pointer_y := -1.0
	if event is InputEventScreenDrag:
		drag_delta = event.relative.x
		pointer_y = event.position.y
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		drag_delta = event.relative.x
		pointer_y = event.position.y
	if is_zero_approx(drag_delta) or pointer_y < 184.0 or pointer_y > 525.0:
		return
	_city_pan_x += drag_delta
	_apply_city_view(false)
	get_viewport().set_input_as_handled()

func _handle_back_request() -> void:
	if modal_layer and is_instance_valid(modal_layer):
		if _modal_back_action.is_valid():
			_modal_back_action.call()
		else:
			# Tutorial, event and battle decisions must be resolved explicitly.
			_play_chime(440.0)
		return
	_show_exit_confirmation()

func _dismiss_modal() -> void:
	if modal_layer and is_instance_valid(modal_layer):
		modal_layer.queue_free()
	modal_layer = null
	_modal_back_action = Callable()
	State.set_modal_paused(false)

func _show_exit_confirmation() -> void:
	var exit_game := func():
		State.save_game()
		get_tree().quit()
	_show_modal(
		"暂离青禾？",
		"当前进度会在退出前立即保存，下次仍从此刻继续。",
		[
			{"text": "继续经营", "callback": func(): pass},
			{"text": "保存并退出", "callback": exit_game},
		],
		JADE,
		_dismiss_modal
	)

func _build_scene() -> void:
	city_world = Control.new()
	city_world.name = "CityWorld"
	city_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(city_world)

	city_background = TextureRect.new()
	city_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_background.texture = load("res://assets/art/city_spring.png")
	city_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	city_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	city_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_world.add_child(city_background)

	var warm_wash := ColorRect.new()
	warm_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm_wash.color = Color(0.96, 0.82, 0.48, 0.055)
	warm_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_world.add_child(warm_wash)

	var ambient := Node2D.new()
	ambient.set_script(load("res://src/ambient_layer.gd"))
	ambient.z_index = 1
	city_world.add_child(ambient)

	city_visual_layer = Control.new()
	city_visual_layer.name = "CityVisuals"
	city_visual_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_visual_layer.set_script(load("res://src/city_visuals.gd"))
	city_visual_layer.z_index = 2
	city_world.add_child(city_visual_layer)
	city_visual_layer.building_selected.connect(_on_city_building_selected)
	city_visual_layer.slot_selected.connect(_on_city_slot_selected)

	_build_top_panel()
	_build_city_pan_hint()
	_build_threat_strip()
	_build_bottom_panel()
	_build_toast()

func _build_top_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_left = 14.0
	panel.offset_top = 18.0
	panel.offset_right = -14.0
	panel.offset_bottom = 184.0
	panel.add_theme_stylebox_override("panel", _style(Color(0.965, 0.91, 0.76, 0.94), 18, 1, Color(0.47, 0.38, 0.23, 0.35), 13))
	panel.z_index = 10
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 7)
	panel.add_child(outer)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	outer.add_child(heading)

	var seal := Label.new()
	seal.text = "禾"
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.custom_minimum_size = Vector2(38, 38)
	seal.add_theme_font_size_override("font_size", 21)
	seal.add_theme_color_override("font_color", Color.WHITE)
	seal.add_theme_stylebox_override("normal", _style(CINNABAR, 9, 0, Color.TRANSPARENT, 2))
	heading.add_child(seal)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", -3)
	heading.add_child(title_stack)

	title_label = Label.new()
	title_label.text = "青禾邑"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", INK)
	title_stack.add_child(title_label)

	population_label = Label.new()
	population_label.add_theme_font_size_override("font_size", 12)
	population_label.add_theme_color_override("font_color", INK_SOFT)
	title_stack.add_child(population_label)

	var settings_button := Button.new()
	settings_button.text = "调"
	settings_button.tooltip_text = "声音、存档与诊断"
	settings_button.custom_minimum_size = Vector2(38, 38)
	settings_button.add_theme_font_size_override("font_size", 16)
	settings_button.add_theme_color_override("font_color", INK)
	settings_button.add_theme_stylebox_override("normal", _style(Color(0.33, 0.42, 0.32, 0.12), 10, 1, Color(0.34, 0.36, 0.25, 0.18), 4))
	settings_button.add_theme_stylebox_override("pressed", _style(JADE, 10, 0, Color.TRANSPARENT, 4))
	settings_button.pressed.connect(func():
		_play_chime()
		_show_settings()
	)
	heading.add_child(settings_button)

	var day_stack := VBoxContainer.new()
	day_stack.custom_minimum_size.x = 92
	heading.add_child(day_stack)
	day_label = Label.new()
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_label.add_theme_font_size_override("font_size", 14)
	day_label.add_theme_color_override("font_color", CINNABAR)
	day_stack.add_child(day_label)
	day_bar = ProgressBar.new()
	day_bar.show_percentage = false
	day_bar.custom_minimum_size = Vector2(86, 6)
	day_bar.add_theme_stylebox_override("background", _style(Color(0.36, 0.31, 0.22, 0.14), 3))
	day_bar.add_theme_stylebox_override("fill", _style(GOLD, 3))
	day_stack.add_child(day_bar)

	var time_row := HBoxContainer.new()
	time_row.custom_minimum_size.y = 30
	time_row.add_theme_constant_override("separation", 5)
	outer.add_child(time_row)
	var time_caption := Label.new()
	time_caption.text = "时序"
	time_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_caption.custom_minimum_size.x = 38
	time_caption.add_theme_font_size_override("font_size", 12)
	time_caption.add_theme_color_override("font_color", INK_SOFT)
	time_row.add_child(time_caption)
	for spec in [[0.0, "停"], [1.0, "1×"], [2.0, "2×"]]:
		var speed: float = spec[0]
		var time_button := Button.new()
		time_button.text = spec[1]
		time_button.toggle_mode = true
		time_button.custom_minimum_size = Vector2(46, 30)
		time_button.add_theme_font_size_override("font_size", 12)
		time_button.add_theme_color_override("font_color", INK)
		time_button.add_theme_color_override("font_pressed_color", Color.WHITE)
		time_button.add_theme_color_override("font_hover_color", INK)
		time_button.add_theme_stylebox_override("normal", _style(Color(0.36, 0.37, 0.27, 0.11), 8, 0, Color.TRANSPARENT, 3))
		time_button.add_theme_stylebox_override("pressed", _style(JADE, 8, 0, Color.TRANSPARENT, 3))
		time_button.pressed.connect(func():
			_play_chime()
			State.set_time_speed(speed)
		)
		time_row.add_child(time_button)
		time_buttons[speed] = time_button
	advance_day_button = Button.new()
	advance_day_button.text = "推进一日"
	advance_day_button.tooltip_text = "暂停时结算到下一日"
	advance_day_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advance_day_button.add_theme_font_size_override("font_size", 12)
	advance_day_button.add_theme_color_override("font_color", INK)
	advance_day_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	advance_day_button.add_theme_color_override("font_disabled_color", INK_SOFT)
	advance_day_button.add_theme_stylebox_override("normal", _style(Color(GOLD, 0.16), 8, 1, Color(GOLD, 0.26), 3))
	advance_day_button.add_theme_stylebox_override("pressed", _style(GOLD, 8, 0, Color.TRANSPARENT, 3))
	advance_day_button.pressed.connect(func():
		_play_chime()
		State.advance_one_day()
	)
	time_row.add_child(advance_day_button)

	var resources_grid := GridContainer.new()
	resources_grid.columns = 4
	resources_grid.add_theme_constant_override("h_separation", 6)
	outer.add_child(resources_grid)
	for id in ["grain", "wood", "stone", "coins"]:
		var pill := Label.new()
		pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pill.custom_minimum_size = Vector2(0, 35)
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.add_theme_font_size_override("font_size", 11)
		pill.add_theme_constant_override("line_spacing", -2)
		pill.add_theme_color_override("font_color", INK)
		pill.add_theme_stylebox_override("normal", _style(Color(1.0, 0.97, 0.86, 0.74), 10, 1, Color(0.38, 0.42, 0.29, 0.18), 6))
		resources_grid.add_child(pill)
		resource_labels[id] = pill

func _on_city_building_selected(instance_id: String) -> void:
	if State.get_building_instance(instance_id).is_empty():
		return
	_selected_building_instance = instance_id
	_selected_building_slot = ""
	_moving_building_instance = ""
	city_visual_layer.set_selected(instance_id)
	current_tab = 0
	_update_tab_buttons()
	content_scroll.scroll_vertical = 0
	_render_tab()
	var instance := State.get_building_instance(instance_id)
	Telemetry.track("building_instance_selected", {"instance_id": instance_id, "building": instance.type, "slot": instance.slot_id})

func _clear_building_selection() -> void:
	_selected_building_instance = ""
	_selected_building_slot = ""
	_moving_building_instance = ""
	if city_visual_layer:
		city_visual_layer.clear_move_mode()
		city_visual_layer.set_selected("")

func _on_city_slot_selected(slot_id: String) -> void:
	if not _moving_building_instance.is_empty():
		var moved_id := _moving_building_instance
		if State.move_building_instance(moved_id, slot_id):
			_moving_building_instance = ""
			_selected_building_instance = moved_id
			_selected_building_slot = ""
			city_visual_layer.clear_move_mode()
			city_visual_layer.set_selected(moved_id)
			_show_toast("建筑已迁至新用地")
			_render_tab()
		return
	_selected_building_instance = ""
	_selected_building_slot = slot_id
	city_visual_layer.set_selected("")
	current_tab = 0
	_update_tab_buttons()
	content_scroll.scroll_vertical = 0
	_render_tab()
	Telemetry.track("building_slot_selected", {"slot": slot_id, "city_level": State.chapter})

func _build_city_pan_hint() -> void:
	city_pan_hint = Label.new()
	city_pan_hint.anchor_left = 0.5
	city_pan_hint.anchor_right = 0.5
	city_pan_hint.anchor_top = 0.525
	city_pan_hint.anchor_bottom = 0.525
	city_pan_hint.offset_left = -92
	city_pan_hint.offset_right = 92
	city_pan_hint.offset_bottom = 24
	city_pan_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	city_pan_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	city_pan_hint.add_theme_font_size_override("font_size", 10)
	city_pan_hint.add_theme_color_override("font_color", Color("#f8e8bb"))
	city_pan_hint.add_theme_stylebox_override("normal", _style(Color(0.10, 0.14, 0.11, 0.72), 10, 1, Color(GOLD, 0.24), 3))
	city_pan_hint.z_index = 9
	city_pan_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(city_pan_hint)

func _build_threat_strip() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.03
	panel.anchor_right = 0.97
	panel.anchor_top = 0.555
	panel.anchor_bottom = 0.555
	panel.offset_top = -4
	panel.offset_bottom = 63
	panel.add_theme_stylebox_override("panel", _style(Color(0.13, 0.17, 0.13, 0.90), 16, 1, Color(0.92, 0.77, 0.43, 0.34), 11))
	panel.z_index = 12
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	panel.add_child(row)

	var beacon := Label.new()
	beacon.text = "烽"
	beacon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beacon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	beacon.custom_minimum_size = Vector2(42, 42)
	beacon.add_theme_font_size_override("font_size", 19)
	beacon.add_theme_color_override("font_color", Color("#f7d88d"))
	beacon.add_theme_stylebox_override("normal", _style(Color(0.64, 0.25, 0.20, 0.92), 21))
	row.add_child(beacon)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 3)
	row.add_child(stack)
	threat_label = Label.new()
	threat_label.add_theme_font_size_override("font_size", 14)
	threat_label.add_theme_color_override("font_color", Color("#f8e8bb"))
	stack.add_child(threat_label)
	threat_bar = ProgressBar.new()
	threat_bar.show_percentage = false
	threat_bar.max_value = 100
	threat_bar.custom_minimum_size.y = 7
	threat_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), 4))
	threat_bar.add_theme_stylebox_override("fill", _style(CINNABAR, 4))
	stack.add_child(threat_bar)

	power_label = Label.new()
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_label.custom_minimum_size.x = 118
	power_label.add_theme_font_size_override("font_size", 12)
	power_label.add_theme_color_override("font_color", Color("#e8d8ad"))
	row.add_child(power_label)

func _build_bottom_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_top = 0.635
	panel.add_theme_stylebox_override("panel", _style(Color(0.955, 0.90, 0.76, 0.985), 24, 1, Color(0.40, 0.31, 0.18, 0.28), 12))
	panel.z_index = 11
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	panel.add_child(layout)

	var handle := ColorRect.new()
	handle.color = Color(0.37, 0.33, 0.23, 0.25)
	handle.custom_minimum_size = Vector2(52, 3)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(handle)

	var tabs := HBoxContainer.new()
	tabs.custom_minimum_size.y = 44
	tabs.add_theme_constant_override("separation", 5)
	layout.add_child(tabs)
	for data in [["build_tab", "城建", "筑"], ["trade_tab", "市易", "易"], ["military_tab", "军务", "戈"], ["governance_tab", "政事", "策"]]:
		var index := tab_buttons.size()
		var tab := Button.new()
		tab.text = "%s  %s" % [data[2], State.term(data[0], data[1])]
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 14)
		tab.add_theme_stylebox_override("normal", _style(Color(0.36, 0.37, 0.27, 0.11), 11, 0, Color.TRANSPARENT, 4))
		tab.add_theme_stylebox_override("hover", _style(Color(0.36, 0.47, 0.35, 0.19), 11, 0, Color.TRANSPARENT, 4))
		tab.add_theme_stylebox_override("pressed", _style(JADE, 11, 0, Color.TRANSPARENT, 4))
		tab.pressed.connect(func():
			_play_chime(520.0 + index * 45.0)
			current_tab = index
			Telemetry.track("tab_opened", {"tab": data[0], "index": index})
			_update_tab_buttons()
			content_scroll.scroll_vertical = 0
			_render_tab()
		)
		tabs.add_child(tab)
		tab_buttons.append(tab)

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.scroll_deadzone = 10
	content_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	layout.add_child(content_scroll)
	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content_box)

	var footer := Label.new()
	footer.text = "离线收益已开启  ·  每十秒自动存档"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.31, 0.33, 0.27, 0.60))
	layout.add_child(footer)
	_update_tab_buttons()

func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.08
	toast_panel.anchor_right = 0.92
	toast_panel.anchor_top = 0.485
	toast_panel.anchor_bottom = 0.485
	toast_panel.offset_bottom = 48
	toast_panel.add_theme_stylebox_override("panel", _style(Color(0.10, 0.14, 0.11, 0.94), 15, 1, Color(0.93, 0.80, 0.49, 0.36), 12))
	toast_panel.z_index = 300
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_panel)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_color_override("font_color", Color("#f7e7bb"))
	toast_panel.add_child(toast_label)

func _play_chime(_frequency := 520.0) -> void:
	Audio.play_sfx("ui_tap")
	if OS.has_feature("mobile") and bool(Audio.settings.get("haptics", true)):
		Input.vibrate_handheld(18)

func _refresh_dynamic() -> void:
	var ledger := State.get_daily_ledger()
	for id in resource_labels:
		var meta: Dictionary = _resource_meta(id)
		resource_labels[id].text = "%s %d%s\n%+.1f/日" % [meta.glyph, floori(State.resources[id]), meta.unit, float(ledger[id].net)]
	title_label.text = "青禾邑 · %s·%s" % [State.get_era_name(), State.get_city_level_name()]
	population_label.text = "%d户 · 民%d · 军%d · 心%d" % [State.get_households(), State.population, State.get_army_count(), roundi(State.morale)]
	var time_text := "停" if State.get_effective_time_speed() <= 0.0 else "%d×" % roundi(State.get_effective_time_speed())
	var calendar := State.get_calendar()
	day_label.text = "%d年·%s%d日·%s" % [calendar.year, calendar.season_name, calendar.day, time_text]
	_apply_season_tone(str(calendar.season))
	_apply_city_view()
	day_bar.value = State.day_progress * 100.0
	for speed in time_buttons:
		time_buttons[speed].button_pressed = is_equal_approx(float(speed), State.time_speed)
	advance_day_button.disabled = State.time_speed > 0.0 or State.modal_paused or not State.current_event.is_empty()
	var enemy := State.get_enemy_display()
	threat_label.text = "%s · %d日后抵城" % [enemy.name, State.days_until_attack()]
	threat_bar.max_value = 7
	threat_bar.value = 7 - clampi(State.days_until_attack(), 0, 7)
	power_label.text = "%s %d / 敌军 %s\n%s" % [State.term("army", "守军"), State.get_army_power(), str(State.get_enemy_power()) if enemy.known else "未明", enemy.range]
	_update_tab_buttons()

func _resource_meta(id: String) -> Dictionary:
	var source: Dictionary = State.RESOURCE_UNITS.get(id, RESOURCE_META.get(id, {}))
	return {
		"name": source.get("short", source.get("name", id)),
		"glyph": source.get("glyph", id.left(1)),
		"unit": source.get("unit", ""),
	}

func _apply_city_view(recenter_on_change := true) -> void:
	if not city_world:
		return
	var view_scale := State.get_city_view_scale()
	var viewport_width := size.x if size.x > 1.0 else 540.0
	var min_x := viewport_width - viewport_width * view_scale
	if recenter_on_change and not is_equal_approx(_displayed_city_scale, view_scale):
		_displayed_city_scale = view_scale
		_city_pan_x = min_x * 0.5
	_city_pan_x = clampf(_city_pan_x, min_x, 0.0)
	city_world.scale = Vector2.ONE * view_scale
	city_world.position = Vector2(_city_pan_x, 184.0 * (1.0 - view_scale))
	city_pan_hint.visible = view_scale > 1.001
	city_pan_hint.text = "左 · %s · 右" % State.get_city_map_hint()

func _apply_season_tone(season: String) -> void:
	if (season == _displayed_season and State.era_id == _displayed_era) or not city_background:
		return
	var era_changed := State.era_id != _displayed_era
	_displayed_season = season
	_displayed_era = State.era_id
	if era_changed:
		var background_path := State.get_city_background_path()
		if ResourceLoader.exists(background_path):
			city_background.texture = load(background_path)
	Audio.set_music_season(season)
	var tones := {
		"spring": Color(1.0, 1.0, 1.0),
		"summer": Color(0.90, 1.0, 0.88),
		"autumn": Color(1.0, 0.88, 0.72),
		"winter": Color(0.82, 0.91, 1.0),
	}
	var tween := get_tree().create_tween()
	tween.tween_property(city_background, "modulate", tones.get(season, Color.WHITE) * State.get_era_tint(), 0.8)

func _update_tab_buttons() -> void:
	var tab_specs := [["build_tab", "城建", "筑"], ["trade_tab", "市易", "易"], ["military_tab", "军务", "戈"], ["governance_tab", "政事", "策"]]
	for i in tab_buttons.size():
		var tab := tab_buttons[i]
		tab.text = "%s  %s" % [tab_specs[i][2], State.term(tab_specs[i][0], tab_specs[i][1])]
		tab.button_pressed = i == current_tab
		tab.add_theme_color_override("font_color", Color.WHITE if i == current_tab else INK)
		tab.add_theme_stylebox_override("normal", _style(JADE if i == current_tab else Color(0.36, 0.37, 0.27, 0.11), 11, 0, Color.TRANSPARENT, 4))

func _render_tab() -> void:
	for child in content_box.get_children():
		child.queue_free()
	_add_opening_guidance()
	match current_tab:
		0: _render_buildings()
		1: _render_market()
		2: _render_military()
		3: _render_governance()
	_allow_content_scroll_gestures(content_box)

func _allow_content_scroll_gestures(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in control.get_children():
		if child is Control:
			_allow_content_scroll_gestures(child)

func _opening_guidance() -> Dictionary:
	return OpeningAdvisor.guidance(State)

func _add_opening_guidance() -> void:
	var advice := _opening_guidance()
	if advice.is_empty():
		return
	var card := _card(86)
	card.add_theme_stylebox_override("panel", _style(Color(0.98, 0.94, 0.79, 0.96), 14, 1, Color(GOLD, 0.58), 9))
	content_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)
	row.add_child(_glyph_badge("策", GOLD))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 2)
	row.add_child(stack)
	var title := Label.new()
	title.text = str(advice.title)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", INK)
	stack.add_child(title)
	var detail := Label.new()
	detail.text = str(advice.detail)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var target_tab := int(advice.tab)
	var action := _action_button("已在此页" if target_tab == current_tab else str(advice.action))
	action.custom_minimum_size = Vector2(76, 42)
	action.disabled = target_tab == current_tab
	action.pressed.connect(func():
		current_tab = target_tab
		Telemetry.track("opening_advice_followed", {"step": advice.step, "tab": target_tab, "day": State.current_day})
		_update_tab_buttons()
		content_scroll.scroll_vertical = 0
		_render_tab()
	)
	row.add_child(action)

func _on_state_visual_event(kind: String, _payload: Dictionary) -> void:
	# Page cards contain day-sensitive forecasts, wounded counts and policy gains.
	# Rebuild only at settlement boundaries; the ScrollContainer keeps its position.
	if kind == "day" and content_box:
		_render_tab()

func _render_buildings() -> void:
	_add_section_heading("营造城邑", "直接点选城中建筑或空地；城池扩建会逐步开放十二处用地")
	content_box.add_child(_info_banner(
		"%s · 建筑用地 %d / %d" % [State.get_city_level_name(), State.get_built_building_count(), State.get_building_slot_count()],
		"尚余%d处空地 · 同类建筑可重复营造，城垣仅限一处" % State.get_open_building_slots(),
		JADE if State.get_open_building_slots() > 0 else GOLD
	))
	if not _moving_building_instance.is_empty():
		content_box.add_child(_info_banner("迁建中", "请在城景中点选一处绿色空地；原建筑等级与产能不会损失", GOLD))
		var cancel_move := _action_button("取消迁建")
		cancel_move.pressed.connect(func():
			_moving_building_instance = ""
			city_visual_layer.clear_move_mode()
			_render_tab()
		)
		content_box.add_child(cancel_move)
		return
	if not _selected_building_instance.is_empty():
		var instance := State.get_building_instance(_selected_building_instance)
		if not instance.is_empty():
			_add_building_inspector(instance)
			return
		_selected_building_instance = ""
	if not _selected_building_slot.is_empty() and State.get_building_at_slot(_selected_building_slot).is_empty():
		_add_building_catalog(_selected_building_slot)
		return
	_selected_building_slot = ""
	content_box.add_child(_info_banner("城景即是建造界面", "点建筑查看独立等级、升级与迁建；点“＋空地”选择要营造的建筑", JADE))

func _add_building_inspector(instance: Dictionary) -> void:
	var id := str(instance.type)
	var data: Dictionary = State.BUILDINGS[id]
	var level := int(instance.level)
	var cost := State.building_instance_cost(str(instance.id))
	var card := _card(154)
	content_box.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	card.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stack.add_child(row)
	row.add_child(_glyph_badge(data.glyph, JADE))
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 2)
	row.add_child(text_stack)
	var name_label := Label.new()
	name_label.text = "%s · %s阶" % [data.name, _cn_number(level)]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", INK)
	text_stack.add_child(name_label)
	var desc := Label.new()
	desc.text = data.desc + "\n" + _format_building_effect(State.get_building_effect_preview(id, str(instance.id)))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", INK_SOFT)
	text_stack.add_child(desc)
	if level < int(data.max):
		stack.add_child(_building_cost_row(cost))
	else:
		var completed := Label.new()
		completed.text = "已臻最高阶 · 城景装饰与旗帜已全部显现"
		completed.add_theme_color_override("font_color", GOLD)
		completed.add_theme_font_size_override("font_size", 11)
		stack.add_child(completed)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	stack.add_child(actions)
	var action := _action_button("已满阶" if level >= int(data.max) else State.term("upgrade_action", "升级"))
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.disabled = level >= int(data.max)
	action.pressed.connect(func():
		_play_chime(600.0)
		if State.upgrade_building_instance(str(instance.id)): _render_tab()
	)
	actions.add_child(action)
	var move_button := _action_button("迁建")
	move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_button.disabled = State.get_open_building_slots() <= 0
	move_button.pressed.connect(func():
		_moving_building_instance = str(instance.id)
		city_visual_layer.set_move_mode(str(instance.id))
		_render_tab()
	)
	actions.add_child(move_button)

func _add_building_catalog(slot_id: String) -> void:
	_add_section_heading("选择营造", "此处为空地；建成后可直接在城景中点选和升级")
	for id in State.BUILDINGS:
		var data: Dictionary = State.BUILDINGS[id]
		var cost := State.new_building_cost(id)
		var card := _card(92)
		content_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		card.add_child(row)
		row.add_child(_glyph_badge(data.glyph, JADE if State.can_place_building_type(id) else Color("#8d8774")))
		var text_stack := VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_stack.add_theme_constant_override("separation", 4)
		row.add_child(text_stack)
		var name_label := Label.new()
		name_label.text = str(data.name)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", INK)
		text_stack.add_child(name_label)
		var desc := Label.new()
		desc.text = str(data.desc)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 9)
		desc.add_theme_color_override("font_color", INK_SOFT)
		text_stack.add_child(desc)
		text_stack.add_child(_building_cost_row(cost))
		var build := _action_button("已有" if not State.can_place_building_type(id) else State.term("build_action", "建造"))
		build.disabled = not State.can_place_building_type(id)
		var captured_id := str(id)
		build.pressed.connect(func():
			_play_chime(600.0)
			if State.place_building(captured_id, slot_id):
				var placed := State.get_building_at_slot(slot_id)
				_selected_building_instance = str(placed.id)
				_selected_building_slot = ""
				city_visual_layer.set_selected(_selected_building_instance)
				_render_tab()
		)
		row.add_child(build)

func _building_cost_row(cost: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for id in ["grain", "wood", "stone", "coins"]:
		if not cost.has(id):
			continue
		var meta := _resource_meta(id)
		var enough := float(State.resources.get(id, 0.0)) + 0.001 >= float(cost[id])
		var chip := Label.new()
		chip.text = "%s%d%s" % [meta.name, int(cost[id]), meta.unit]
		chip.add_theme_font_size_override("font_size", 10)
		chip.add_theme_color_override("font_color", JADE if enough else CINNABAR)
		chip.add_theme_stylebox_override("normal", _style(Color(0.96, 0.91, 0.75, 0.62), 6, 1, Color(JADE if enough else CINNABAR, 0.22), 3))
		row.add_child(chip)
	return row

func _format_building_effect(preview: Dictionary) -> String:
	return UiPresentation.building_effect(preview, State.RESOURCE_UNITS, State.TERMS)

func _render_market() -> void:
	_add_section_heading(State.term("ledger_title", "邑中账簿"), State.term("ledger_desc", "所有生产、民食、军粮与军饷按日公开结算"))
	var ledger := State.get_daily_ledger()
	for id in ["grain", "wood", "stone", "coins"]:
		_add_ledger_card(id, ledger[id])
	_add_section_heading(State.term("market_title", "陶朱之市"), State.term("market_desc", "市集等级越高价格越有利；仓容不足时整笔不成交、不扣款"))
	for trade_id in ["sell_grain", "buy_grain", "sell_wood", "buy_stone"]:
		_add_trade_card(State.get_trade_label(trade_id), trade_id)

func _add_ledger_card(id: String, entry: Dictionary) -> void:
	var meta := _resource_meta(id)
	var unit: String = meta.unit
	var details: Array[String] = []
	for item in entry.details:
		if absf(float(item[1])) >= 0.01:
			details.append("%s %+.1f%s" % [item[0], float(item[1]), unit])
	var accent := JADE if float(entry.net) >= 0.0 else CINNABAR
	content_box.add_child(_info_banner(
		"%s %d / %d%s · 本日 %+.1f%s" % [meta.name, floori(State.resources[id]), floori(State.get_capacity(id)), unit, float(entry.net), unit],
		"  ·  ".join(details),
		accent
	))

func _add_trade_card(title: String, id: String) -> void:
	var quote := State.get_trade_quote(id)
	var card := _card(78)
	content_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(_glyph_badge("易", GOLD))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", INK)
	stack.add_child(heading)
	var detail := Label.new()
	detail.text = "付 %s  →  得 %s" % [_format_cost(quote.cost), _format_cost(quote.gain)]
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var button := _action_button(State.get_trade_label("action"))
	button.pressed.connect(func():
		_play_chime(640.0)
		if State.trade(id): _render_tab()
	)
	row.add_child(button)

func _render_military() -> void:
	_add_section_heading(State.term("military_title", "戎车既饬"), State.term("military_desc", "军籍、军粮、伤员、辎重与来敌编成均可追溯"))
	var enemy := State.get_enemy_display()
	var enemy_detail := "%s · 距城%d日 · %s\n%s" % [enemy.name, State.days_until_attack(), enemy.range, enemy.composition]
	content_box.add_child(_info_banner(State.term("enemy_intel", "来敌军情"), enemy_detail, CINNABAR))
	_add_defense_order_card()
	if bool(enemy.known):
		var forecast := State.get_battle_forecast(100)
		var forecast_text := "%s「%s」 · 我军力%d / 敌军力%d\n胜算约%d%% · 预计伤亡%d～%d%s" % [State.term("defense_order", "阵令"), State.get_defense_order_data().name, State.get_army_power(), State.get_enemy_power(), roundi(float(forecast.win_rate) * 100.0), forecast.loss_low, forecast.loss_high, State.term("population_unit", "人")]
		content_box.add_child(_info_banner(State.term("battle_forecast", "守城推演"), forecast_text, JADE if float(forecast.win_rate) >= 0.60 else CINNABAR))
	else:
		content_box.add_child(_info_banner(State.term("battle_forecast", "守城推演"), "%s「%s」 · 我军力%d · 敌军约%s\n军情不足：巡剿或反侦后显示胜算与预计伤亡" % [State.term("defense_order", "阵令"), State.get_defense_order_data().name, State.get_army_power(), enemy.range], GOLD))
	var ledger := State.get_daily_ledger()
	content_box.add_child(_info_banner(State.term("roster", "军籍与伤营"), "%d/%d%s · 其中%s%d%s · 日耗%s%.1f%s、%s%.0f%s" % [State.get_army_count() + State.get_wounded_count(), State.get_army_capacity(), State.term("population_unit", "人"), State.term("wounded", "伤员"), State.get_wounded_count(), State.term("population_unit", "人"), State.term("provisions", "军粮"), _army_ledger_cost(ledger.grain.details), State.RESOURCE_UNITS.grain.unit, State.term("pay", "军饷"), _army_ledger_cost(ledger.coins.details), State.RESOURCE_UNITS.coins.unit], GOLD))
	var logistics := State.get_logistics_status()
	content_box.add_child(_info_banner("%s · %s" % [logistics.name, logistics.state], "负载%.0f / 承载%.0f%s · 战斗效能%d%%\n%s" % [logistics.load, logistics.capacity, logistics.unit, roundi(float(logistics.factor) * 100.0), logistics.desc], JADE if float(logistics.factor) >= 0.999 else (GOLD if float(logistics.factor) >= 0.85 else CINNABAR)))
	for id in State.UNITS:
		_add_unit_card(id)
	var patrol_card := _card(82)
	content_box.add_child(patrol_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	patrol_card.add_child(row)
	row.add_child(_glyph_badge("巡", CINNABAR))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var label := Label.new()
	label.text = State.term("patrol_name", "出城巡剿")
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", INK)
	stack.add_child(label)
	var detail := Label.new()
	detail.text = "每日至多一次 · %s · 侦察并削减真实敌军" % _format_cost(State.LOGISTICS.patrol_cost)
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var action := _action_button(State.term("patrol_action", "出征"))
	action.pressed.connect(func():
		_play_chime(390.0)
		if State.patrol(): _render_tab()
	)
	row.add_child(action)

func _add_defense_order_card() -> void:
	var active: Dictionary = State.get_defense_order_data()
	var card := _card(124)
	content_box.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	card.add_child(stack)
	var title := Label.new()
	title.text = "%s · 当前「%s」" % [State.term("defense_order", "守城阵令"), active.name]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", INK)
	stack.add_child(title)
	var detail := Label.new()
	detail.text = active.desc + "；切换后推演与真实守城同步更新"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	stack.add_child(choices)
	for id in State.DEFENSE_ORDERS:
		var order_id := str(id)
		var order: Dictionary = State.DEFENSE_ORDERS[order_id]
		var button := _action_button(("● " if order_id == State.defense_order else "") + str(order.name))
		button.custom_minimum_size = Vector2(0, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if order_id == State.defense_order:
			button.add_theme_stylebox_override("normal", _style(CINNABAR, 10, 1, GOLD, 4))
		button.pressed.connect(func():
			if State.set_defense_order(order_id):
				_render_tab()
		)
		choices.add_child(button)

func _add_unit_card(id: String) -> void:
	var data: Dictionary = State.UNITS[id]
	var count: int = State.units[id]
	var card := _card(104)
	content_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(_glyph_badge(data.glyph, Color("#756047")))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var name_label := Label.new()
	var unit_name := "%s  %d%s" % [data.name, count, str(data.get("count_unit", State.term("population_unit", "人")))]
	if data.has("formation_size") and int(data.formation_size) > 0:
		unit_name += "（%d%s齐备）" % [floori(float(count) / int(data.formation_size)), str(data.get("formation_unit", "队"))]
	name_label.text = unit_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", INK)
	stack.add_child(name_label)
	var detail := Label.new()
	detail.text = "每%s一%s%d%s · 军力/%s %.2f\n日耗 %s%.2f%s %s%.2f%s · %s%s" % [State.term("recruit_verb", "征募"), str(data.get("batch_label", "伍")), data.batch, str(data.get("count_unit", State.term("population_unit", "人"))), str(data.get("count_unit", State.term("population_unit", "人"))), data.power, State.RESOURCE_UNITS.grain.short, data.grain_daily, State.RESOURCE_UNITS.grain.unit, State.RESOURCE_UNITS.coins.short, data.coins_daily, State.RESOURCE_UNITS.coins.unit, ("需%s%d级 · " % [State.BUILDINGS.barracks.name, int(data.need)] if int(data.need) > 0 else ""), _format_cost(data.cost)]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var recruit_button := _action_button(State.term("recruit_action", "征募"))
	recruit_button.disabled = State.buildings.barracks < int(data.need)
	recruit_button.pressed.connect(func():
		_play_chime(440.0)
		if State.recruit(id): _render_tab()
	)
	row.add_child(recruit_button)

func _army_ledger_cost(details: Array) -> float:
	var total := 0.0
	for item in details:
		if str(item[0]) in [State.term("army_food", "军籍粮秣"), State.term("army_pay", "军饷")]:
			total += absf(float(item[1]))
	return total

func _render_governance() -> void:
	_add_section_heading(State.term("governance_title", "邑宰案牍"), State.term("governance_desc", "城池规模与时代积累分别成长，发展和征战共同推动新制"))
	var prosperity := State.get_prosperity()
	var target := State.get_chapter_target()
	content_box.add_child(_progress_card(
		"%s · 城池等级%d" % [State.get_city_level_name(), State.chapter],
		mini(prosperity, target), target,
		"繁荣%d · 建筑用地%d处 · 建筑、人口与军队共同提升" % [prosperity, State.get_building_slot_count()]
	))
	if State.get_next_era_id().is_empty():
		content_box.add_child(_progress_card(
			"%s新制已启用" % State.get_era_name(), 1, 1,
			"当前时代路线已经完成，继续经营并扩建城池"
		))
	else:
		content_box.add_child(_progress_card(
			"%s%s" % [State.get_era_name(), State.term("era_progress", "时代积累")],
			State.era_progress, State.get_era_progress_target(),
			"主动推进日期、营造城池、巡剿与守城胜利都会积累"
		))
	var irrigation: Dictionary = State.get_policy_data("irrigate")
	_add_policy_card(irrigation.name, irrigation.effect, "irrigate", irrigation.glyph)
	var relief_preview := State.get_policy_preview("tax_relief")
	var relief: Dictionary = State.get_policy_data("tax_relief")
	_add_policy_card(relief.name, "%s+%d · 民心+%.0f" % [State.term("population", "民口"), relief_preview.population_gain, relief_preview.morale_gain], "tax_relief", relief.glyph)
	var reward_preview := State.get_policy_preview("reward_army")
	var reward: Dictionary = State.get_policy_data("reward_army")
	_add_policy_card(reward.name, "民心+%.0f · %d%s%s可提前归队" % [reward_preview.morale_gain, reward_preview.expedited_wounded, State.term("population_unit", "人"), State.term("wounded", "伤员")], "reward_army", reward.glyph)
	var advance := _card(82)
	content_box.add_child(advance)
	var row := HBoxContainer.new()
	advance.add_child(row)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var name_label := Label.new()
	var city_at_max := State.chapter >= State.get_max_city_level()
	name_label.text = "扩建为下一阶城池" if not city_at_max else "%s城池已臻完善" % State.get_era_name()
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", INK)
	stack.add_child(name_label)
	var detail := Label.new()
	detail.text = "达到繁荣目标后开放建筑用地，城景也会扩大" if not city_at_max else "继续发展与征战，积累进入下一时代所需的制度经验"
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var action := _action_button("扩建" if not city_at_max else "已完成")
	action.disabled = city_at_max or prosperity < target
	action.pressed.connect(func():
		_play_chime(740.0)
		if State.advance_chapter():
			_show_chapter_modal()
			_render_tab()
	)
	row.add_child(action)

	var era_card := _card(92)
	content_box.add_child(era_card)
	var era_row := HBoxContainer.new()
	era_row.add_theme_constant_override("separation", 10)
	era_card.add_child(era_row)
	era_row.add_child(_glyph_badge("史", GOLD))
	var era_stack := VBoxContainer.new()
	era_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	era_row.add_child(era_stack)
	var era_title := Label.new()
	var next_era_name := State.get_next_era_name()
	era_title.text = "进入%s" % next_era_name if not next_era_name.is_empty() else "%s新制已定" % State.get_era_name()
	era_title.add_theme_font_size_override("font_size", 15)
	era_title.add_theme_color_override("font_color", INK)
	era_stack.add_child(era_title)
	var era_detail := Label.new()
	var era_block := State.get_era_advance_block_reason()
	era_detail.text = "积累完成。进入新制后，兵种、城建、敌军与资源称谓都会更新。" if era_block.is_empty() else era_block
	era_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	era_detail.add_theme_font_size_override("font_size", 10)
	era_detail.add_theme_color_override("font_color", INK_SOFT)
	era_stack.add_child(era_detail)
	var era_action := _action_button("更迭" if not next_era_name.is_empty() else "已完备")
	era_action.disabled = not State.can_advance_era()
	era_action.pressed.connect(func():
		var commit_era := func():
			if State.advance_era():
				_show_era_transition_modal()
				_render_tab()
		_show_modal(
			"进入%s？" % State.get_next_era_name(),
			"这是一次时代跃迁。青禾的城池、人口、资源和军队人数会保留，但兵种名称、训练强度、建筑体系、阵令与来敌将切换为新配置。",
			[
				{"text": "暂缓更迭", "callback": func(): pass},
				{"text": "启用新制", "callback": commit_era},
			],
			GOLD,
			_dismiss_modal
		)
	)
	era_row.add_child(era_action)

func _add_policy_card(title: String, effect: String, id: String, glyph: String) -> void:
	var cost := State.get_policy_cost(id)
	var block_reason := State.get_policy_block_reason(id)
	var card := _card(82)
	content_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(_glyph_badge(glyph, JADE_LIGHT))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", INK)
	stack.add_child(title_label)
	var desc := Label.new()
	desc.text = "%s · %s" % [_format_cost(cost), effect if block_reason.is_empty() else block_reason]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", CINNABAR if not block_reason.is_empty() else INK_SOFT)
	stack.add_child(desc)
	var action := _action_button("施行")
	action.disabled = not block_reason.is_empty()
	action.pressed.connect(func():
		_play_chime(570.0)
		if State.enact_policy(id): _render_tab()
	)
	row.add_child(action)

func _add_section_heading(title: String, subtitle: String) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -1)
	content_box.add_child(stack)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", INK)
	stack.add_child(heading)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(sub)

func _card(height: float) -> PanelContainer:
	return UiComponents.card(height)

func _glyph_badge(glyph: String, color: Color) -> Label:
	return UiComponents.glyph_badge(glyph, color)

func _action_button(text_value: String) -> Button:
	return UiComponents.action_button(text_value)

func _info_banner(title: String, detail: String, accent: Color) -> PanelContainer:
	return UiComponents.info_banner(title, detail, accent)

func _progress_card(title: String, value: int, target: int, detail_text: String) -> PanelContainer:
	return UiComponents.progress_card(title, value, target, detail_text)

func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = get_tree().create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func(): toast_panel.visible = false)

func _show_settings() -> void:
	State.set_modal_paused(true)
	Telemetry.track("settings_opened", {})
	if modal_layer and is_instance_valid(modal_layer):
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.z_index = 210
	add_child(modal_layer)
	_modal_back_action = _close_settings
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.055, 0.075, 0.06, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.045
	panel.anchor_right = 0.955
	panel.anchor_top = 0.075
	panel.anchor_bottom = 0.93
	panel.add_theme_stylebox_override("panel", _style(PAPER, 24, 2, Color(JADE, 0.62), 16))
	modal_layer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "城邑设置"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", INK)
	header.add_child(title)
	var close := _action_button("完成")
	close.custom_minimum_size = Vector2(70, 38)
	close.pressed.connect(func():
		_play_chime()
		_close_settings()
	)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scroll.add_child(content)

	_add_settings_heading(content, "声律", "四时原创曲目随季节平滑切换")
	_add_volume_row(content, "总音量", "master")
	_add_volume_row(content, "背景音乐", "music")
	_add_volume_row(content, "操作音效", "sfx")
	var mute := CheckButton.new()
	mute.text = "静音"
	mute.button_pressed = bool(Audio.settings.muted)
	_style_settings_toggle(mute)
	mute.toggled.connect(func(value: bool): Audio.set_muted(value))
	content.add_child(mute)
	var haptics := CheckButton.new()
	haptics.text = "触觉反馈"
	haptics.button_pressed = bool(Audio.settings.get("haptics", true))
	_style_settings_toggle(haptics)
	haptics.toggled.connect(func(value: bool): Audio.set_haptics_enabled(value))
	content.add_child(haptics)

	_add_settings_heading(content, "存档管理", "自动存档持续运行，手动档位用于保留关键节点")
	content.add_child(_info_banner("自动存档", "第 %d 日 · 繁荣 %d · 每十秒与关键操作保存" % [State.current_day, State.get_prosperity()], JADE))
	for slot_data in State.list_save_slots():
		_add_save_slot_row(content, slot_data)
	var new_game := _danger_button("重新开始新城邑")
	new_game.pressed.connect(func():
		_confirm_action("重新开始？", "当前自动进度将被新游戏覆盖。三个手动档位不会删除。", "重新开始", func():
			State.reset_game()
			_clear_building_selection()
			_render_tab()
			_show_tutorial()
		)
	)
	content.add_child(new_game)

	_add_settings_heading(content, "诊断与埋点", "只在本机滚动记录，不联网、不含个人信息")
	var diag_toggle := CheckButton.new()
	diag_toggle.text = "记录本地诊断事件"
	diag_toggle.button_pressed = bool(Audio.settings.diagnostics_enabled)
	_style_settings_toggle(diag_toggle)
	diag_toggle.toggled.connect(func(value: bool):
		Audio.set_diagnostics_enabled(value)
		if value: Telemetry.track("diagnostics_enabled", {})
	)
	content.add_child(diag_toggle)
	var export_button := _action_button("导出诊断报告并复制")
	export_button.custom_minimum_size.y = 46
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(func():
		_play_chime()
		var path := Telemetry.build_report(State.get_snapshot(), State.list_save_slots())
		_show_toast("诊断报告已复制，可直接粘贴给开发者\n本机备份：" + path)
	)
	content.add_child(export_button)
	var clear_logs := Button.new()
	clear_logs.text = "清空诊断记录"
	clear_logs.add_theme_font_size_override("font_size", 13)
	clear_logs.add_theme_color_override("font_color", CINNABAR)
	clear_logs.add_theme_stylebox_override("normal", _style(Color(CINNABAR, 0.08), 10, 1, Color(CINNABAR, 0.24), 6))
	clear_logs.pressed.connect(func():
		_confirm_action("清空诊断记录？", "历史操作与错误记录将被删除，此操作无法撤销。", "确认清空", func():
			Telemetry.clear_logs()
			_show_settings()
		)
	)
	content.add_child(clear_logs)

	_add_settings_heading(content, "关于", "版本 %s · 离线单机 · 无广告与联网权限" % ProjectSettings.get_setting("application/config/version", "未知"))
	var tutorial_button := _action_button("重看上任说明")
	tutorial_button.custom_minimum_size.y = 46
	tutorial_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_button.pressed.connect(func():
		_play_chime()
		_show_tutorial(true)
	)
	content.add_child(tutorial_button)
	var licenses_button := _action_button("开源软件许可与鸣谢")
	licenses_button.custom_minimum_size.y = 46
	licenses_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	licenses_button.pressed.connect(func():
		_play_chime()
		_show_licenses()
	)
	content.add_child(licenses_button)

func _show_licenses() -> void:
	State.set_modal_paused(true)
	Telemetry.track("licenses_opened", {})
	if modal_layer and is_instance_valid(modal_layer):
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.z_index = 215
	add_child(modal_layer)
	_modal_back_action = _show_settings
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.055, 0.075, 0.06, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.035
	panel.anchor_right = 0.965
	panel.anchor_top = 0.035
	panel.anchor_bottom = 0.965
	panel.add_theme_stylebox_override("panel", _style(PAPER, 22, 2, Color(JADE, 0.62), 13))
	modal_layer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "开源软件许可"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", INK)
	header.add_child(title)
	var back := _action_button("返回设置")
	back.custom_minimum_size = Vector2(86, 38)
	back.pressed.connect(func():
		_play_chime()
		_show_settings()
	)
	header.add_child(back)
	var hint := Label.new()
	hint.text = "许可信息随当前引擎生成，可长按选择文本。"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", INK_SOFT)
	layout.add_child(hint)
	var notice := RichTextLabel.new()
	notice.name = "LicenseNotice"
	notice.text = LicenseNotice.build_notice()
	notice.bbcode_enabled = false
	notice.selection_enabled = true
	notice.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notice.add_theme_font_size_override("normal_font_size", 11)
	notice.add_theme_color_override("default_color", INK)
	notice.add_theme_stylebox_override("normal", _style(Color(1.0, 0.98, 0.90, 0.62), 12, 1, Color(JADE, 0.18), 9))
	layout.add_child(notice)

func _style_settings_toggle(toggle: CheckButton) -> void:
	toggle.add_theme_font_size_override("font_size", 14)
	# Android's default pressed CheckButton text is white. Every state needs an
	# explicit ink color so enabled toggles remain readable on the paper panel.
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(color_name, INK)
	toggle.add_theme_color_override("font_disabled_color", Color(INK, 0.42))

func _close_settings() -> void:
	Audio.save_settings()
	_dismiss_modal()
	Telemetry.track("settings_closed", {})

func _add_settings_heading(parent: VBoxContainer, title_text: String, subtitle_text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	parent.add_child(spacer)
	var label := Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", INK)
	parent.add_child(label)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", INK_SOFT)
	parent.add_child(subtitle)

func _add_volume_row(parent: VBoxContainer, label_text: String, channel: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 43
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 82
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", INK)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(Audio.settings[channel])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%d%%" % roundi(slider.value * 100.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size.x = 48
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", JADE)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float):
		value_label.text = "%d%%" % roundi(value * 100.0)
		Audio.set_volume(channel, value, false)
	)
	slider.drag_ended.connect(func(value_changed: bool):
		if not value_changed: return
		Audio.save_settings()
		if channel == "sfx": Audio.play_sfx("ui_tap")
	)

func _add_save_slot_row(parent: VBoxContainer, data: Dictionary) -> void:
	var slot: int = int(data.slot)
	var card := _card(84)
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	card.add_child(row)
	var badge := _glyph_badge(str(slot), JADE if bool(data.exists) else Color("#8e8878"))
	badge.custom_minimum_size = Vector2(44, 44)
	row.add_child(badge)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var title := Label.new()
	title.text = "手动档位 %d" % slot
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", INK)
	stack.add_child(title)
	var detail := Label.new()
	if bool(data.exists):
		detail.text = "%s · 第 %d 日 · 城池等级 %d · 繁荣 %d\n%s" % [data.get("era_name", "春秋"), data.day, data.chapter, data.prosperity, _format_save_time(float(data.saved_at))]
	else:
		detail.text = "空档位"
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var save_button := _action_button("覆盖" if bool(data.exists) else "保存")
	save_button.custom_minimum_size = Vector2(58, 38)
	save_button.pressed.connect(func():
		if bool(data.exists):
			_confirm_action("覆盖档位 %d？" % slot, "原有手动存档将被当前进度替换。", "确认覆盖", func():
				State.manual_save(slot)
				_show_settings()
			)
		else:
			State.manual_save(slot)
			_show_settings()
	)
	row.add_child(save_button)
	if bool(data.exists):
		var load_button := _action_button("载入")
		load_button.custom_minimum_size = Vector2(54, 38)
		load_button.pressed.connect(func():
			_confirm_action("载入档位 %d？" % slot, "当前自动进度会先保存，然后切换到该档位。", "确认载入", func():
				State.save_game()
				State.load_slot(slot)
				_clear_building_selection()
				_render_tab()
				_show_settings()
			)
		)
		row.add_child(load_button)
		var delete_button := Button.new()
		delete_button.text = "删"
		delete_button.custom_minimum_size = Vector2(38, 38)
		delete_button.add_theme_color_override("font_color", CINNABAR)
		delete_button.add_theme_stylebox_override("normal", _style(Color(CINNABAR, 0.08), 9, 1, Color(CINNABAR, 0.22), 3))
		delete_button.pressed.connect(func():
			_confirm_action("删除档位 %d？" % slot, "此手动存档将永久删除。", "确认删除", func():
				State.delete_slot(slot)
				_show_settings()
			)
		)
		row.add_child(delete_button)

func _confirm_action(title: String, body: String, confirm_text: String, action: Callable) -> void:
	_show_modal(title, body, [
		{"text": "取消", "callback": func(): _show_settings()},
		{"text": confirm_text, "callback": action},
	], CINNABAR, _show_settings)

func _danger_button(text_value: String) -> Button:
	return UiComponents.danger_button(text_value)

func _format_save_time(unix_time: float) -> String:
	return UiPresentation.save_time(unix_time)

func _format_save_time_with_bias(unix_time: float, utc_bias_minutes: int) -> String:
	return UiPresentation.save_time_with_bias(unix_time, utc_bias_minutes)

func _show_tutorial(return_to_settings := false) -> void:
	var finish := func():
		State.mark_tutorial_seen()
		if return_to_settings:
			_show_settings()
	_show_modal(
		"青禾初托",
		"周室式微，诸侯争衡。你受命治理河畔小邑「青禾」。\n\n此刻时序已经停下：不操作就不会过日。首支山泽盗将在第七日抵城，先依照「首战备忘」补兵、修防务并探明来敌，准备好再推进日期。\n\n粮以石、木以车、石料以方、财货以枚计；每日收支与军粮军饷都能在市易账簿逐项核对。",
		[{"text": "返回设置" if return_to_settings else "从首战备忘开始", "callback": finish}],
		JADE,
		_show_settings if return_to_settings else Callable()
	)

func _on_event_started(event: Dictionary) -> void:
	var options: Array = []
	for i in event.options.size():
		var choice: int = i
		var block_reason := State.get_event_choice_block_reason(choice)
		var available := block_reason.is_empty()
		var caption := _event_option_caption(event.id, i, event.options[i])
		options.append({"text": caption if available else caption + " · " + block_reason, "disabled": not available, "callback": func():
			State.resolve_event(choice)
			_render_tab()
		})
	_show_modal(event.title, event.body, options, GOLD)

func _event_option_caption(id: String, index: int, base: String) -> String:
	return UiPresentation.event_option_caption(State, id, index, base)

func _on_battle_finished(result: Dictionary) -> void:
	var title := State.term("victory_title", "城头凯歌") if result.won else State.term("defeat_title", "烽火入郭")
	var body := "%s来敌%d%s。%s奉「%s」%s，战前我军力%d、敌军力%d。\n\n%s" % [result.enemy_name, result.enemy_total, State.term("population_unit", "人"), State.term("army", "守军"), result.defense_order_name, State.term("defense_order", "阵令"), result.player_power, result.enemy_power, result.loss_text]
	var breakdown := _battle_breakdown(result)
	if not breakdown.is_empty():
		body += "\n\n" + breakdown
	if result.rounds.size() > 0:
		var round_lines: Array[String] = []
		for round_data in result.rounds:
			round_lines.append("第%d阵：我损%d / 敌损%d" % [round_data.round, round_data.player_losses, round_data.enemy_losses])
		body += "\n\n" + "  ".join(round_lines)
	_show_modal(title, body, [{"text": "整顿城邑", "callback": func(): _render_tab()}], JADE if result.won else CINNABAR)

func _battle_breakdown(result: Dictionary) -> String:
	return UiPresentation.battle_breakdown(result, State.UNITS)

func _show_chapter_modal() -> void:
	_show_modal(
		"城池扩建 · %s" % State.get_city_level_name(),
		"青禾的城郭与建筑用地已经扩展。当前可容纳%d处建筑，城景可左右拖动巡视；繁荣与时代积累仍会分别增长。" % State.get_building_slot_count(),
		[{"text": "巡视新城", "callback": func(): pass}],
		GOLD
	)

func _show_era_transition_modal() -> void:
	_show_modal(
		"时代更迭 · %s" % State.get_era_name(),
		State.get_transition_text(),
		[{"text": "整顿新制", "callback": func(): pass}],
		CINNABAR
	)

func _show_modal(title: String, body: String, buttons: Array, accent: Color, back_action: Callable = Callable()) -> void:
	State.set_modal_paused(true)
	if modal_layer and is_instance_valid(modal_layer):
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.z_index = 200
	add_child(modal_layer)
	_modal_back_action = back_action
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.055, 0.075, 0.06, 0.70)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.075
	panel.anchor_right = 0.925
	panel.anchor_top = 0.23
	panel.anchor_bottom = 0.75
	panel.add_theme_stylebox_override("panel", _style(PAPER, 24, 2, Color(accent, 0.65), 22))
	modal_layer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	panel.add_child(layout)
	var seal := Label.new()
	seal.text = "◆"
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 20)
	seal.add_theme_color_override("font_color", accent)
	layout.add_child(seal)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", INK)
	layout.add_child(heading)
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _style(Color(accent, 0.30), 1))
	layout.add_child(divider)
	var copy := Label.new()
	copy.text = body
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_theme_font_size_override("font_size", 15)
	copy.add_theme_color_override("font_color", INK_SOFT)
	copy.add_theme_constant_override("line_spacing", 7)
	layout.add_child(copy)
	for spec in buttons:
		var callback: Callable = spec.callback
		var button := _action_button(spec.text)
		button.disabled = bool(spec.get("disabled", false))
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			_play_chime(680.0)
			_dismiss_modal()
			callback.call()
		)
		layout.add_child(button)

func _format_cost(cost: Dictionary) -> String:
	return UiPresentation.cost(cost, State.RESOURCE_UNITS)

func _cn_number(value: int) -> String:
	return UiPresentation.chinese_number(value)

func _style(fill: Color, radius := 12, border_width := 0, border_color := Color.TRANSPARENT, padding := 0) -> StyleBoxFlat:
	return UiComponents.style(fill, radius, border_width, border_color, padding)
