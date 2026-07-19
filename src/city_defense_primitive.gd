extends Node2D

var kind := ""
var data := {}
var palette := {}
var texture: Texture2D

func configure_segment(segment: Dictionary, style: Dictionary, colors: Dictionary) -> void:
	kind = "segment"
	palette = colors.duplicate()
	var from: Vector2 = segment.screen_from
	var to: Vector2 = segment.screen_to
	position = (from + to) * 0.5
	z_index = int(segment.sort_depth)
	data = {
		"from": from - position,
		"to": to - position,
		"tier": int(style.wall_tier),
	}
	queue_redraw()

func configure_tower(tower: Dictionary, colors: Dictionary) -> void:
	kind = "tower"
	palette = colors.duplicate()
	position = Vector2(tower.screen)
	z_index = int(tower.sort_depth)
	data = {"tier": int(tower.tier)}
	queue_redraw()

func configure_gate(
	gate_texture: Texture2D,
	source_rect: Rect2,
	frame_rect: Rect2,
	ground_anchor: Vector2,
	level: int,
	colors: Dictionary,
	sort_depth: int
) -> void:
	kind = "gate"
	texture = gate_texture
	palette = colors.duplicate()
	position = frame_rect.position
	z_index = sort_depth
	data = {
		"source_rect": source_rect,
		"frame_rect": Rect2(Vector2.ZERO, frame_rect.size),
		"ground_anchor": ground_anchor - position,
		"level": level,
	}
	queue_redraw()

func _draw() -> void:
	match kind:
		"segment": _draw_segment()
		"tower": _draw_tower()
		"gate": _draw_gate()

func _draw_segment() -> void:
	var tier := int(data.tier)
	var width := 2.0 + float(tier) * 0.72
	var from: Vector2 = data.from
	var to: Vector2 = data.to
	draw_line(from + Vector2(0, 2), to + Vector2(0, 2), Color(palette.shadow), width + 2.0, true)
	draw_line(from, to, Color(palette.body), width, true)
	draw_line(from + Vector2(0, -1.2), to + Vector2(0, -1.2), Color(palette.top), maxf(1.0, width * 0.25), true)

func _draw_tower() -> void:
	var tier := int(data.tier)
	var size := 4.0 + float(tier) * 1.2
	var height := 4.0 + float(tier) * 2.0
	var base := PackedVector2Array([
		Vector2(0, -size * 0.5), Vector2(size, 0),
		Vector2(0, size * 0.5), Vector2(-size, 0),
	])
	draw_colored_polygon(base, Color(palette.shadow))
	var upper := PackedVector2Array()
	for point in base:
		upper.append(point - Vector2(0, height))
	draw_colored_polygon(PackedVector2Array([base[3], base[2], upper[2], upper[3]]), Color(palette.body).darkened(0.14))
	draw_colored_polygon(PackedVector2Array([base[2], base[1], upper[1], upper[2]]), Color(palette.body))
	draw_colored_polygon(upper, Color(palette.top))
	draw_polyline(upper, Color(palette.shadow), 1.2, true)

func _draw_gate() -> void:
	if texture:
		draw_texture_rect_region(texture, data.frame_rect, data.source_rect)
		return
	var anchor: Vector2 = data.ground_anchor
	var gate_width := 22.0
	var gate_height := 12.0 + int(data.level) * 2.0
	draw_rect(Rect2(anchor - Vector2(gate_width * 0.5, gate_height), Vector2(gate_width, gate_height)), Color(palette.body))
	draw_rect(Rect2(anchor - Vector2(4, gate_height - 4), Vector2(8, gate_height - 4)), Color(palette.shadow))
