extends Node2D

const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")
const ArtAlignment = preload("res://src/city_placement/art_alignment.gd")
const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")
const DefensePrimitive = preload("res://src/city_defense_primitive.gd")

const FRAME_SIZE := Vector2(384, 384)
const GATE_FOOTPRINT := Vector2i(4, 2)
const DEFAULT_PALETTE := {
	"shadow": Color("#49382b"),
	"body": Color("#806442"),
	"top": Color("#c4a66b"),
	"accent": Color("#a84737"),
}

var defense_level := 0
var era_id := "warring_states"
var unlocked_count := 12
var palette := DEFAULT_PALETTE.duplicate()
var _gate_texture: Texture2D
var _upgrade_tween: Tween

func configure(level: int, next_era_id := "warring_states", colors := {}, next_unlocked_count := 12) -> void:
	defense_level = clampi(level, 0, DefenseLayout.MAX_LEVEL)
	era_id = next_era_id
	unlocked_count = next_unlocked_count
	palette = DEFAULT_PALETTE.duplicate()
	for key in colors:
		palette[key] = colors[key]
	_gate_texture = _load_gate_texture()
	_rebuild_primitives()

func _rebuild_primitives() -> void:
	for child in get_children():
		child.queue_free()
	if defense_level <= 0:
		return
	var style := DefenseLayout.level_style(defense_level)
	for segment in DefenseLayout.wall_segments(defense_level, unlocked_count):
		var primitive := DefensePrimitive.new()
		primitive.configure_segment(segment, style, palette)
		add_child(primitive)
	for tower in DefenseLayout.tower_nodes(defense_level, unlocked_count):
		var primitive := DefensePrimitive.new()
		primitive.configure_tower(tower, palette)
		add_child(primitive)
	var layout := gate_render_layout()
	var gate := DefensePrimitive.new()
	gate.configure_gate(
		_gate_texture, layout.source_rect, layout.frame_rect, layout.ground_anchor,
		defense_level, palette, int(layout.sort_depth)
	)
	add_child(gate)

func play_upgrade() -> void:
	if _upgrade_tween and _upgrade_tween.is_valid():
		_upgrade_tween.kill()
	modulate = Color("#ffe29a")
	_upgrade_tween = create_tween()
	_upgrade_tween.tween_property(self, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD)
	_upgrade_tween.tween_property(self, "modulate", Color("#fff0bd"), 0.12)
	_upgrade_tween.tween_property(self, "modulate", Color.WHITE, 0.30).set_trans(Tween.TRANS_SINE)

func gate_render_layout() -> Dictionary:
	var gate: Dictionary = DefenseLayout.primary_gate(unlocked_count)
	var anchor: Vector2 = gate.screen_anchor
	var stage := clampi(defense_level - 1, 0, 3)
	var source := gate_source_rect(stage)
	var display_size := FootprintTemplates.frame_display_size(GATE_FOOTPRINT)
	var frame_layout: Dictionary
	if _uses_standardized_gate():
		frame_layout = standardized_gate_layout(stage, anchor)
	else:
		frame_layout = ArtAlignment.frame_layout(_gate_texture, stage, display_size, anchor)
	return {
		"stage": stage,
		"source_rect": source,
		"frame_rect": frame_layout.frame_rect,
		"ground_anchor": anchor,
		"ground_socket": frame_layout.ground_socket,
		"sort_depth": int(gate.sort_depth),
		"standardized": _uses_standardized_gate(),
	}

static func gate_source_rect(stage: int) -> Rect2:
	var safe_stage := clampi(stage, 0, 3)
	return Rect2(Vector2(safe_stage % 2, int(safe_stage / 2)) * FRAME_SIZE, FRAME_SIZE)

static func standardized_gate_layout(stage: int, ground_anchor: Vector2) -> Dictionary:
	var display_size := FootprintTemplates.frame_display_size(GATE_FOOTPRINT)
	var source_socket := FootprintTemplates.source_socket(GATE_FOOTPRINT)
	var scale := Vector2(display_size.x / FRAME_SIZE.x, display_size.y / FRAME_SIZE.y)
	return {
		"stage": clampi(stage, 0, 3),
		"source_rect": gate_source_rect(stage),
		"frame_rect": Rect2(ground_anchor - source_socket * scale, display_size),
		"ground_socket": source_socket * scale,
		"visible_contact": ground_anchor,
	}

func _load_gate_texture() -> Texture2D:
	var standardized := "res://assets/art/buildings/eras/%s/wall_stages_standardized.png" % era_id
	if ResourceLoader.exists(standardized):
		return load(standardized)
	var legacy := "res://assets/art/buildings/eras/%s/wall_stages.png" % era_id
	if ResourceLoader.exists(legacy):
		return load(legacy)
	return null

func _uses_standardized_gate() -> bool:
	return ResourceLoader.exists("res://assets/art/buildings/eras/%s/wall_stages_standardized.png" % era_id)
