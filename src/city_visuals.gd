extends Control

const UiFont = preload("res://src/ui_font.gd")
const CityLayout = preload("res://src/data/city_layout.gd")
const BuildingProfiles = preload("res://src/city_placement/building_profiles.gd")
const POSITIONS := CityLayout.BUILDING_POSITIONS
const SIZES := CityLayout.BUILDING_SIZES
const EFFECT_POSITIONS := CityLayout.EFFECT_POSITIONS

signal building_selected(instance_id: String)
signal cell_selected(cell: Vector2i)

var building_views := {}
var building_buttons := {}
var building_labels := {}
var ground_input: Control
var displayed_stages := {}
var displayed_levels := {}
var displayed_eras := {}
var world_state := {}
var effects: Array[Dictionary] = []
var selected_instance_id := ""
var move_instance_id := ""
var selected_cell := CityLayout.INVALID_ORIGIN
var hovered_cell := CityLayout.INVALID_ORIGIN
var _pointer_start := Vector2.ZERO
var _pointer_down := false
var _effect_font: Font
var _production_accum := 0.0
var _world_time := 0.0
var _rng := RandomNumberGenerator.new()
var debug_geometry_enabled := false

func _ready() -> void:
	_effect_font = UiFont.medium()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 884422
	_build_ground_input()
	State.changed.connect(_refresh_buildings)
	State.visual_event.connect(play_event)
	_refresh_buildings()
	set_process(true)

func _style(fill: Color, border := Color.TRANSPARENT, width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	return style

func _build_ground_input() -> void:
	ground_input = Control.new()
	ground_input.name = "PlacementGround"
	ground_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground_input.mouse_filter = Control.MOUSE_FILTER_PASS
	ground_input.z_index = 1
	ground_input.gui_input.connect(_on_ground_input)
	add_child(ground_input)

func _on_ground_input(event: InputEvent) -> void:
	var point := Vector2(-999, -999)
	if event is InputEventMouseMotion:
		point = event.position
	elif event is InputEventScreenDrag:
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		if event.pressed:
			_pointer_down = true
			_pointer_start = point
		else:
			var is_tap := _pointer_down and _pointer_start.distance_to(point) <= 12.0
			_pointer_down = false
			if is_tap:
				_select_ground_cell(CityLayout.screen_to_grid(point))
	elif event is InputEventScreenTouch:
		point = event.position
		if event.pressed:
			_pointer_down = true
			_pointer_start = point
		else:
			var is_tap := _pointer_down and _pointer_start.distance_to(point) <= 18.0
			_pointer_down = false
			if is_tap:
				_select_ground_cell(CityLayout.screen_to_grid(point))
	if point.x > -900:
		hovered_cell = CityLayout.screen_to_grid(point)
		queue_redraw()

func _select_ground_cell(cell: Vector2i) -> void:
	if not CityLayout.is_cell_unlocked(cell, State.get_building_slot_count()):
		return
	var occupied := State.get_building_at_cell(cell)
	if not occupied.is_empty():
		building_selected.emit(str(occupied.id))
		return
	selected_cell = cell
	cell_selected.emit(cell)
	queue_redraw()

func set_selected(instance_id: String) -> void:
	selected_instance_id = instance_id
	selected_cell = CityLayout.INVALID_ORIGIN
	_refresh_buildings()

func set_selected_cell(cell: Vector2i) -> void:
	selected_cell = cell
	selected_instance_id = ""
	_refresh_buildings()

func set_move_mode(instance_id: String) -> void:
	move_instance_id = instance_id
	selected_instance_id = instance_id
	_refresh_buildings()

func clear_move_mode() -> void:
	move_instance_id = ""
	_refresh_buildings()

func set_debug_geometry_enabled(enabled: bool) -> void:
	debug_geometry_enabled = enabled
	queue_redraw()

func _layout_for_instance(instance: Dictionary) -> Dictionary:
	var building_type := str(instance.get("type", ""))
	var origin := CityLayout.instance_origin(instance)
	if origin == CityLayout.INVALID_ORIGIN or building_type.is_empty():
		return {}
	var polygon := CityLayout.footprint_polygon(origin, building_type)
	var ground_rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		ground_rect = ground_rect.expand(point)
	var anchor := CityLayout.art_anchor(origin, building_type)
	var level := int(instance.get("level", 1))
	var art_rect := BuildingProfiles.render_rect(anchor, building_type, level)
	return {
		"origin": origin, "polygon": polygon, "anchor": anchor,
		"position": ground_rect.position, "size": ground_rect.size,
		"art_size": art_rect.size,
		"art_rect": art_rect,
		"z": 20 + CityLayout.depth(origin, building_type),
	}

func _create_building_view(instance: Dictionary) -> void:
	var instance_id := str(instance.id)
	var button := Button.new()
	button.name = instance_id
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var captured_id := instance_id
	button.pressed.connect(func(): building_selected.emit(captured_id))
	add_child(button)
	building_buttons[instance_id] = button

	var view := TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.modulate = Color(1.0, 1.0, 1.0, 0.96)
	button.add_child(view)
	building_views[instance_id] = view

	var label := Label.new()
	label.position = Vector2(-9, -25)
	label.size = Vector2(118, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#f8e9bd"))
	label.add_theme_stylebox_override("normal", _style(Color(0.08, 0.12, 0.09, 0.78), Color(0.89, 0.73, 0.38, 0.30), 1))
	button.add_child(label)
	building_labels[instance_id] = label

func _sync_instance_views() -> void:
	var active := {}
	for instance in State.get_building_instances():
		var instance_id := str(instance.id)
		active[instance_id] = true
		if not building_views.has(instance_id):
			_create_building_view(instance)
		var slot_data := _layout_for_instance(instance)
		var button: Button = building_buttons[instance_id]
		button.position = slot_data.art_rect.position
		button.size = slot_data.art_rect.size
		button.pivot_offset = button.size * 0.5
		button.z_index = int(slot_data.z)
		var is_selected := selected_instance_id == instance_id
		button.add_theme_stylebox_override("normal", _style(Color(0.94, 0.79, 0.42, 0.08) if is_selected else Color.TRANSPARENT))
		button.add_theme_stylebox_override("hover", _style(Color(0.94, 0.79, 0.42, 0.09)))
		button.add_theme_stylebox_override("pressed", _style(Color(0.63, 0.23, 0.18, 0.12)))
		var building_type := str(instance.type)
		var level := int(instance.level)
		var stage := _stage_for_level(level)
		if displayed_stages.get(instance_id, -1) != stage or displayed_eras.get(instance_id, "") != State.era_id:
			displayed_stages[instance_id] = stage
			displayed_eras[instance_id] = State.era_id
			building_views[instance_id].texture = _atlas_for(building_type, stage)
		var art_size: Vector2 = slot_data.art_size
		var view: TextureRect = building_views[instance_id]
		view.size = art_size
		view.position = Vector2.ZERO
		view.pivot_offset = art_size * 0.5
		if displayed_levels.get(instance_id, -1) != level:
			displayed_levels[instance_id] = level
			view.scale = Vector2.ONE
		view.modulate = Color(1.0, 1.0, 1.0, 0.96)
		var rank_mark := " 冠" if level >= 5 else (" 精" if level >= 3 else "")
		var label: Label = building_labels[instance_id]
		label.position = Vector2(-5, art_size.y - 22)
		label.size = Vector2(art_size.x + 10, 22)
		label.text = "%s · %s%s" % [State.BUILDINGS[building_type].name, _cn_number(level), rank_mark]
		building_labels[instance_id].visible = is_selected
	for instance_id in building_views.keys():
		if active.has(instance_id):
			continue
		building_buttons[instance_id].queue_free()
		building_buttons.erase(instance_id)
		building_views.erase(instance_id)
		building_labels.erase(instance_id)
		displayed_stages.erase(instance_id)
		displayed_levels.erase(instance_id)
		displayed_eras.erase(instance_id)

func _cn_number(value: int) -> String:
	return ["零", "一", "二", "三", "四", "五"][clampi(value, 0, 5)]

func _process(delta: float) -> void:
	_world_time += delta
	_production_accum += delta
	if _production_accum >= 4.2:
		_production_accum = 0.0
		_spawn_production_details()
	for effect in effects:
		effect.life -= delta
		effect.pos += effect.vel * delta
	var remaining: Array[Dictionary] = []
	for effect in effects:
		if effect.life > 0.0:
			remaining.append(effect)
	effects = remaining
	queue_redraw()

func _refresh_buildings() -> void:
	_sync_instance_views()
	_refresh_world_state()
	queue_redraw()

func _refresh_world_state() -> void:
	var army_count := State.get_army_count()
	world_state = {
		"era": State.era_id,
		"city_level": State.chapter,
		"building_slots": State.get_building_slot_count(),
		"irrigation": State.current_day <= int(State.buffs.get("farm_until", 0)),
		"all_buff": State.current_day <= int(State.buffs.get("all_until", 0)),
		"civilian_markers": clampi(ceili(State.population / 35.0), 1, 5),
		"soldier_markers": clampi(ceili(army_count / 15.0), 0, 6),
		"defense_order": State.defense_order,
		"wounded_markers": clampi(ceili(State.get_wounded_count() / 5.0), 0, 3),
		"enemy_warning": State.days_until_attack() <= 3 or bool(State.enemy_army.get("scouted", false)),
		"enemy_urgent": State.days_until_attack() <= 1,
	}

func _building_positions(building_type: String) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for instance in State.get_building_instances_of_type(building_type):
		var slot_data := _layout_for_instance(instance)
		if not slot_data.is_empty():
			positions.append(slot_data.position)
	return positions

func _first_building_position(building_type: String, fallback: Vector2) -> Vector2:
	var positions := _building_positions(building_type)
	return positions[0] if not positions.is_empty() else fallback

func _stage_for_level(level: int) -> int:
	if level <= 0:
		return 0
	if level == 1:
		return 1
	if level <= 3:
		return 2
	return 3

func _atlas_for(id: String, stage: int) -> AtlasTexture:
	var era_path := "res://assets/art/buildings/eras/%s/%s_stages.png" % [State.era_id, id]
	var texture = load(era_path) if ResourceLoader.exists(era_path) else load("res://assets/art/buildings/%s_stages.png" % id)
	var half_w := float(texture.get_width()) / 2.0
	var half_h := float(texture.get_height()) / 2.0
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2((stage % 2) * half_w, int(stage / 2) * half_h, half_w, half_h)
	return atlas

func play_event(kind: String, payload: Dictionary) -> void:
	var position := _position_for_event(kind, payload)
	var color := Color("#d7aa51")
	var glyph := "◆"
	var burst := true
	match kind:
		"build":
			color = Color("#d9be7b")
			glyph = "落成"
			_animate_building(str(payload.get("instance_id", "")), true)
		"upgrade":
			color = Color("#f1d572")
			glyph = "焕新"
			_animate_building(str(payload.get("instance_id", "")), false)
		"trade":
			color = Color("#d9a44d")
			glyph = "商队往来"
			_spawn_caravan(not str(payload.get("trade", "")).begins_with("sell"))
		"recruit":
			color = Color("#a94d3f")
			glyph = "列阵"
			_spawn_soldiers()
		"defense_order":
			var order_id := str(payload.get("order", "steady"))
			var order: Dictionary = State.DEFENSE_ORDERS.get(order_id, State.DEFENSE_ORDERS.steady)
			color = {"steady": Color("#c59b52"), "fortify": Color("#5c7964"), "volley": Color("#6d758f"), "sally": Color("#a94d3f")}.get(order_id, Color("#c59b52"))
			glyph = "军令·" + str(order.name)
			_spawn_soldiers()
		"policy":
			color = Color("#6d9476")
			var policy := str(payload.get("policy", ""))
			glyph = str(State.POLICIES.get(policy, {}).get("name", "政令施行"))
			match policy:
				"irrigate":
					_spawn_irrigation_flow()
				"tax_relief":
					_spawn_civilians()
				"reward_army":
					_spawn_soldiers()
		"event":
			color = Color("#cf9944")
			glyph = "风云有变"
		"event_choice":
			color = Color("#cf9944")
			glyph = "事定人安"
			_spawn_event_choice(payload)
		"patrol_win":
			color = Color("#e3c96f")
			glyph = "凯旋"
			_spawn_patrol(true)
		"patrol_loss":
			color = Color("#a34237")
			glyph = "巡骑折返"
			_spawn_patrol(false)
			_spawn_smoke(position)
		"siege_win":
			color = Color("#e3c96f")
			glyph = "城头凯歌"
			_spawn_patrol(true)
		"siege_loss":
			color = Color("#a34237")
			glyph = "烽烟"
			_spawn_smoke(position)
		"day":
			burst = false
			_spawn_daily_flow(payload)
		"shortage":
			color = Color("#b65243")
			glyph = "物资不足"
		"storage_full":
			color = Color("#c07a42")
			glyph = "仓容不足"
		"chapter":
			color = Color("#e6c56f")
			glyph = "城邑焕新"
			_flash_all_buildings()
		"era":
			color = Color("#b84b3f")
			glyph = "%s新制" % str(payload.get("name", State.get_era_name()))
			_flash_all_buildings()
			_spawn_soldiers()
		"slot_full":
			color = Color("#c07a42")
			glyph = "城内用地已满"
		"load", "new_game":
			_refresh_buildings()
			glyph = "整顿城邑"
	if burst:
		_spawn_burst(position, color, glyph)

func _position_for_event(kind: String, payload: Dictionary) -> Vector2:
	var instance := State.get_building_instance(str(payload.get("instance_id", "")))
	if not instance.is_empty():
		var slot_data := _layout_for_instance(instance)
		return slot_data.anchor
	if payload.has("building") and POSITIONS.has(payload.building):
		return POSITIONS[payload.building] + SIZES[payload.building] * 0.5
	if kind.begins_with("siege"):
		return EFFECT_POSITIONS.siege
	return EFFECT_POSITIONS.get(kind, Vector2(270, 350))

func _animate_building(instance_id: String, is_new: bool) -> void:
	if not building_views.has(instance_id):
		return
	var instance := State.get_building_instance(instance_id)
	var view: TextureRect = building_views[instance_id]
	var button: Button = building_buttons[instance_id]
	var target_scale := Vector2.ONE
	view.scale = Vector2(0.46, 0.46) if is_new else Vector2(0.78, 0.78)
	view.modulate = Color(0.52, 0.43, 0.30, 0.20)
	button.add_theme_stylebox_override("normal", _style(Color(0.35, 0.25, 0.14, 0.30), Color("#d6aa54"), 2))
	var center := button.position + button.size * 0.5
	effects.append({"kind": "construction", "pos": center, "vel": Vector2.ZERO, "life": 1.35, "max_life": 1.35, "color": Color("#d5aa5b"), "size": 42.0})
	var tween := get_tree().create_tween()
	tween.tween_interval(0.48)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", target_scale, 0.82)
	tween.parallel().tween_property(view, "modulate", Color(1, 1, 1, 0.96), 0.82)
	tween.tween_callback(func():
		_spawn_burst(center, Color("#f1d572"), "落成" if is_new else "升阶")
		_refresh_buildings()
	)

func _flash_all_buildings() -> void:
	for id in building_views:
		var view: TextureRect = building_views[id]
		view.modulate = Color(1.45, 1.25, 0.72, 1.0)
		get_tree().create_tween().tween_property(view, "modulate", Color(1, 1, 1, 0.94), 1.2)

func _spawn_burst(position: Vector2, color: Color, label: String) -> void:
	for i in 16:
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(16.0, 52.0)
		effects.append({
			"kind": "mote",
			"pos": position,
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -10),
			"life": _rng.randf_range(0.7, 1.4),
			"max_life": 1.4,
			"color": color,
			"size": _rng.randf_range(1.8, 4.4),
		})
	effects.append({"kind": "label", "pos": position + Vector2(-28, -18), "vel": Vector2(0, -18), "life": 1.7, "max_life": 1.7, "color": color, "text": label})

func _spawn_production_details() -> void:
	var candidates := []
	for id in ["farm", "woodcut", "quarry", "market"]:
		if int(State.buildings[id]) > 0:
			candidates.append(id)
	if candidates.is_empty():
		return
	var id: String = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var labels := {"farm": "+" + str(State.RESOURCE_UNITS.grain.glyph), "woodcut": "+" + str(State.RESOURCE_UNITS.wood.glyph), "quarry": "+" + str(State.RESOURCE_UNITS.stone.glyph), "market": "+" + str(State.RESOURCE_UNITS.coins.glyph)}
	effects.append({"kind": "label", "pos": POSITIONS[id] + SIZES[id] * 0.46, "vel": Vector2(0, -11), "life": 1.5, "max_life": 1.5, "color": Color("#f0d88e"), "text": labels[id]})

func _spawn_caravan(incoming := true) -> void:
	for i in 3:
		var start := Vector2(-30 - i * 24, 422 + i * 5) if incoming else Vector2(150 + i * 18, 405 + i * 5)
		var velocity := Vector2(92, -5) if incoming else Vector2(-92, 5)
		effects.append({"kind": "caravan", "pos": start, "vel": velocity, "life": 2.5, "max_life": 2.5, "color": Color("#c68f45"), "size": 5.0})

func _spawn_soldiers() -> void:
	for i in 6:
		effects.append({"kind": "soldier", "pos": Vector2(368 + (i % 3) * 11, 300 + int(i / 3) * 12), "vel": Vector2(30, -15), "life": 2.0, "max_life": 2.0, "color": Color("#a64b3d"), "size": 4.0})

func _spawn_patrol(won: bool) -> void:
	for i in 6:
		var start := Vector2(392 + (i % 3) * 9, 250 + int(i / 3) * 11)
		effects.append({"kind": "soldier", "pos": start, "vel": Vector2(58, -18 if won else 12), "life": 2.1, "max_life": 2.1, "color": Color("#d3b65f") if won else Color("#9b493f"), "size": 4.0})

func _spawn_irrigation_flow() -> void:
	for i in 14:
		effects.append({"kind": "water", "pos": POSITIONS.farm + Vector2(22 + i * 5, 31 + (i % 3) * 5), "vel": Vector2(14, -7), "life": 1.4 + i * 0.04, "max_life": 2.0, "color": Color("#66a9ad"), "size": 2.4})

func _spawn_civilians() -> void:
	for i in 7:
		effects.append({"kind": "civilian", "pos": POSITIONS.market + Vector2(34 + (i % 3) * 12, 58 + int(i / 3) * 10), "vel": Vector2(34, -7), "life": 2.2, "max_life": 2.2, "color": Color("#c1844b"), "size": 3.0})

func _spawn_event_choice(payload: Dictionary) -> void:
	var id := str(payload.get("id", ""))
	var choice := int(payload.get("choice", 0))
	match id:
		"drought", "flood":
			if choice == 0: _spawn_irrigation_flow()
			elif id == "flood": _spawn_smoke(POSITIONS.farm + SIZES.farm * 0.5)
		"refugees": _spawn_civilians()
		"winter_relief":
			if choice == 0: _spawn_civilians()
		"merchant":
			if choice == 0: _spawn_caravan(true)
			elif choice == 1: _spawn_caravan(false)
		"scouts":
			if choice == 0: _spawn_patrol(true)
			else: _spawn_smoke(POSITIONS.wall + SIZES.wall * 0.5)
		"rumors":
			if choice == 0: _spawn_civilians()
			else: _spawn_smoke(POSITIONS.market + SIZES.market * 0.5)
		"harvest": _spawn_daily_flow({"ledger": State.get_daily_ledger(), "recovered": 0})
		"craftsmen": _flash_all_buildings()
		"levy":
			if choice == 0: _spawn_caravan(false)
			else: _spawn_smoke(POSITIONS.wall + SIZES.wall * 0.5)

func _spawn_daily_flow(payload: Dictionary) -> void:
	var ledger: Dictionary = payload.get("ledger", {})
	var sources := {"grain": "farm", "wood": "woodcut", "stone": "quarry", "coins": "market"}
	for resource in sources:
		if not ledger.has(resource):
			continue
		var net := float(ledger[resource].get("net", 0.0))
		if absf(net) < 0.05:
			continue
		var source: String = sources[resource]
		var tint := Color("#ead07b") if net >= 0.0 else Color("#b95b4b")
		effects.append({"kind": "label", "pos": POSITIONS[source] + SIZES[source] * 0.48, "vel": Vector2(0, -13), "life": 1.65, "max_life": 1.65, "color": tint, "text": "%s%+.0f" % [State.RESOURCE_UNITS[resource].glyph, net]})
	var recovered := int(payload.get("recovered", 0))
	var day_label := State.term("day_ledger", "日结") if recovered <= 0 else "%d%s归队" % [recovered, State.term("population_unit", "人")]
	effects.append({"kind": "label", "pos": Vector2(246, 446), "vel": Vector2(0, -12), "life": 1.8, "max_life": 1.8, "color": Color("#f0d88e"), "text": day_label})

func _spawn_smoke(position: Vector2) -> void:
	for i in 14:
		effects.append({"kind": "smoke", "pos": position + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-8, 8)), "vel": Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-24, -12)), "life": _rng.randf_range(1.4, 2.6), "max_life": 2.6, "color": Color("#4a4038"), "size": _rng.randf_range(5.0, 10.0)})

func _draw_debug_geometry() -> void:
	if not debug_geometry_enabled:
		return
	for instance in State.get_building_instances():
		var building_type := str(instance.get("type", ""))
		var origin := CityLayout.instance_origin(instance)
		var plot := CityLayout.footprint_polygon(origin, building_type)
		var closed_plot := PackedVector2Array(plot)
		closed_plot.append(plot[0])
		draw_polyline(closed_plot, Color(0.28, 0.92, 0.52, 0.95), 1.4, true)
		var clearance := CityLayout.visual_clearance_rect(origin, building_type)
		draw_rect(clearance, Color(1.0, 0.62, 0.18, 0.88), false, 1.2)
		var visual := CityLayout.visual_rect(origin, building_type)
		draw_rect(visual, Color(0.25, 0.72, 1.0, 0.72), false, 0.9)
		draw_circle(CityLayout.art_anchor(origin, building_type), 2.8, Color(0.95, 0.22, 0.28, 0.96))

func _draw() -> void:
	_draw_plot_sockets()
	_draw_world_state()
	_draw_debug_geometry()
	for effect in effects:
		var alpha := clampf(effect.life / effect.max_life, 0.0, 1.0)
		var color: Color = effect.color
		color.a = alpha * 0.9
		match effect.kind:
			"mote":
				draw_circle(effect.pos, effect.size, color)
				draw_line(effect.pos - Vector2(effect.size, 0), effect.pos + Vector2(effect.size, 0), color.lightened(0.25), 1.0)
			"label":
				var label_width := _effect_font.get_string_size(effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				draw_rect(Rect2(effect.pos + Vector2(-4, -15), Vector2(label_width + 8, 20)), Color(0.07, 0.10, 0.08, alpha * 0.72), true)
				draw_string(_effect_font, effect.pos + Vector2(1, 1), effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.05, 0.07, 0.05, alpha * 0.70))
				draw_string(_effect_font, effect.pos, effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.24))
			"caravan":
				draw_rect(Rect2(effect.pos, Vector2(18, 9)), color, true)
				draw_circle(effect.pos + Vector2(4, 11), 3, Color(0.18, 0.15, 0.11, alpha))
				draw_circle(effect.pos + Vector2(15, 11), 3, Color(0.18, 0.15, 0.11, alpha))
				var direction := 1.0 if effect.vel.x >= 0.0 else -1.0
				draw_line(effect.pos + Vector2(9 + 9 * direction, 3), effect.pos + Vector2(9 + 17 * direction, -2), color.lightened(0.15), 2)
			"soldier":
				draw_circle(effect.pos, 3.2, color)
				draw_line(effect.pos + Vector2(0, 3), effect.pos + Vector2(0, 12), color, 2)
				draw_line(effect.pos + Vector2(3, 6), effect.pos + Vector2(8, -5), color.lightened(0.3), 1.5)
			"smoke":
				draw_circle(effect.pos, effect.size * (1.2 - alpha * 0.3), Color(color, alpha * 0.34))
			"water":
				draw_line(effect.pos - effect.vel.normalized() * 7.0, effect.pos, Color(color, alpha * 0.45), 1.4, true)
				draw_circle(effect.pos, effect.size, Color(color, alpha * 0.85))
			"civilian":
				draw_circle(effect.pos, 2.8, color)
				draw_line(effect.pos + Vector2(0, 3), effect.pos + Vector2(0, 10), color.darkened(0.12), 2.0)
			"construction":
				var half: float = float(effect.size) * (0.82 + (1.0 - alpha) * 0.12)
				var frame := Rect2(effect.pos - Vector2(half, half * 0.62), Vector2(half * 2.0, half * 1.24))
				draw_rect(frame, Color(0.20, 0.14, 0.08, alpha * 0.12), true)
				draw_rect(frame, Color(color, alpha * 0.86), false, 2.0)
				for x in [-0.62, 0.0, 0.62]:
					draw_line(effect.pos + Vector2(half * x, -half * 0.72), effect.pos + Vector2(half * x, half * 0.72), Color(color.darkened(0.24), alpha * 0.82), 2.0)
				draw_line(effect.pos + Vector2(-half, -half * 0.20), effect.pos + Vector2(half, half * 0.32), Color(color.lightened(0.18), alpha * 0.78), 2.0)

func _draw_plot_sockets() -> void:
	var identity: Dictionary = State.era_definition.visual.get("identity", {})
	var earth: Color = identity.get("earth", Color(0.42, 0.32, 0.22, 0.72))
	# These exact avenue cells are rejected by placement validation. Render the
	# union as one worn-earth ribbon, not twelve board-game tiles.
	var road_polygon := CityLayout.grid_rect_polygon(Vector2i(CityLayout.ROAD_COLUMN, 0), Vector2i(1, CityLayout.GRID_SIZE.y))
	var road_tint := Color("#cbb98f").lerp(earth.lightened(0.28), 0.24)
	road_tint.a = 0.46
	draw_colored_polygon(road_polygon, road_tint)
	var edge_tint := Color(earth.darkened(0.16), 0.27)
	draw_line(road_polygon[0], road_polygon[3], edge_tint, 1.15, true)
	draw_line(road_polygon[1], road_polygon[2], edge_tint, 1.15, true)
	for y in range(1, CityLayout.GRID_SIZE.y, 2):
		var center := CityLayout.grid_to_screen(Vector2i(CityLayout.ROAD_COLUMN, y))
		draw_line(center + Vector2(-6, -3), center + Vector2(6, 3), Color(earth.darkened(0.10), 0.09), 0.8, true)

	var placement_active := not move_instance_id.is_empty() or selected_cell != CityLayout.INVALID_ORIGIN
	if placement_active:
		var region := CityLayout.unlocked_region(State.get_building_slot_count())
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				if CityLayout.is_road(cell):
					continue
				var polygon := CityLayout.cell_polygon(cell)
				var closed := PackedVector2Array(polygon)
				closed.append(polygon[0])
				draw_polyline(closed, Color(0.90, 0.78, 0.48, 0.13), 0.65, true)

	var preview_cell := hovered_cell if not move_instance_id.is_empty() else selected_cell
	if preview_cell == CityLayout.INVALID_ORIGIN:
		return
	var preview_type := "house"
	var ignore_id := ""
	if not move_instance_id.is_empty():
		var moving := State.get_building_instance(move_instance_id)
		if moving.is_empty():
			return
		preview_type = str(moving.type)
		ignore_id = move_instance_id
	var valid := State.can_place_building_at(preview_type, preview_cell, ignore_id)
	var preview := CityLayout.footprint_polygon(preview_cell, preview_type)
	var color := Color(0.25, 0.66, 0.38, 0.24) if valid else Color(0.76, 0.22, 0.18, 0.28)
	draw_colored_polygon(preview, color)
	var preview_closed := PackedVector2Array(preview)
	preview_closed.append(preview[0])
	draw_polyline(preview_closed, Color(color.lightened(0.24), 0.86), 2.0, true)

func _draw_world_state() -> void:
	if world_state.is_empty():
		return
	if bool(world_state.irrigation):
		for farm_position in _building_positions("farm"):
			for row in 3:
				var points := PackedVector2Array()
				for step in 7:
					points.append(farm_position + Vector2(15 + step * 11, 27 + row * 9 + sin(_world_time * 2.0 + step) * 1.6))
				draw_polyline(points, Color(0.30, 0.72, 0.77, 0.70), 2.1, true)
	if bool(world_state.all_buff):
		for instance in State.get_building_instances():
			var slot_data := _layout_for_instance(instance)
			var glow := 0.48 + sin(_world_time * 2.2 + slot_data.position.x) * 0.18
			draw_circle(slot_data.position + Vector2(slot_data.size.x * 0.72, slot_data.size.y * 0.25), 2.6, Color(0.95, 0.80, 0.38, glow))
	var house_position := _first_building_position("house", POSITIONS.house)
	for i in int(world_state.civilian_markers):
		if i == 0:
			draw_circle(house_position + Vector2(17, 57), 15.0, Color(0.16, 0.13, 0.09, 0.22))
		var civilian_pos := house_position + Vector2(7 + (i % 3) * 10, 49 + int(i / 3) * 10)
		draw_circle(civilian_pos, 3.0, Color("#e1ad62"))
		draw_line(civilian_pos + Vector2(0, 3), civilian_pos + Vector2(0, 9), Color("#76543b"), 1.6)
	var barracks_position := _first_building_position("barracks", POSITIONS.barracks)
	for i in int(world_state.soldier_markers):
		if i == 0:
			draw_circle(barracks_position + Vector2(17, 58), 16.0, Color(0.12, 0.10, 0.08, 0.26))
		var offset := Vector2(6 + (i % 3) * 10, 50 + int(i / 3) * 10)
		match str(world_state.defense_order):
			"fortify": offset = Vector2(7 + (i % 2) * 9, 49 + int(i / 2) * 7)
			"volley": offset = Vector2(3 + i * 6, 50 + (i % 2) * 7)
			"sally": offset = Vector2(4 + int(i / 2) * 9, 48 + abs(i % 2 - 1) * 8)
		var soldier_pos := barracks_position + offset
		draw_circle(soldier_pos, 3.0, Color("#b75042"))
		draw_line(soldier_pos + Vector2(0, 3), soldier_pos + Vector2(0, 10), Color("#654034"), 1.8)
		draw_line(soldier_pos + Vector2(3, 6), soldier_pos + Vector2(7, -2), Color("#c7aa68"), 1.2)
	var order_id := str(world_state.defense_order)
	var order: Dictionary = State.DEFENSE_ORDERS.get(order_id, State.DEFENSE_ORDERS.steady)
	var banner_base := barracks_position + Vector2(73, 74)
	var banner_color: Color = {"steady": Color("#c59b52"), "fortify": Color("#55745d"), "volley": Color("#69718a"), "sally": Color("#a54a3d")}.get(order_id, Color("#c59b52"))
	draw_line(banner_base, banner_base + Vector2(0, -31), Color("#4b3b2d"), 2.0)
	draw_colored_polygon(PackedVector2Array([banner_base + Vector2(1, -30), banner_base + Vector2(22, -25), banner_base + Vector2(1, -17)]), banner_color)
	draw_string(_effect_font, banner_base + Vector2(5, -19), str(order.glyph), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f7ebc9"))
	if int(world_state.wounded_markers) > 0:
		var tent := barracks_position + Vector2(48, 72)
		draw_colored_polygon(PackedVector2Array([tent, tent + Vector2(13, -13), tent + Vector2(26, 0)]), Color(0.84, 0.76, 0.58, 0.90))
		draw_line(tent + Vector2(13, -13), tent + Vector2(13, 0), Color("#81483b"), 1.6)
	if bool(world_state.enemy_warning):
		var warning := _first_building_position("wall", POSITIONS.wall) + Vector2(84, 68)
		var pulse := 0.68 + sin(_world_time * (5.0 if bool(world_state.enemy_urgent) else 2.0)) * 0.22
		draw_line(warning, warning + Vector2(0, -25), Color("#533a30"), 2.0)
		draw_colored_polygon(PackedVector2Array([warning + Vector2(0, -25), warning + Vector2(15, -20), warning + Vector2(0, -14)]), Color(0.64, 0.20, 0.17, pulse))

func _draw_era_identity() -> void:
	var identity: Dictionary = State.era_definition.visual.get("identity", {})
	if identity.is_empty():
		return
	# Era definitions choose the overlaid wall, standard and one small military
	# motif; the painted background remains the primary visual identity.
	var earth: Color = identity.get("earth", Color(0.37, 0.24, 0.17, 0.66))
	draw_line(Vector2(383, 248), Vector2(523, 248), earth, 4.0, true)
	for x in range(390, 520, 16):
		draw_rect(Rect2(x, 239, 9, 10), earth.lightened(0.09), true)
	for base in [Vector2(405, 223), Vector2(451, 228), Vector2(492, 220)]:
		draw_line(base, base + Vector2(0, -31), Color("#3e3027"), 2.0, true)
		var standard: Color = identity.get("standard", Color("#963e35"))
		draw_colored_polygon(PackedVector2Array([base + Vector2(1, -30), base + Vector2(19, -27), base + Vector2(16, -16), base + Vector2(1, -18)]), standard)
	var barracks_position := _first_building_position("barracks", POSITIONS.barracks)
	var command_base := barracks_position + Vector2(18, 69)
	for i in 4:
		var shield_pos := command_base + Vector2(i * 13, (i % 2) * 5)
		draw_circle(shield_pos, 5.0, Color("#6f4933"))
		draw_circle(shield_pos, 2.2, Color("#c69b58"))
		draw_line(shield_pos + Vector2(5, 1), shield_pos + Vector2(13, -8), Color("#d2bd83"), 1.4, true)
	match str(identity.get("motif", "rammed_earth")):
		"qin_road":
			for x in range(398, 516, 24):
				draw_rect(Rect2(x, 251, 14, 4), Color(0.11, 0.10, 0.09, 0.62), true)
		"han_que":
			for base in [Vector2(402, 220), Vector2(506, 219)]:
				draw_line(base + Vector2(-7, 0), base + Vector2(-7, 24), Color("#70482f"), 2.0)
				draw_line(base + Vector2(7, 0), base + Vector2(7, 24), Color("#70482f"), 2.0)
				draw_line(base + Vector2(-10, 5), base + Vector2(10, 5), Color("#a7503e"), 3.0)
		"palisade":
			for x in range(390, 522, 12):
				draw_line(Vector2(x, 255), Vector2(x + 2, 244), Color("#51463b"), 1.5)
		"river_gate":
			draw_arc(Vector2(451, 247), 16.0, PI, TAU, 12, Color("#765541"), 3.0)
			draw_line(Vector2(435, 247), Vector2(435, 257), Color("#765541"), 2.0)
			draw_line(Vector2(467, 247), Vector2(467, 257), Color("#765541"), 2.0)
		"cataphract":
			for i in 3:
				var horse := barracks_position + Vector2(20 + i * 15, 73 + (i % 2) * 4)
				draw_rect(Rect2(horse - Vector2(6, 3), Vector2(13, 7)), Color("#766b5d"), true)
				draw_circle(horse + Vector2(7, -2), 3.5, Color("#655a4d"))
		"canal_axis":
			for y in [251.0, 256.0]:
				draw_line(Vector2(390, y), Vector2(522, y), Color(0.28, 0.48, 0.57, 0.66), 1.7, true)
			draw_line(Vector2(449, 244), Vector2(449, 260), Color("#856e4e"), 3.0, true)
		"tang_ward":
			for x in [401.0, 451.0, 501.0]:
				draw_rect(Rect2(x - 7, 241, 14, 15), Color("#8b4939"), false, 2.0)
				draw_line(Vector2(x - 10, 241), Vector2(x + 10, 241), Color("#b47a4c"), 3.0, true)
		"commandery":
			for x in range(392, 522, 11):
				draw_line(Vector2(x, 257), Vector2(x + 2, 244), Color("#3e3732"), 1.5, true)
			for x in [404.0, 508.0]:
				draw_rect(Rect2(x - 5, 232, 10, 19), Color("#645143"), false, 2.0)
		"river_market":
			for y in [251.0, 256.0]:
				draw_line(Vector2(390, y), Vector2(522, y), Color(0.28, 0.55, 0.58, 0.70), 1.8, true)
			for x in [408.0, 449.0, 490.0]:
				draw_line(Vector2(x - 9, 247), Vector2(x, 238), Color("#815f42"), 2.0, true)
				draw_line(Vector2(x, 238), Vector2(x + 9, 247), Color("#815f42"), 2.0, true)
		"steppe_station":
			for i in 4:
				var horse := barracks_position + Vector2(17 + i * 15, 72 + (i % 2) * 4)
				draw_rect(Rect2(horse - Vector2(6, 3), Vector2(13, 7)), Color("#77614b"), true)
				draw_circle(horse + Vector2(7, -2), 3.5, Color("#5e4b3b"))
				draw_line(horse + Vector2(-4, 3), horse + Vector2(-4, 9), Color("#4b4035"), 1.2)
				draw_line(horse + Vector2(4, 3), horse + Vector2(4, 9), Color("#4b4035"), 1.2)
		"brick_bastion":
			for x in range(389, 522, 18):
				draw_rect(Rect2(x, 240, 12, 16), Color("#5d6060"), false, 2.0)
			for x in [405.0, 507.0]:
				draw_circle(Vector2(x, 236), 4.0, Color("#3f4242"))
				draw_line(Vector2(x + 2, 235), Vector2(x + 14, 231), Color("#887055"), 2.5, true)
		"banner_bastion":
			for x in [399.0, 451.0, 503.0]:
				draw_rect(Rect2(x - 7, 238, 14, 18), Color("#61656a"), false, 2.0)
				draw_circle(Vector2(x, 234), 4.2, Color("#343c49"))
				draw_line(Vector2(x + 2, 233), Vector2(x + 15, 229), Color("#8b7456"), 2.5, true)
			draw_line(Vector2(392, 258), Vector2(520, 258), Color("#405266"), 2.0, true)
