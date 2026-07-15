extends Control

const UiFont = preload("res://src/ui_font.gd")
const INK := Color("#29382f")
const INK_SOFT := Color("#5f6555")
const PAPER := Color("#f4e8c8")
const PAPER_DARK := Color("#dfca96")
const JADE := Color("#55745d")
const JADE_LIGHT := Color("#779274")
const CINNABAR := Color("#a54a3d")
const GOLD := Color("#c99945")
const SHADOW := Color(0.10, 0.12, 0.09, 0.42)

const RESOURCE_META := {
	"grain": {"name": "粮", "glyph": "粟", "unit": "石"},
	"wood": {"name": "木", "glyph": "木", "unit": "车"},
	"stone": {"name": "石", "glyph": "石", "unit": "方"},
	"coins": {"name": "财", "glyph": "币", "unit": "枚"},
}

var resource_labels := {}
var marker_buttons := {}
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
var content_box: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var modal_layer: Control
var _modal_back_action: Callable
var _toast_tween: Tween
var city_background: TextureRect
var city_visual_layer: Control
var _displayed_season := ""

func _ready() -> void:
	theme = UiFont.make_theme()
	_build_scene()
	State.changed.connect(_refresh_dynamic)
	State.notice.connect(_show_toast)
	State.event_started.connect(_on_event_started)
	State.battle_finished.connect(_on_battle_finished)
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
	city_background = TextureRect.new()
	city_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_background.texture = load("res://assets/art/city_spring.png")
	city_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	city_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	city_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(city_background)

	var warm_wash := ColorRect.new()
	warm_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm_wash.color = Color(0.96, 0.82, 0.48, 0.055)
	warm_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(warm_wash)

	var ambient := Node2D.new()
	ambient.set_script(load("res://src/ambient_layer.gd"))
	ambient.z_index = 1
	add_child(ambient)

	city_visual_layer = Control.new()
	city_visual_layer.name = "CityVisuals"
	city_visual_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_visual_layer.set_script(load("res://src/city_visuals.gd"))
	city_visual_layer.z_index = 2
	add_child(city_visual_layer)

	_build_top_panel()
	_build_map_markers()
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

func _build_map_markers() -> void:
	var marker_data := {
		"wall": Vector2(410, 190),
		"barracks": Vector2(344, 260),
		"warehouse": Vector2(243, 305),
		"market": Vector2(102, 354),
		"house": Vector2(360, 390),
		"woodcut": Vector2(58, 242),
		"quarry": Vector2(415, 465),
		"farm": Vector2(104, 485),
	}
	for id in marker_data:
		var button := Button.new()
		button.position = marker_data[id]
		button.size = Vector2(68, 32)
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _style(Color(0.12, 0.18, 0.13, 0.64), 10, 1, Color(1, 0.91, 0.63, 0.38), 2))
		button.add_theme_stylebox_override("hover", _style(Color(0.33, 0.45, 0.34, 0.90), 10, 1, PAPER_DARK, 2))
		button.add_theme_stylebox_override("pressed", _style(CINNABAR, 10, 1, PAPER, 2))
		button.tooltip_text = State.BUILDINGS[id].desc
		button.z_index = 5
		var captured_id: String = id
		button.pressed.connect(func():
			_play_chime(470.0)
			current_tab = 0
			Telemetry.track("building_marker_opened", {"building": captured_id})
			_update_tab_buttons()
			_render_tab()
			_show_toast("%s：%s" % [State.BUILDINGS[captured_id].name, State.BUILDINGS[captured_id].desc])
		)
		add_child(button)
		marker_buttons[id] = button

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
	for data in [["城建", "筑"], ["市易", "易"], ["军务", "戈"], ["政事", "策"]]:
		var index := tab_buttons.size()
		var tab := Button.new()
		tab.text = "%s  %s" % [data[1], data[0]]
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
			_render_tab()
		)
		tabs.add_child(tab)
		tab_buttons.append(tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	layout.add_child(scroll)
	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 8)
	scroll.add_child(content_box)

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
		resource_labels[id].text = "%s %d%s\n%+.1f/日" % [RESOURCE_META[id].glyph, floori(State.resources[id]), RESOURCE_META[id].unit, float(ledger[id].net)]
	var stage_names := ["", "垦荒", "成邑", "一方之城"]
	title_label.text = "青禾邑 · %s" % stage_names[mini(State.chapter, stage_names.size() - 1)]
	population_label.text = "%d户 · 民%d · 军%d · 心%d" % [State.get_households(), State.population, State.get_army_count(), roundi(State.morale)]
	var time_text := "停" if State.get_effective_time_speed() <= 0.0 else "%d×" % roundi(State.get_effective_time_speed())
	var calendar := State.get_calendar()
	day_label.text = "%d年·%s%d日·%s" % [calendar.year, calendar.season_name, calendar.day, time_text]
	_apply_season_tone(str(calendar.season))
	day_bar.value = State.day_progress * 100.0
	for speed in time_buttons:
		time_buttons[speed].button_pressed = is_equal_approx(float(speed), State.time_speed)
	advance_day_button.disabled = State.time_speed > 0.0 or State.modal_paused or not State.current_event.is_empty()
	var enemy := State.get_enemy_display()
	threat_label.text = "%s · %d日后抵城" % [enemy.name, State.days_until_attack()]
	threat_bar.max_value = 7
	threat_bar.value = 7 - clampi(State.days_until_attack(), 0, 7)
	power_label.text = "我军 %d / 敌军 %s\n%s" % [State.get_army_power(), str(State.get_enemy_power()) if enemy.known else "未明", enemy.range]
	for id in marker_buttons:
		var level: int = State.buildings[id]
		marker_buttons[id].text = "%s · %s" % [State.BUILDINGS[id].name, ("未" if level == 0 else _cn_number(level))]

func _apply_season_tone(season: String) -> void:
	if season == _displayed_season or not city_background:
		return
	_displayed_season = season
	Audio.set_music_season(season)
	var tones := {
		"spring": Color(1.0, 1.0, 1.0),
		"summer": Color(0.90, 1.0, 0.88),
		"autumn": Color(1.0, 0.88, 0.72),
		"winter": Color(0.82, 0.91, 1.0),
	}
	var tween := get_tree().create_tween()
	tween.tween_property(city_background, "modulate", tones.get(season, Color.WHITE), 0.8)

func _update_tab_buttons() -> void:
	for i in tab_buttons.size():
		var tab := tab_buttons[i]
		tab.button_pressed = i == current_tab
		tab.add_theme_color_override("font_color", Color.WHITE if i == current_tab else INK)
		tab.add_theme_stylebox_override("normal", _style(JADE if i == current_tab else Color(0.36, 0.37, 0.27, 0.11), 11, 0, Color.TRANSPARENT, 4))

func _render_tab() -> void:
	for child in content_box.get_children():
		child.queue_free()
	match current_tab:
		0: _render_buildings()
		1: _render_market()
		2: _render_military()
		3: _render_governance()

func _render_buildings() -> void:
	_add_section_heading("营造城邑", "升级建筑，建立稳定的生产循环")
	for id in State.BUILDINGS:
		_add_building_card(id)

func _add_building_card(id: String) -> void:
	var data: Dictionary = State.BUILDINGS[id]
	var level: int = State.buildings[id]
	var cost := State.building_cost(id)
	var card := _card(96)
	content_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(_glyph_badge(data.glyph, JADE if level > 0 else Color("#8d8774")))
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 2)
	row.add_child(text_stack)
	var name_label := Label.new()
	name_label.text = "%s  %s" % [data.name, ("未建" if level == 0 else "· " + _cn_number(level) + "阶")]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", INK)
	text_stack.add_child(name_label)
	var desc := Label.new()
	desc.text = data.desc
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", INK_SOFT)
	text_stack.add_child(desc)
	var cost_label := Label.new()
	cost_label.text = "已满级" if level >= int(data.max) else _format_cost(cost)
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", CINNABAR if not State.can_afford(cost) else JADE)
	text_stack.add_child(cost_label)
	var action := _action_button("建造" if level == 0 else "升级")
	action.disabled = level >= int(data.max)
	action.pressed.connect(func():
		_play_chime(600.0)
		if State.upgrade_building(id): _render_tab()
	)
	row.add_child(action)

func _render_market() -> void:
	_add_section_heading("邑中账簿", "所有生产、民食、军粮与军饷按日公开结算")
	var ledger := State.get_daily_ledger()
	for id in ["grain", "wood", "stone", "coins"]:
		_add_ledger_card(id, ledger[id])
	_add_section_heading("陶朱之市", "市集等级越高，交易价格越有利")
	_add_trade_card("粟米出仓", "售出 55石粮", "获得 %d枚" % (340 + State.buildings.market * 30), "sell_grain")
	_add_trade_card("购入军粮", "支付 %d枚" % maxi(340, 460 - State.buildings.market * 20), "获得 55石粮", "buy_grain")
	_add_trade_card("木材发卖", "售出 40车木", "获得 %d枚" % (300 + State.buildings.market * 20), "sell_wood")
	_add_trade_card("商队运石", "支付 %d枚" % maxi(380, 500 - State.buildings.market * 20), "获得 35方石", "buy_stone")

func _add_ledger_card(id: String, entry: Dictionary) -> void:
	var unit: String = RESOURCE_META[id].unit
	var details: Array[String] = []
	for item in entry.details:
		if absf(float(item[1])) >= 0.01:
			details.append("%s %+.1f%s" % [item[0], float(item[1]), unit])
	var accent := JADE if float(entry.net) >= 0.0 else CINNABAR
	content_box.add_child(_info_banner(
		"%s %d%s · 本日 %+.1f%s" % [RESOURCE_META[id].name, floori(State.resources[id]), unit, float(entry.net), unit],
		"  ·  ".join(details),
		accent
	))

func _add_trade_card(title: String, pay: String, gain: String, id: String) -> void:
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
	detail.text = "%s  →  %s" % [pay, gain]
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var button := _action_button("交易")
	button.pressed.connect(func():
		_play_chime(640.0)
		if State.trade(id): _render_tab()
	)
	row.add_child(button)

func _render_military() -> void:
	_add_section_heading("戎车既饬", "军籍、军粮、伤员与来敌编成均可追溯")
	var enemy := State.get_enemy_display()
	var enemy_detail := "%s · 距城%d日 · %s\n%s" % [enemy.name, State.days_until_attack(), enemy.range, enemy.composition]
	content_box.add_child(_info_banner("来敌军情", enemy_detail, CINNABAR))
	if bool(enemy.known):
		var forecast := State.get_battle_forecast(100)
		var forecast_text := "我军力%d / 敌军力%d · 胜算约%d%% · 预计伤亡%d～%d人" % [State.get_army_power(), State.get_enemy_power(), roundi(float(forecast.win_rate) * 100.0), forecast.loss_low, forecast.loss_high]
		content_box.add_child(_info_banner("守城推演", forecast_text, JADE if float(forecast.win_rate) >= 0.60 else CINNABAR))
	else:
		content_box.add_child(_info_banner("守城推演", "我军力%d · 敌军约%s\n军情不足：巡剿或反侦后显示胜算与预计伤亡" % [State.get_army_power(), enemy.range], GOLD))
	var ledger := State.get_daily_ledger()
	content_box.add_child(_info_banner("军籍与伤营", "%d/%d人 · 其中伤员%d人 · 日耗粮%.1f石、军饷%.0f枚" % [State.get_army_count() + State.get_wounded_count(), State.get_army_capacity(), State.get_wounded_count(), _army_ledger_cost(ledger.grain.details), _army_ledger_cost(ledger.coins.details)], GOLD))
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
	label.text = "出城巡剿"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", INK)
	stack.add_child(label)
	var detail := Label.new()
	detail.text = "每日至多一次 · 粮6石 财40枚 · 侦察并削减真实敌军"
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var action := _action_button("出征")
	action.pressed.connect(func():
		_play_chime(390.0)
		if State.patrol(): _render_tab()
	)
	row.add_child(action)

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
	var unit_name := "%s  %d人" % [data.name, count]
	if id == "chariot":
		unit_name += "（%d乘齐备）" % floori(count / 5.0)
	name_label.text = unit_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", INK)
	stack.add_child(name_label)
	var detail := Label.new()
	detail.text = "每征一伍%d人 · 军力/人 %.2f\n日耗 粮%.2f石 财%.2f枚 · %s%s" % [data.batch, data.power, data.grain_daily, data.coins_daily, ("需兵营%d级 · " % int(data.need) if int(data.need) > 0 else ""), _format_cost(data.cost)]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var recruit_button := _action_button("征募")
	recruit_button.disabled = State.buildings.barracks < int(data.need)
	recruit_button.pressed.connect(func():
		_play_chime(440.0)
		if State.recruit(id): _render_tab()
	)
	row.add_child(recruit_button)

func _army_ledger_cost(details: Array) -> float:
	var total := 0.0
	for item in details:
		if str(item[0]) in ["军籍粮秣", "军饷"]:
			total += absf(float(item[1]))
	return total

func _render_governance() -> void:
	_add_section_heading("邑宰案牍", "权衡民生、生产与军备，方可长治久安")
	var prosperity := State.get_prosperity()
	var target := State.get_chapter_target()
	content_box.add_child(_progress_card("城邑繁荣", prosperity, target, "建筑、人口与军队共同提升繁荣度"))
	_add_policy_card("兴修水利", "木35车 石24方 财280枚", "三日粮秣增产 35%", "irrigate", "渠")
	_add_policy_card("轻徭薄赋", "财650枚 粮35石", "吸引民口并提升民心", "tax_relief", "民")
	_add_policy_card("犒赏三军", "粮60石 财450枚", "提升士气并加快伤员恢复", "reward_army", "赏")
	var advance := _card(82)
	content_box.add_child(advance)
	var row := HBoxContainer.new()
	advance.add_child(row)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var name_label := Label.new()
	name_label.text = "晋升城邑" if State.chapter < 3 else "一方强邑"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", INK)
	stack.add_child(name_label)
	var detail := Label.new()
	detail.text = "达到繁荣目标后获得物资，后续敌军编成也会升级" if State.chapter < 3 else "你已将青禾经营为乱世中的安宁之城"
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	var action := _action_button("晋升" if State.chapter < 3 else "完成")
	action.disabled = State.chapter >= 3 or prosperity < target
	action.pressed.connect(func():
		_play_chime(740.0)
		if State.advance_chapter():
			_show_chapter_modal()
			_render_tab()
	)
	row.add_child(action)

func _add_policy_card(title: String, cost: String, effect: String, id: String, glyph: String) -> void:
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
	desc.text = "%s · %s" % [cost, effect]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(desc)
	var action := _action_button("施行")
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
	var card := PanelContainer.new()
	card.custom_minimum_size.y = height
	card.add_theme_stylebox_override("panel", _style(Color(1.0, 0.975, 0.89, 0.80), 14, 1, Color(0.42, 0.36, 0.24, 0.16), 10))
	return card

func _glyph_badge(glyph: String, color: Color) -> Label:
	var badge := Label.new()
	badge.text = glyph
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(50, 50)
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_stylebox_override("normal", _style(color, 14))
	return badge

func _action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(76, 42)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(JADE, 11, 0, Color.TRANSPARENT, 5))
	button.add_theme_stylebox_override("hover", _style(JADE_LIGHT, 11, 0, Color.TRANSPARENT, 5))
	button.add_theme_stylebox_override("pressed", _style(CINNABAR, 11, 0, Color.TRANSPARENT, 5))
	button.add_theme_stylebox_override("disabled", _style(Color(0.42, 0.41, 0.35, 0.35), 11, 0, Color.TRANSPARENT, 5))
	return button

func _info_banner(title: String, detail: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 68 if "\n" in detail else 60
	panel.add_theme_stylebox_override("panel", _style(Color(accent, 0.13), 13, 1, Color(accent, 0.22), 9))
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", accent.darkened(0.25))
	stack.add_child(heading)
	var desc := Label.new()
	desc.text = detail
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", INK)
	stack.add_child(desc)
	return panel

func _progress_card(title: String, value: int, target: int, detail_text: String) -> PanelContainer:
	var card := _card(90)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", INK)
	heading.add_child(label)
	var number := Label.new()
	number.text = "%d / %d" % [value, target]
	number.add_theme_font_size_override("font_size", 13)
	number.add_theme_color_override("font_color", CINNABAR)
	heading.add_child(number)
	var progress := ProgressBar.new()
	progress.max_value = target
	progress.value = value
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	progress.add_theme_stylebox_override("background", _style(Color(0.31, 0.32, 0.23, 0.13), 4))
	progress.add_theme_stylebox_override("fill", _style(JADE, 4))
	stack.add_child(progress)
	var detail := Label.new()
	detail.text = detail_text
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	return card

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
			_render_tab()
			_show_settings()
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
		detail.text = "第 %d 日 · 城邑阶 %d · 繁荣 %d\n%s" % [data.day, data.chapter, data.prosperity, _format_save_time(float(data.saved_at))]
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
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", CINNABAR)
	button.add_theme_stylebox_override("normal", _style(Color(CINNABAR, 0.08), 11, 1, Color(CINNABAR, 0.28), 6))
	button.add_theme_stylebox_override("pressed", _style(Color(CINNABAR, 0.20), 11, 1, CINNABAR, 6))
	return button

func _format_save_time(unix_time: float) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%04d-%02d-%02d  %02d:%02d" % [date.year, date.month, date.day, date.hour, date.minute]

func _show_tutorial() -> void:
	_show_modal(
		"青禾初托",
		"周室式微，诸侯争衡。你受命治理河畔小邑「青禾」。\n\n粮以石计、木以车计、石料以方计、财货以枚计。四时会改变收成、采集、赋税与冬日口粮，所有变化都会列入每日账本。\n\n军队按真实人数征募，来敌也有实际编成；城墙降低伤亡而不凭空增加军力。使用顶部时序控制暂停、正常、加速或精确推进一日。",
		[{"text": "接掌城邑", "callback": func(): State.mark_tutorial_seen()}],
		JADE
	)

func _on_event_started(event: Dictionary) -> void:
	var options: Array = []
	for i in event.options.size():
		var choice: int = i
		var available := State.is_event_choice_available(choice)
		var caption := _event_option_caption(event.id, i, event.options[i])
		options.append({"text": caption if available else caption + " · 物资不足", "disabled": not available, "callback": func():
			State.resolve_event(choice)
			_render_tab()
		})
	_show_modal(event.title, event.body, options, GOLD)

func _event_option_caption(id: String, index: int, base: String) -> String:
	var suffix := ""
	match id:
		"drought": suffix = " · 木28车 石18方" if index == 0 else " · 粮-45石"
		"refugees": suffix = " · 粮58石，民口+20" if index == 0 else " · 粮-28石"
		"merchant":
			if index == 0: suffix = " · 财720枚"
			elif index == 1: suffix = " · 粮-75石 财+620枚"
		"scouts": suffix = " · 财320枚，探明并袭扰敌军" if index == 0 else " · 敌军延误一日"
		"harvest": suffix = " · 粮+105石" if index == 0 else " · 粮+42石 民心+15"
		"flood": suffix = " · 木30车 石18方，农田增产3日" if index == 0 else " · 粮-60石 民心-4"
		"winter_relief": suffix = " · 粮42石 民心+10" if index == 0 else " · 民心-5"
		"craftsmen": suffix = " · 财480枚 木16车，全邑增产3日" if index == 0 else " · 石+28方 民心-3"
		"rumors": suffix = " · 财200枚，探明敌军 民心+5" if index == 0 else " · 民心-6"
		"levy": suffix = " · 粮45石 财220枚 民心+3" if index == 0 else " · 敌军提前1日 民心-4"
	return base + suffix

func _on_battle_finished(result: Dictionary) -> void:
	var title := "城头凯歌" if result.won else "烽火入郭"
	var body := "%s来敌%d人。战前我军力%d、敌军力%d。\n\n%s" % [result.enemy_name, result.enemy_total, result.player_power, result.enemy_power, result.loss_text]
	if result.rounds.size() > 0:
		var round_lines: Array[String] = []
		for round_data in result.rounds:
			round_lines.append("第%d阵：我损%d / 敌损%d" % [round_data.round, round_data.player_losses, round_data.enemy_losses])
		body += "\n\n" + "  ".join(round_lines)
	_show_modal(title, body, [{"text": "整顿城邑", "callback": func(): _render_tab()}], JADE if result.won else CINNABAR)

func _show_chapter_modal() -> void:
	var texts := ["", "", "青禾已由村聚成长为真正的城邑。商旅渐多，邻国也开始注视这里。", "城垣坚固，仓廪充实。你在乱世中守住了一方生民。"]
	_show_modal("邑格晋升", texts[State.chapter], [{"text": "继续经营", "callback": func(): pass}], GOLD)

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
	var parts: Array[String] = []
	for id in ["grain", "wood", "stone", "coins"]:
		if cost.has(id):
			parts.append("%s%d%s" % [RESOURCE_META[id].name, int(cost[id]), RESOURCE_META[id].unit])
	return "  ".join(parts)

func _cn_number(value: int) -> String:
	return ["零", "一", "二", "三", "四", "五"][clampi(value, 0, 5)]

func _style(fill: Color, radius := 12, border_width := 0, border_color := Color.TRANSPARENT, padding := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.border_color = border_color
	box.content_margin_left = padding
	box.content_margin_top = padding
	box.content_margin_right = padding
	box.content_margin_bottom = padding
	return box
