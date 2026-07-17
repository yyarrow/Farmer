extends Control

const UiFont = preload("res://src/ui_font.gd")
const CityLayout = preload("res://src/data/city_layout.gd")
const POSITIONS := CityLayout.BUILDING_POSITIONS
const SIZES := CityLayout.BUILDING_SIZES
const EFFECT_POSITIONS := CityLayout.EFFECT_POSITIONS

var building_views := {}
var displayed_stages := {}
var displayed_levels := {}
var veteran_banners := {}
var master_banners := {}
var world_state := {}
var effects: Array[Dictionary] = []
var _effect_font: Font
var _production_accum := 0.0
var _world_time := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_effect_font = UiFont.medium()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 884422
	_build_views()
	State.changed.connect(_refresh_buildings)
	State.visual_event.connect(play_event)
	_refresh_buildings()
	set_process(true)

func _build_views() -> void:
	for id in POSITIONS:
		var view := TextureRect.new()
		view.position = POSITIONS[id]
		view.size = SIZES[id]
		view.pivot_offset = view.size * 0.5
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.modulate = Color(1.0, 1.0, 1.0, 0.94)
		add_child(view)
		building_views[id] = view
	for id in POSITIONS:
		veteran_banners[id] = _make_banner(id, false)
		master_banners[id] = _make_banner(id, true)

func _make_banner(id: String, is_master: bool) -> Node2D:
	var root := Node2D.new()
	var offset_x := 0.82 if not is_master else 0.62
	root.position = POSITIONS[id] + Vector2(SIZES[id].x * offset_x, SIZES[id].y * 0.30)
	root.z_index = 4
	root.visible = false
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -24 if not is_master else -20)])
	pole.width = 2.0
	pole.default_color = Color("#5b4028")
	pole.antialiased = true
	root.add_child(pole)
	var flag := Polygon2D.new()
	var height := -24.0 if not is_master else -20.0
	flag.polygon = PackedVector2Array([Vector2(0, height), Vector2(15, height + 5), Vector2(0, height + 11)])
	flag.color = Color("#a94b3f") if not is_master else Color("#d4aa4f")
	root.add_child(flag)
	add_child(root)
	return root

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
	for id in building_views:
		var level := int(State.buildings[id])
		var stage := _stage_for_level(level)
		if displayed_stages.get(id, -1) != stage:
			displayed_stages[id] = stage
			building_views[id].texture = _atlas_for(id, stage)
		if displayed_levels.get(id, -1) != level:
			displayed_levels[id] = level
			building_views[id].scale = Vector2.ONE * _scale_for_level(level)
		var era_tint: Color = Color.WHITE.lerp(State.get_era_tint(), 0.38)
		era_tint.a = 0.94
		building_views[id].modulate = era_tint
		veteran_banners[id].visible = level >= 3
		master_banners[id].visible = level >= 5
	_refresh_world_state()

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

func _stage_for_level(level: int) -> int:
	if level <= 0:
		return 0
	if level == 1:
		return 1
	if level <= 3:
		return 2
	return 3

func _scale_for_level(level: int) -> float:
	return [0.82, 0.90, 0.97, 1.02, 1.08, 1.14][clampi(level, 0, 5)]

func _atlas_for(id: String, stage: int) -> AtlasTexture:
	var texture = load("res://assets/art/buildings/%s_stages.png" % id)
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
			_animate_building(str(payload.get("building", "")), true)
		"upgrade":
			color = Color("#f1d572")
			glyph = "焕新"
			_animate_building(str(payload.get("building", "")), false)
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
	if payload.has("building") and POSITIONS.has(payload.building):
		return POSITIONS[payload.building] + SIZES[payload.building] * 0.5
	if kind.begins_with("siege"):
		return EFFECT_POSITIONS.siege
	return EFFECT_POSITIONS.get(kind, Vector2(270, 350))

func _animate_building(id: String, is_new: bool) -> void:
	if not building_views.has(id):
		return
	var view: TextureRect = building_views[id]
	var target_scale := Vector2.ONE * _scale_for_level(int(State.buildings[id]))
	view.scale = Vector2(0.48, 0.48) if is_new else Vector2(0.82, 0.82)
	view.modulate = Color(1.6, 1.35, 0.72, 1.0)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", target_scale, 0.72)
	tween.tween_property(view, "modulate", Color(1, 1, 1, 0.94), 0.72)

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

func _draw() -> void:
	_draw_world_state()
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

func _draw_world_state() -> void:
	if world_state.is_empty():
		return
	_draw_era_identity()
	if bool(world_state.irrigation):
		for row in 3:
			var points := PackedVector2Array()
			for step in 7:
				points.append(POSITIONS.farm + Vector2(23 + step * 12, 30 + row * 9 + sin(_world_time * 2.0 + step) * 1.6))
			draw_polyline(points, Color(0.30, 0.72, 0.77, 0.70), 2.1, true)
	if bool(world_state.all_buff):
		for id in building_views:
			if int(State.buildings[id]) > 0:
				var glow := 0.48 + sin(_world_time * 2.2 + POSITIONS[id].x) * 0.18
				draw_circle(POSITIONS[id] + Vector2(SIZES[id].x * 0.72, SIZES[id].y * 0.25), 2.6, Color(0.95, 0.80, 0.38, glow))
	for i in int(world_state.civilian_markers):
		if i == 0:
			draw_circle(POSITIONS.house + Vector2(36, 82), 17.0, Color(0.16, 0.13, 0.09, 0.22))
		var civilian_pos := POSITIONS.house + Vector2(25 + (i % 3) * 11, 76 + int(i / 3) * 11)
		draw_circle(civilian_pos, 3.0, Color("#e1ad62"))
		draw_line(civilian_pos + Vector2(0, 3), civilian_pos + Vector2(0, 9), Color("#76543b"), 1.6)
	for i in int(world_state.soldier_markers):
		if i == 0:
			draw_circle(POSITIONS.barracks + Vector2(16, 124), 18.0, Color(0.12, 0.10, 0.08, 0.26))
		var offset := Vector2(5 + (i % 3) * 10, 117 + int(i / 3) * 11)
		match str(world_state.defense_order):
			"fortify": offset = Vector2(7 + (i % 2) * 9, 115 + int(i / 2) * 8)
			"volley": offset = Vector2(3 + i * 6, 116 + (i % 2) * 7)
			"sally": offset = Vector2(4 + int(i / 2) * 9, 113 + abs(i % 2 - 1) * 8)
		var soldier_pos := POSITIONS.barracks + offset
		draw_circle(soldier_pos, 3.0, Color("#b75042"))
		draw_line(soldier_pos + Vector2(0, 3), soldier_pos + Vector2(0, 10), Color("#654034"), 1.8)
		draw_line(soldier_pos + Vector2(3, 6), soldier_pos + Vector2(7, -2), Color("#c7aa68"), 1.2)
	var order_id := str(world_state.defense_order)
	var order: Dictionary = State.DEFENSE_ORDERS.get(order_id, State.DEFENSE_ORDERS.steady)
	var banner_base := POSITIONS.barracks + Vector2(43, 126)
	var banner_color: Color = {"steady": Color("#c59b52"), "fortify": Color("#55745d"), "volley": Color("#69718a"), "sally": Color("#a54a3d")}.get(order_id, Color("#c59b52"))
	draw_line(banner_base, banner_base + Vector2(0, -31), Color("#4b3b2d"), 2.0)
	draw_colored_polygon(PackedVector2Array([banner_base + Vector2(1, -30), banner_base + Vector2(22, -25), banner_base + Vector2(1, -17)]), banner_color)
	draw_string(_effect_font, banner_base + Vector2(5, -19), str(order.glyph), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f7ebc9"))
	if int(world_state.wounded_markers) > 0:
		var tent := POSITIONS.barracks + Vector2(48, 123)
		draw_colored_polygon(PackedVector2Array([tent, tent + Vector2(13, -13), tent + Vector2(26, 0)]), Color(0.84, 0.76, 0.58, 0.90))
		draw_line(tent + Vector2(13, -13), tent + Vector2(13, 0), Color("#81483b"), 1.6)
	if bool(world_state.enemy_warning):
		var warning := POSITIONS.wall + Vector2(105, 90)
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
	var command_base := POSITIONS.barracks + Vector2(18, 116)
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
				var horse := POSITIONS.barracks + Vector2(20 + i * 15, 139 + (i % 2) * 4)
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
