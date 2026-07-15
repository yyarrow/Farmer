extends Control

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
	"policy": Vector2(270, 330),
	"siege": Vector2(425, 205),
	"shortage": Vector2(270, 460),
}

var building_views := {}
var displayed_stages := {}
var displayed_levels := {}
var veteran_banners := {}
var master_banners := {}
var effects: Array[Dictionary] = []
var _production_accum := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
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
	var glyph := "✦"
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
			_spawn_caravan()
		"recruit":
			color = Color("#a94d3f")
			glyph = "列阵"
			_spawn_soldiers()
		"policy":
			color = Color("#6d9476")
			glyph = "政通人和"
		"event", "event_choice":
			color = Color("#cf9944")
			glyph = "风云有变"
		"patrol_win", "siege_win":
			color = Color("#e3c96f")
			glyph = "凯旋"
		"patrol_loss", "siege_loss":
			color = Color("#a34237")
			glyph = "烽烟"
			_spawn_smoke(position)
		"shortage":
			color = Color("#b65243")
			glyph = "物资不足"
		"chapter":
			color = Color("#e6c56f")
			glyph = "城邑焕新"
			_flash_all_buildings()
		"load", "new_game":
			_refresh_buildings()
			glyph = "整顿城邑"
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

func _spawn_caravan() -> void:
	for i in 3:
		effects.append({"kind": "caravan", "pos": Vector2(-30 - i * 24, 422 + i * 5), "vel": Vector2(92, -5), "life": 2.5, "max_life": 2.5, "color": Color("#c68f45"), "size": 5.0})

func _spawn_soldiers() -> void:
	for i in 6:
		effects.append({"kind": "soldier", "pos": Vector2(368 + (i % 3) * 11, 300 + int(i / 3) * 12), "vel": Vector2(30, -15), "life": 2.0, "max_life": 2.0, "color": Color("#a64b3d"), "size": 4.0})

func _spawn_smoke(position: Vector2) -> void:
	for i in 14:
		effects.append({"kind": "smoke", "pos": position + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-8, 8)), "vel": Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-24, -12)), "life": _rng.randf_range(1.4, 2.6), "max_life": 2.6, "color": Color("#4a4038"), "size": _rng.randf_range(5.0, 10.0)})

func _draw() -> void:
	for effect in effects:
		var alpha := clampf(effect.life / effect.max_life, 0.0, 1.0)
		var color: Color = effect.color
		color.a = alpha * 0.9
		match effect.kind:
			"mote":
				draw_circle(effect.pos, effect.size, color)
				draw_line(effect.pos - Vector2(effect.size, 0), effect.pos + Vector2(effect.size, 0), color.lightened(0.25), 1.0)
			"label":
				draw_string(ThemeDB.fallback_font, effect.pos, effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
			"caravan":
				draw_rect(Rect2(effect.pos, Vector2(18, 9)), color, true)
				draw_circle(effect.pos + Vector2(4, 11), 3, Color(0.18, 0.15, 0.11, alpha))
				draw_circle(effect.pos + Vector2(15, 11), 3, Color(0.18, 0.15, 0.11, alpha))
				draw_line(effect.pos + Vector2(18, 3), effect.pos + Vector2(26, -2), color.lightened(0.15), 2)
			"soldier":
				draw_circle(effect.pos, 3.2, color)
				draw_line(effect.pos + Vector2(0, 3), effect.pos + Vector2(0, 12), color, 2)
				draw_line(effect.pos + Vector2(3, 6), effect.pos + Vector2(8, -5), color.lightened(0.3), 1.5)
			"smoke":
				draw_circle(effect.pos, effect.size * (1.2 - alpha * 0.3), Color(color, alpha * 0.34))
