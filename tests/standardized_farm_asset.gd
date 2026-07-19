extends SceneTree

const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")
const ATLAS_PATH := "res://assets/art/buildings/eras/warring_states/farm_stages_standardized.png"
const FRAME_SIZE := Vector2i(384, 384)
const ALPHA_THRESHOLD := 0.06

var failures: Array[String] = []

func _initialize() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_check(not atlas.is_empty(), "standardized farm atlas can be loaded")
	if atlas.is_empty():
		_finish()
		return
	_check(atlas.get_size() == FRAME_SIZE * 2, "standardized farm atlas is a 2x2 stage sheet")
	var expected_quad := FootprintTemplates.source_quad(Vector2i(3, 3))
	for stage in 4:
		var origin := Vector2i((stage % 2) * FRAME_SIZE.x, int(stage / 2) * FRAME_SIZE.y)
		var frame := atlas.get_region(Rect2i(origin, FRAME_SIZE))
		var bounds := _alpha_bounds(frame)
		_check(absi(bounds.position.x - 30) <= 2, "stage %d left edge matches the canonical plot" % (stage + 1))
		_check(absi((bounds.end.x - 1) - 354) <= 2, "stage %d right edge matches the canonical plot" % (stage + 1))
		_check(absi((bounds.end.y - 1) - 350) <= 2, "stage %d front edge matches the canonical socket" % (stage + 1))
		for corner in expected_quad:
			var distance := _nearest_alpha_distance(frame, corner)
			_check(distance <= 15.0, "stage %d paints canonical corner %s (nearest %.1fpx)" % [stage + 1, corner, distance])
	_finish()

func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	return Rect2i() if max_x < 0 else Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _nearest_alpha_distance(image: Image, point: Vector2) -> float:
	var nearest_squared := INF
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				nearest_squared = minf(nearest_squared, Vector2(x, y).distance_squared_to(point))
	return sqrt(nearest_squared)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("STANDARDIZED_FARM_ASSET_OK stages=4 corners=16")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
