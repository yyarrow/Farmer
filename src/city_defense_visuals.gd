extends Node2D

const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")
const ArtAlignment = preload("res://src/city_placement/art_alignment.gd")
const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")

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

func configure(level: int, next_era_id := "warring_states", colors := {}, next_unlocked_count := 12) -> void:
	defense_level = clampi(level, 0, DefenseLayout.MAX_LEVEL)
	era_id = next_era_id
	unlocked_count = next_unlocked_count
	palette = DEFAULT_PALETTE.duplicate()
	for key in colors:
		palette[key] = colors[key]
	_gate_texture = _load_gate_texture()
	queue_redraw()

func _draw() -> void:
	if defense_level <= 0:
		return
	var style := DefenseLayout.level_style(defense_level)
	var body: Color = palette.body
	var shadow: Color = palette.shadow
	var top: Color = palette.top
	var width := 2.0 + float(style.wall_tier) * 0.72

	# This compact node is an isolated preview renderer. Production integration
	# must instantiate wall/tower primitives with DefenseLayout.sort_depth so the
	# front wall can occlude objects while rear walls remain behind them.
	for side in ["north", "east", "west", "south"]:
		for segment in DefenseLayout.wall_segments(defense_level, unlocked_count):
			if str(segment.side) != side:
				continue
			var from: Vector2 = segment.screen_from
			var to: Vector2 = segment.screen_to
			draw_line(from + Vector2(0, 2), to + Vector2(0, 2), shadow, width + 2.0, true)
			draw_line(from, to, body, width, true)
			draw_line(from + Vector2(0, -1.2), to + Vector2(0, -1.2), top, maxf(1.0, width * 0.25), true)

	for tower in DefenseLayout.tower_nodes(defense_level, unlocked_count):
		_draw_tower(tower.screen, int(tower.tier))
	_draw_gate()

func _draw_tower(anchor: Vector2, tier: int) -> void:
	var size := 4.0 + float(tier) * 1.2
	var height := 4.0 + float(tier) * 2.0
	var base := PackedVector2Array([
		anchor + Vector2(0, -size * 0.5),
		anchor + Vector2(size, 0),
		anchor + Vector2(0, size * 0.5),
		anchor + Vector2(-size, 0),
	])
	draw_colored_polygon(base, palette.shadow)
	var upper := PackedVector2Array()
	for point in base:
		upper.append(point - Vector2(0, height))
	draw_colored_polygon(PackedVector2Array([base[3], base[2], upper[2], upper[3]]), palette.body.darkened(0.14))
	draw_colored_polygon(PackedVector2Array([base[2], base[1], upper[1], upper[2]]), palette.body)
	draw_colored_polygon(upper, palette.top)
	draw_polyline(upper, palette.shadow, 1.2, true)

func _draw_gate() -> void:
	var layout := gate_render_layout()
	if _gate_texture:
		draw_texture_rect_region(_gate_texture, layout.frame_rect, layout.source_rect)
		return
	# Deterministic fallback keeps the gate readable before era art is imported.
	var anchor: Vector2 = layout.ground_anchor
	var gate_width := 22.0
	var gate_height := 12.0 + defense_level * 2.0
	draw_rect(Rect2(anchor - Vector2(gate_width * 0.5, gate_height), Vector2(gate_width, gate_height)), palette.body)
	draw_rect(Rect2(anchor - Vector2(4, gate_height - 4), Vector2(8, gate_height - 4)), palette.shadow)

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
