extends SceneTree

const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")
const FRAME_SIZE := Vector2i(384, 384)
const ALPHA_THRESHOLD := 0.06
const BUILDINGS := {
	"woodcut": Vector2i(2, 2),
	"quarry": Vector2i(2, 2),
	"house": Vector2i(2, 2),
}

var failures: Array[String] = []

func _initialize() -> void:
	for building_type in BUILDINGS:
		_check_asset(building_type, BUILDINGS[building_type])
	_finish()

func _check_asset(building_type: String, footprint: Vector2i) -> void:
	var path := "res://assets/art/buildings/eras/warring_states/%s_stages_standardized.png" % building_type
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(path))
	_check(not atlas.is_empty(), "%s standardized atlas loads" % building_type)
	if atlas.is_empty():
		return
	_check(atlas.get_size() == FRAME_SIZE * 2, "%s atlas is a 2x2 stage sheet" % building_type)
	var expected_quad := FootprintTemplates.source_quad(footprint)
	for stage in 4:
		var origin := Vector2i((stage % 2) * FRAME_SIZE.x, int(stage / 2) * FRAME_SIZE.y)
		var frame := atlas.get_region(Rect2i(origin, FRAME_SIZE))
		var bounds := _alpha_bounds(frame)
		_check(bounds.size != Vector2i.ZERO, "%s stage %d is visible" % [building_type, stage + 1])
		_check(bounds.position.x >= 4 and bounds.end.x <= FRAME_SIZE.x - 4, "%s stage %d keeps horizontal render padding" % [building_type, stage + 1])
		_check(bounds.position.y >= 4 and bounds.end.y <= FRAME_SIZE.y - 4, "%s stage %d keeps vertical render padding" % [building_type, stage + 1])
		for corner_index in expected_quad.size():
			var corner := expected_quad[corner_index]
			var distance := _nearest_alpha_distance(frame, corner)
			var tolerance := 15.0 if corner_index == 0 else 5.0
			_check(distance <= tolerance, "%s stage %d paints canonical corner %s (nearest %.1fpx)" % [building_type, stage + 1, corner, distance])

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
		print("STANDARDIZED_BUILDING_ASSETS_OK buildings=%d stages=%d corners=%d" % [
			BUILDINGS.size(), BUILDINGS.size() * 4, BUILDINGS.size() * 16,
		])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
