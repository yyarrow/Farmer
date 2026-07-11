extends Control

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
	"grain": {"name": "粮", "glyph": "粟"},
	"wood": {"name": "木", "glyph": "木"},
	"stone": {"name": "石", "glyph": "石"},
	"coins": {"name": "钱", "glyph": "铢"},
}

var resource_labels := {}
var marker_buttons := {}
var tab_buttons: Array[Button] = []
var current_tab := 0
var title_label: Label
var day_label: Label
var population_label: Label
var threat_label: Label
var power_label: Label
var threat_bar: ProgressBar
var day_bar: ProgressBar
var content_box: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var modal_layer: Control
var chime_player: AudioStreamPlayer
var _toast_tween: Tween

func _ready() -> void:
	_build_scene()
	State.changed.connect(_refresh_dynamic)
	State.notice.connect(_show_toast)
	State.event_started.connect(_on_event_started)
	State.battle_finished.connect(_on_battle_finished)
	_refresh_dynamic()
	_render_tab()
	if not State.offline_report.is_empty():
		call_deferred("_show_toast", State.offline_report)
	if not State.tutorial_seen:
		call_deferred("_show_tutorial")

func _build_scene() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/art/city_spring.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var warm_wash := ColorRect.new()
	warm_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm_wash.color = Color(0.96, 0.82, 0.48, 0.055)
	warm_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(warm_wash)

	var ambient := Node2D.new()
	ambient.set_script(load("res://src/ambient_layer.gd"))
	ambient.z_index = 1
	add_child(ambient)

	_build_top_panel()
	_build_map_markers()
	_build_threat_strip()
	_build_bottom_panel()
	_build_toast()
	_build_sound()

func _build_top_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_left = 14.0
	panel.offset_top = 18.0
	panel.offset_right = -14.0
	panel.offset_bottom = 148.0
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

	var day_stack := VBoxContainer.new()
	day_stack.custom_minimum_size.x = 110
	heading.add_child(day_stack)
	day_label = Label.new()
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_label.add_theme_font_size_override("font_size", 14)
	day_label.add_theme_color_override("font_color", CINNABAR)
	day_stack.add_child(day_label)
	day_bar = ProgressBar.new()
	day_bar.show_percentage = false
	day_bar.custom_minimum_size = Vector2(100, 6)
	day_bar.add_theme_stylebox_override("background", _style(Color(0.36, 0.31, 0.22, 0.14), 3))
	day_bar.add_theme_stylebox_override("fill", _style(GOLD, 3))
	day_stack.add_child(day_bar)

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
		pill.add_theme_font_size_override("font_size", 14)
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
		button.size = Vector2(72, 50)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _style(Color(0.12, 0.18, 0.13, 0.70), 13, 1, Color(1, 0.91, 0.63, 0.46), 4))
		button.add_theme_stylebox_override("hover", _style(Color(0.33, 0.45, 0.34, 0.90), 13, 1, PAPER_DARK, 4))
		button.add_theme_stylebox_override("pressed", _style(CINNABAR, 13, 1, PAPER, 4))
		button.tooltip_text = State.BUILDINGS[id].desc
		button.z_index = 5
		var captured_id: String = id
		button.pressed.connect(func():
			_play_chime(470.0)
			current_tab = 0
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
	toast_panel.z_index = 80
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

func _build_sound() -> void:
	chime_player = AudioStreamPlayer.new()
	chime_player.stream = _make_chime_stream(520.0)
	chime_player.volume_db = -12.0
	add_child(chime_player)

func _make_chime_stream(frequency: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.22
	var frames := int(mix_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / mix_rate
		var envelope := pow(1.0 - t / duration, 2.3)
		var sample := (sin(TAU * frequency * t) * 0.70 + sin(TAU * frequency * 1.5 * t) * 0.22) * envelope
		bytes.encode_s16(i * 2, clampi(int(sample * 11000.0), -32767, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _play_chime(frequency := 520.0) -> void:
	chime_player.stream = _make_chime_stream(frequency)
	chime_player.play()
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(18)

func _refresh_dynamic() -> void:
	for id in resource_labels:
		resource_labels[id].text = "%s  %d" % [RESOURCE_META[id].glyph, floori(State.resources[id])]
	var stage_names := ["", "垦荒", "成邑", "一方之城"]
	title_label.text = "青禾邑 · %s" % stage_names[mini(State.chapter, stage_names.size() - 1)]
	population_label.text = "户民 %d/%d   民心 %d" % [State.population, State.get_population_cap(), roundi(State.morale)]
	day_label.text = "春 · 第 %d 日" % State.current_day
	day_bar.value = State.day_progress * 100.0
	threat_label.text = "边患 %d · %d 日后敌袭" % [roundi(State.threat), State.days_until_attack()]
	threat_bar.value = State.threat
	power_label.text = "守军 %d队\n守备 %d / 敌势 %d" % [State.get_army_count(), State.get_defense(), State.get_next_enemy_power()]
	for id in marker_buttons:
		var level: int = State.buildings[id]
		marker_buttons[id].text = "%s  %s\n%s" % [State.BUILDINGS[id].glyph, State.BUILDINGS[id].name, ("待建" if level == 0 else "伍" + _cn_number(level))]

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
	name_label.text = "%s  %s" % [data.name, ("未建" if level == 0 else "· 伍" + _cn_number(level))]
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
	var rates := State.get_rates()
	_add_section_heading("陶朱之市", "市集等级越高，交易价格越有利")
	var income := _info_banner("每刻产出", "粮 %.1f  木 %.1f  石 %.1f  钱 %.1f" % [rates.grain, rates.wood, rates.stone, rates.coins], GOLD)
	content_box.add_child(income)
	_add_trade_card("粟米出仓", "售出 55 粮", "获得 %d 钱" % (34 + State.buildings.market * 3), "sell_grain")
	_add_trade_card("购入军粮", "支付 %d 钱" % maxi(34, 46 - State.buildings.market * 2), "获得 55 粮", "buy_grain")
	_add_trade_card("木材发卖", "售出 40 木", "获得 %d 钱" % (30 + State.buildings.market * 2), "sell_wood")
	_add_trade_card("商队运石", "支付 %d 钱" % maxi(38, 50 - State.buildings.market * 2), "获得 35 石", "buy_stone")

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
	_add_section_heading("戎车既饬", "军队消耗粮钱，但能守护积累的财富")
	var comparison := "守备 %d    敌势 %d    士气 %d" % [State.get_defense(), State.get_next_enemy_power(), roundi(State.morale)]
	content_box.add_child(_info_banner("下一场守城", comparison, CINNABAR if State.get_defense() < State.get_next_enemy_power() else JADE))
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
	detail.text = "消耗 粮38 钱18 · 胜利可降低边患"
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
	var card := _card(86)
	content_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(_glyph_badge(data.glyph, Color("#756047")))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var name_label := Label.new()
	name_label.text = "%s  × %d    战力 %d" % [data.name, count, int(data.power)]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", INK)
	stack.add_child(name_label)
	var detail := Label.new()
	detail.text = ("需兵营伍%d · " % int(data.need) if int(data.need) > 0 else "") + _format_cost(data.cost)
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

func _render_governance() -> void:
	_add_section_heading("邑宰案牍", "权衡民生、生产与军备，方可长治久安")
	var prosperity := State.get_prosperity()
	var target := State.get_chapter_target()
	content_box.add_child(_progress_card("城邑繁荣", prosperity, target, "建筑、人口与军队共同提升繁荣度"))
	_add_policy_card("兴修水利", "木35 石24 钱28", "三日粮食增产 35%", "irrigate", "渠")
	_add_policy_card("轻徭薄赋", "钱65 粮35", "增加人口与民心", "tax_relief", "民")
	_add_policy_card("犒赏三军", "粮60 钱45", "提升士气并降低边患", "reward_army", "赏")
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
	detail.text = "达到繁荣目标后获得物资，但敌势也会增强" if State.chapter < 3 else "你已将青禾经营为乱世中的安宁之城"
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
	panel.custom_minimum_size.y = 60
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

func _show_tutorial() -> void:
	_show_modal(
		"青禾初托",
		"周室式微，诸侯争衡。你受命治理河畔小邑「青禾」。\n\n营造农田与工坊，让资源持续增长；招募军队、修筑城垣，抵御周期来袭的敌人；在市易与政令之间权衡，让百姓在乱世中安居。\n\n每一日约二十四秒，离开游戏也会积累部分收益。",
		[{"text": "接掌城邑", "callback": func(): State.mark_tutorial_seen()}],
		JADE
	)

func _on_event_started(event: Dictionary) -> void:
	var options: Array = []
	for i in event.options.size():
		var choice: int = i
		options.append({"text": _event_option_caption(event.id, i, event.options[i]), "callback": func():
			State.resolve_event(choice)
			_render_tab()
		})
	_show_modal(event.title, event.body, options, GOLD)

func _event_option_caption(id: String, index: int, base: String) -> String:
	var suffix := ""
	match id:
		"drought": suffix = " · 木28 石18" if index == 0 else " · 粮-45"
		"refugees": suffix = " · 粮58" if index == 0 else " · 粮-28"
		"merchant": suffix = " · 钱72" if index == 0 else " · 粮-75 钱+62"
		"scouts": suffix = " · 钱32" if index == 0 else " · 民心-4"
		"harvest": suffix = " · 粮+105" if index == 0 else " · 民心+15"
	return base + suffix

func _on_battle_finished(result: Dictionary) -> void:
	var title := "城头凯歌" if result.won else "烽火入郭"
	var body := "敌势 %d，守备 %d。\n\n%s" % [result.enemy, result.defense, result.loss_text]
	_show_modal(title, body, [{"text": "整顿城邑", "callback": func(): _render_tab()}], JADE if result.won else CINNABAR)

func _show_chapter_modal() -> void:
	var texts := ["", "", "青禾已由村聚成长为真正的城邑。商旅渐多，邻国也开始注视这里。", "城垣坚固，仓廪充实。你在乱世中守住了一方生民。"]
	_show_modal("邑格晋升", texts[State.chapter], [{"text": "继续经营", "callback": func(): pass}], GOLD)

func _show_modal(title: String, body: String, buttons: Array, accent: Color) -> void:
	State.set_process(false)
	if modal_layer and is_instance_valid(modal_layer):
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.z_index = 200
	add_child(modal_layer)
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
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			_play_chime(680.0)
			modal_layer.queue_free()
			State.set_process(true)
			callback.call()
		)
		layout.add_child(button)

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in ["grain", "wood", "stone", "coins"]:
		if cost.has(id):
			parts.append("%s%d" % [RESOURCE_META[id].name, int(cost[id])])
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
