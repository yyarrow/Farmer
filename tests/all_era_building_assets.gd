extends SceneTree

const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")

const FRAME_SIZE := Vector2i(384, 384)
const ALPHA_THRESHOLD := 0.06
const EDGE_MARGIN := 4
const MANIFEST_PATH := "res://assets/art/buildings/standardization_manifest.json"
const ERAS := [
	"spring_autumn", "warring_states", "qin", "han", "three_kingdoms", "jin",
	"northern_southern", "sui", "tang", "five_dynasties", "song", "yuan", "ming", "qing",
]
const BUILDINGS := {
	"woodcut": Vector2i(2, 2),
	"quarry": Vector2i(2, 2),
	"house": Vector2i(2, 2),
	"market": Vector2i(3, 2),
	"warehouse": Vector2i(3, 2),
	"barracks": Vector2i(3, 3),
	"farm": Vector2i(3, 3),
	"wall": Vector2i(4, 2),
}

var _failures: Array[String] = []
var _checked_frames := 0
var _ground_overflow_pixels := 0

func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(manifest is Dictionary, "standardization manifest parses")
	if not manifest is Dictionary:
		_finish()
		return
	_check(int(manifest.get("schema", 0)) == 1, "manifest schema is 1")
	_check(manifest.get("transform", "") == "uniform scale and translation only; never affine stretch", "manifest forbids non-uniform stretch")
	_check(manifest.get("root_fallback_policy", "") == "deprecated; era atlases are authoritative", "root fallback is explicitly deprecated")
	for era_id in _selected_eras():
		_check_era(era_id, manifest.get("assets", {}), _selected_buildings())
	_finish()

func _selected_eras() -> Array[String]:
	var requested := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--era="):
			requested = argument.trim_prefix("--era=")
	if requested == "all":
		var result: Array[String] = []
		for era_id in ERAS:
			result.append(era_id)
		return result
	return [requested]

func _selected_buildings() -> Array[String]:
	var requested := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--buildings="):
			requested = argument.trim_prefix("--buildings=")
	if requested == "all":
		var result: Array[String] = []
		for building_type in BUILDINGS:
			result.append(building_type)
		return result
	var result: Array[String] = []
	for building_type in requested.split(",", false):
		result.append(building_type)
	return result

func _check_era(era_id: String, manifest_assets: Dictionary, selected_buildings: Array[String]) -> void:
	_check(era_id in ERAS, "%s is a known era" % era_id)
	_check(manifest_assets.has(era_id), "%s has a manifest entry" % era_id)
	var era_manifest: Dictionary = manifest_assets.get(era_id, {})
	for building_type in selected_buildings:
		_check(BUILDINGS.has(building_type), "%s is a known building type" % building_type)
		if not BUILDINGS.has(building_type):
			continue
		var footprint: Vector2i = BUILDINGS[building_type]
		var path := "res://assets/art/buildings/eras/%s/%s_stages_standardized.png" % [era_id, building_type]
		if not FileAccess.file_exists(path):
			_check(false, "%s exists" % path)
			continue
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(atlas != null and not atlas.is_empty(), "%s loads" % path)
		if atlas == null or atlas.is_empty():
			continue
		_check(atlas.get_size() == FRAME_SIZE * 2, "%s is a 2x2 384px atlas" % path)
		var record: Dictionary = era_manifest.get(building_type, {})
		var declared_footprint: Array = record.get("footprint", [])
		_check(declared_footprint.size() == 2 and int(declared_footprint[0]) == footprint.x and int(declared_footprint[1]) == footprint.y, "%s declares its canonical footprint" % path)
		_check(record.get("socket", []).size() == 2, "%s declares a ground socket" % path)
		_check(record.get("method", "") in ["authoritative", "deterministic_relayout", "imagegen_regenerated"], "%s declares its production method" % path)
		var stage_scales: Array[float] = []
		for stage_record in record.get("stages", []):
			var scale := float(stage_record.get("uniform_scale", 0.0))
			stage_scales.append(scale)
		if record.get("method", "") == "deterministic_relayout":
			var scale_min := INF
			var scale_max := 0.0
			for scale in stage_scales:
				scale_min = minf(scale_min, scale)
				scale_max = maxf(scale_max, scale)
			_check(stage_scales.size() == 4 and scale_min > 0.0 and absf(scale_max - scale_min) <= 0.0001, "%s preserves one source camera scale across all stages" % path)
		elif record.get("method", "") == "imagegen_regenerated":
			var scale_min := INF
			for scale in stage_scales:
				scale_min = minf(scale_min, scale)
			_check(stage_scales.size() == 4 and scale_min > 0.0, "%s records a uniform per-stage fit" % path)
		for stage in 4:
			_check_frame(atlas, footprint, era_id, building_type, stage)

func _check_frame(atlas: Image, footprint: Vector2i, era_id: String, building_type: String, stage: int) -> int:
	var origin := Vector2i((stage % 2) * FRAME_SIZE.x, int(stage / 2) * FRAME_SIZE.y)
	var frame := atlas.get_region(Rect2i(origin, FRAME_SIZE))
	var bounds := _alpha_bounds(frame)
	var label := "%s/%s stage %d" % [era_id, building_type, stage + 1]
	_check(bounds.size != Vector2i.ZERO, "%s is visible" % label)
	_check(_meaningful_edge_pixels(frame) == 0, "%s has no meaningful frame-edge bleed" % label)
	var quad := FootprintTemplates.source_quad(footprint)
	# A farm exposes its complete lot boundary, so all four painted corners must
	# follow the placement diamond. Other buildings legitimately leave garden or
	# yard space invisible; forcing alpha into every corner would recreate the
	# artificial double-foundation bug this pipeline is intended to remove.
	if building_type == "farm":
		for corner in quad:
			var distance := _nearest_alpha_distance(frame, corner)
			_check(distance <= 22.0, "%s keeps its field contour near %s (nearest %.1fpx)" % [label, corner, distance])
	var socket := (
		Vector2(FRAME_SIZE.x * 0.5, FootprintTemplates.FRONT_Y)
		if building_type == "wall"
		else FootprintTemplates.source_socket(footprint)
	)
	var socket_distance := _nearest_alpha_distance(frame, socket)
	# A gate deliberately leaves its road entrance transparent between the two
	# wall leaves. Its visible contact surrounds the socket instead of painting
	# over it; ordinary buildings still require the exact three-pixel contact.
	var socket_tolerance := 16.0 if building_type == "wall" else 3.0
	var baseline_tolerance := 16.0 if building_type == "wall" else 2.0
	_check(socket_distance <= socket_tolerance, "%s paints its explicit entrance socket (nearest %.1fpx)" % [label, socket_distance])
	_check(absf(float(bounds.end.y - 1) - socket.y) <= baseline_tolerance, "%s grounds its lowest pixel at the socket baseline" % label)
	var bottom_median_x := _bottom_alpha_median_x(frame)
	var median_tolerance := 20.0 if building_type == "wall" else (10.0 if building_type == "farm" else 4.0)
	_check(absf(bottom_median_x - socket.x) <= median_tolerance, "%s centers its ground contact on the socket (median %.1f vs %.1f)" % [label, bottom_median_x, socket.x])
	var overflow := _meaningful_ground_overflow(frame, quad) if building_type == "farm" else 0
	_ground_overflow_pixels += overflow
	# Five source pixels become at most 1.7px in the 128px farm render. This
	# preserves hand-painted field rims while still rejecting detached or
	# materially oversized ground planes.
	_check(overflow <= 5, "%s keeps ground-contact art inside its footprint tolerance (overflow %dpx)" % [label, overflow])
	_checked_frames += 1
	return bounds.size.x

func _meaningful_edge_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if x >= EDGE_MARGIN and x < image.get_width() - EDGE_MARGIN and y >= EDGE_MARGIN and y < image.get_height() - EDGE_MARGIN:
				continue
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				count += 1
	return count

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
	var radius := 48
	var center := Vector2i(roundi(point.x), roundi(point.y))
	for y in range(maxi(0, center.y - radius), mini(image.get_height(), center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(image.get_width(), center.x + radius + 1)):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				nearest_squared = minf(nearest_squared, Vector2(x, y).distance_squared_to(point))
	return sqrt(nearest_squared)

func _bottom_alpha_median_x(image: Image) -> float:
	var bounds := _alpha_bounds(image)
	var x_values := PackedInt32Array()
	for y in range(maxi(bounds.position.y, bounds.end.y - 3), bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				x_values.append(x)
	if x_values.is_empty():
		return -INF
	x_values.sort()
	return x_values[x_values.size() / 2]

func _meaningful_ground_overflow(image: Image, quad: PackedVector2Array) -> int:
	var ground_band_y := floori(minf(quad[1].y, quad[3].y)) - 5
	var overflow := 0
	for y in range(maxi(0, ground_band_y), image.get_height()):
		for x in image.get_width():
			if image.get_pixel(x, y).a < ALPHA_THRESHOLD:
				continue
			var point := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(point, quad):
				continue
			var nearest := INF
			for index in 4:
				var closest := Geometry2D.get_closest_point_to_segment(point, quad[index], quad[(index + 1) % 4])
				nearest = minf(nearest, point.distance_to(closest))
			if nearest > 8.0:
				overflow += 1
	return overflow

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("ALL_ERA_BUILDING_ASSETS_OK frames=%d edge_bleed=0 ground_overflow=%d transform=uniform sockets=explicit" % [_checked_frames, _ground_overflow_pixels])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
