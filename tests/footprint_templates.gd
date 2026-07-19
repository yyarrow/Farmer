extends SceneTree

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var templates := [Vector2i(2, 2), Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 2)]
	for footprint in templates:
		var source := FootprintTemplates.source_quad(footprint)
		var source_bounds := _bounds(source)
		_check(absf(source_bounds.size.x - 324.0) < 0.01, "%s source width is canonical" % footprint)
		_check(absf(source_bounds.size.y - 162.0) < 0.01, "%s source height keeps 2:1 projection" % footprint)
		_check(source_bounds.position.x >= 29.9 and source_bounds.end.x <= 354.1, "%s source keeps horizontal safe margin" % footprint)
		_check(absf(source[2].y - 350.0) < 0.01, "%s front socket uses canonical baseline" % footprint)

		var expected := PlacementEngine.grid_rect_polygon(Vector2i(4, 3), footprint)
		var anchor := expected[2]
		var socket := FootprintTemplates.source_socket(footprint)
		var scale := FootprintTemplates.screen_scale(footprint)
		for index in 4:
			var mapped := anchor + (source[index] - socket) * scale
			_check(mapped.distance_to(expected[index]) < 0.01, "%s corner %d maps exactly to game grid" % [footprint, index])
	if failures.is_empty():
		print("FOOTPRINT_TEMPLATES_OK templates=%d corners=%d" % [templates.size(), templates.size() * 4])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
