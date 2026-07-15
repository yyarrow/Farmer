extends Control

const UiFont = preload("res://src/ui_font.gd")
const POSITIONS := {
	"wall": Vector2(386, 154),
	"barracks": Vector2(326, 217),
	"warehouse": Vector2(226, 268),
	"market": Vector2(78, 323),
	"house": Vector2(330, 348),
	"woodcut": Vector2(35, 209),
	"quarry": Vector2(395, 407),
	"farm": Vector2(83, 432),
}
const SIZES := {
	"wall": Vector2(132, 112),
	"barracks": Vector2(126, 112),
	"warehouse": Vector2(112, 102),
	"market": Vector2(118, 100),
	"house": Vector2(118, 104),
	"woodcut": Vector2(116, 104),
	"quarry": Vector2(116, 104),
	"farm": Vector2(126, 106),
}
const EFFECT_POSITIONS := {
	"trade": Vector2(150, 405),
	"recruit": Vector2(380, 275),
	"policy": Vector2(270, 410),
	"siege": Vector2(425, 205),
	"shortage": Vector2(270, 460),
	"storage_full": Vector2(270, 350),
}

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
		veteran_banners[id].visible = level >= 3
		master_banners[id].visible = level >= 5
	_refresh_world_state()

func _refresh_world_state() -> void:
	var army_count := State.get_army_count()
	world_state = {
		"irrigation": State.current_day <= int(State.buffs.get("farm_until", 0)),
		"all_buff": State.current_day <= int(State.buffs.get("all_until", 0)),
		"civilian_markers": clampi(ceili(State.population / 35.0), 1, 5),
		"soldier_markers": clampi(ceili(army_count / 15.0), 0, 6),
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
		"policy":
			color = Color("#6d9476")
			var policy := str(payload.get("policy", ""))
			match policy:
				"irrigate":
					glyph = "清渠通流"
					_spawn_irrigation_flow()
				"tax_relief":
					glyph = "百姓归心"
					_spawn_civilians()
				"reward_army":
					glyph = "三军振奋"
					_spawn_soldiers()
				_: glyph = "政通人和"
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
	var labels := {"farm": "+粟", "woodcut": "+木", "quarry": "+石", "market": "+铢"}
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
	var glyphs := {"grain": "粟", "wood": "木", "stone": "石", "coins": "财"}
	for resource in sources:
		if not ledger.has(resource):
			continue
		var net := float(ledger[resource].get("net", 0.0))
		if absf(net) < 0.05:
			continue
		var source: String = sources[resource]
		var tint := Color("#ead07b") if net >= 0.0 else Color("#b95b4b")
		effects.append({"kind": "label", "pos": POSITIONS[source] + SIZES[source] * 0.48, "vel": Vector2(0, -13), "life": 1.65, "max_life": 1.65, "color": tint, "text": "%s%+.0f" % [glyphs[resource], net]})
	var recovered := int(payload.get("recovered", 0))
	var day_label := "日结" if recovered <= 0 else "%d人归队" % recovered
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
		var soldier_pos := POSITIONS.barracks + Vector2(5 + (i % 3) * 10, 117 + int(i / 3) * 11)
		draw_circle(soldier_pos, 3.0, Color("#b75042"))
		draw_line(soldier_pos + Vector2(0, 3), soldier_pos + Vector2(0, 10), Color("#654034"), 1.8)
		draw_line(soldier_pos + Vector2(3, 6), soldier_pos + Vector2(7, -2), Color("#c7aa68"), 1.2)
	if int(world_state.wounded_markers) > 0:
		var tent := POSITIONS.barracks + Vector2(48, 123)
		draw_colored_polygon(PackedVector2Array([tent, tent + Vector2(13, -13), tent + Vector2(26, 0)]), Color(0.84, 0.76, 0.58, 0.90))
		draw_line(tent + Vector2(13, -13), tent + Vector2(13, 0), Color("#81483b"), 1.6)
	if bool(world_state.enemy_warning):
		var warning := POSITIONS.wall + Vector2(105, 90)
		var pulse := 0.68 + sin(_world_time * (5.0 if bool(world_state.enemy_urgent) else 2.0)) * 0.22
		draw_line(warning, warning + Vector2(0, -25), Color("#533a30"), 2.0)
		draw_colored_polygon(PackedVector2Array([warning + Vector2(0, -25), warning + Vector2(15, -20), warning + Vector2(0, -14)]), Color(0.64, 0.20, 0.17, pulse))
