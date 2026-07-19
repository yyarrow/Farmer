extends RefCounted

# Isometric art is positioned by its visible ground contact, not by the
# transparent frame edge. Measurements are cached per imported texture/frame.
const ALPHA_THRESHOLD := 0.06
const MIN_CONTACT_PIXELS := 2

static var _metrics_cache := {}

static func frame_metrics(texture: Texture2D, stage: int) -> Dictionary:
	if texture == null:
		return {}
	var safe_stage := clampi(stage, 0, 3)
	var cache_key := "%d:%d" % [texture.get_instance_id(), safe_stage]
	if _metrics_cache.has(cache_key):
		return _metrics_cache[cache_key]
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {}
	var frame_size := Vector2i(image.get_width() / 2, image.get_height() / 2)
	if frame_size.x <= 0 or frame_size.y <= 0:
		return {}
	var frame_origin := Vector2i((safe_stage % 2) * frame_size.x, int(safe_stage / 2) * frame_size.y)
	var frame := image.get_region(Rect2i(frame_origin, frame_size))
	var opaque_rect := frame.get_used_rect()
	if opaque_rect.size == Vector2i.ZERO:
		opaque_rect = Rect2i(Vector2i.ZERO, frame_size)
	var contact_bottom := _find_contact_bottom(frame, opaque_rect)
	contact_bottom = clampi(contact_bottom, opaque_rect.position.y + 1, frame_size.y)
	opaque_rect.size.y = contact_bottom - opaque_rect.position.y
	var metrics := {
		"source_size": Vector2(frame_size),
		"opaque_rect": Rect2(opaque_rect),
		"ground_socket": Vector2(frame_size.x * 0.5, contact_bottom),
		"bottom_padding": frame_size.y - contact_bottom,
	}
	_metrics_cache[cache_key] = metrics
	return metrics

static func frame_layout(
	texture: Texture2D,
	stage: int,
	display_size: Vector2,
	ground_anchor: Vector2,
	explicit_source_socket := Vector2(-1, -1)
) -> Dictionary:
	var metrics := frame_metrics(texture, stage)
	if metrics.is_empty():
		var fallback := Rect2(ground_anchor - Vector2(display_size.x * 0.5, display_size.y), display_size)
		return {
			"frame_rect": fallback,
			"visible_rect": fallback,
			"ground_socket": Vector2(display_size.x * 0.5, display_size.y),
			"visible_contact": ground_anchor,
		}
	var source_size := Vector2(metrics.source_size)
	var scale := Vector2(display_size.x / source_size.x, display_size.y / source_size.y)
	var source_socket := (
		Vector2(explicit_source_socket)
		if Vector2(explicit_source_socket).x >= 0.0 and Vector2(explicit_source_socket).y >= 0.0
		else Vector2(metrics.ground_socket)
	)
	var screen_socket := source_socket * scale
	var frame_rect := Rect2(ground_anchor - screen_socket, display_size)
	var source_visible := Rect2(metrics.opaque_rect)
	var visible_rect := Rect2(
		frame_rect.position + source_visible.position * scale,
		source_visible.size * scale
	)
	return {
		"frame_rect": frame_rect,
		"visible_rect": visible_rect,
		"ground_socket": screen_socket,
		"visible_contact": frame_rect.position + screen_socket,
	}

static func clear_cache() -> void:
	_metrics_cache.clear()

static func _find_contact_bottom(frame: Image, used: Rect2i) -> int:
	var x_end := mini(used.end.x, frame.get_width())
	var y_start := mini(used.end.y, frame.get_height()) - 1
	for y in range(y_start, used.position.y - 1, -1):
		var opaque_pixels := 0
		for x in range(maxi(0, used.position.x), x_end):
			if frame.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				opaque_pixels += 1
				if opaque_pixels >= MIN_CONTACT_PIXELS:
					return y + 1
	return used.end.y
