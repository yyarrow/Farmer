extends SceneTree

const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")
const SOURCE_DIR := "res://assets/art/buildings/source/standardized/warring_states"
const OUTPUT_DIR := "res://assets/art/buildings/eras/warring_states"
const PREVIEW_DIR := "res://.qa/building_standardization"
const FRAME_SIZE := Vector2i(384, 384)
const ALPHA_THRESHOLD := 0.06
const EDGE_SAMPLE := 5
const BUILDINGS := {
	"woodcut": Vector2i(2, 2),
	"quarry": Vector2i(2, 2),
	"house": Vector2i(2, 2),
	"market": Vector2i(3, 2),
	"warehouse": Vector2i(3, 2),
	"barracks": Vector2i(3, 3),
	"wall": Vector2i(4, 2),
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIR))
	for building_type in BUILDINGS:
		if not _assemble(building_type, BUILDINGS[building_type]):
			return
	print("STANDARDIZED_BUILDING_ASSEMBLY_OK buildings=%d stages=%d" % [BUILDINGS.size(), BUILDINGS.size() * 4])
	quit(0)

func _assemble(building_type: String, footprint: Vector2i) -> bool:
	var source_path := "%s/%s_atlas_alpha.png" % [SOURCE_DIR, building_type]
	var source_atlas := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if source_atlas.is_empty():
		return _fail("cannot load %s" % source_path)
	var split_x := source_atlas.get_width() / 2
	var split_y := source_atlas.get_height() / 2
	var output := Image.create(FRAME_SIZE.x * 2, FRAME_SIZE.y * 2, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var debug := Image.create(FRAME_SIZE.x * 2, FRAME_SIZE.y * 2, false, Image.FORMAT_RGBA8)
	debug.fill(Color.TRANSPARENT)
	var target_quad := FootprintTemplates.source_quad(footprint)
	for stage in 4:
		var column := stage % 2
		var row := int(stage / 2)
		var region_position := Vector2i(column * split_x, row * split_y)
		var region_size := Vector2i(
			split_x if column == 0 else source_atlas.get_width() - split_x,
			split_y if row == 0 else source_atlas.get_height() - split_y
		)
		var source := source_atlas.get_region(Rect2i(region_position, region_size))
		source = _keep_largest_component(source)
		var bounds := _alpha_bounds(source)
		if bounds.size == Vector2i.ZERO:
			return _fail("%s stage %d has no visible pixels" % [building_type, stage + 1])
		var left := _edge_point(source, bounds, "left")
		var right := _edge_point(source, bounds, "right")
		var bottom := _edge_point(source, bounds, "bottom")
		var top := left + right - bottom
		var frame := _affine_map(source, PackedVector2Array([top, right, bottom, left]), target_quad)
		if frame.is_empty():
			return _fail("%s stage %d cannot be mapped" % [building_type, stage + 1])
		var output_origin := Vector2i(column, row) * FRAME_SIZE
		output.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME_SIZE), output_origin)
		var debug_frame := frame.duplicate()
		_draw_quad(debug_frame, target_quad)
		debug.blit_rect(debug_frame, Rect2i(Vector2i.ZERO, FRAME_SIZE), output_origin)
		var mapped_bounds := _alpha_bounds(frame)
		print("STANDARDIZED_BUILDING_STAGE type=%s stage=%d source=%s ground=%s mapped=%s" % [
			building_type, stage + 1, bounds, PackedVector2Array([top, right, bottom, left]), mapped_bounds,
		])
	var output_path := "%s/%s_stages_standardized.png" % [OUTPUT_DIR, building_type]
	if output.save_png(output_path) != OK:
		return _fail("cannot save %s" % output_path)
	var preview_path := "%s/%s_stages_standardized_debug.png" % [PREVIEW_DIR, building_type]
	if debug.save_png(preview_path) != OK:
		return _fail("cannot save %s" % preview_path)
	return true

func _keep_largest_component(source: Image) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	var labels := PackedInt32Array()
	labels.resize(width * height)
	labels.fill(-1)
	var component_sizes: Array[int] = []
	var next_label := 0
	for y in height:
		for x in width:
			var index := y * width + x
			if labels[index] >= 0 or source.get_pixel(x, y).a < ALPHA_THRESHOLD:
				continue
			var queue := PackedInt32Array([index])
			labels[index] = next_label
			var cursor := 0
			while cursor < queue.size():
				var current := queue[cursor]
				cursor += 1
				var current_x := current % width
				var current_y := int(current / width)
				for offset_y in range(-1, 2):
					for offset_x in range(-1, 2):
						if offset_x == 0 and offset_y == 0:
							continue
						var neighbor_x := current_x + offset_x
						var neighbor_y := current_y + offset_y
						if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= height:
							continue
						var neighbor := neighbor_y * width + neighbor_x
						if labels[neighbor] >= 0 or source.get_pixel(neighbor_x, neighbor_y).a < ALPHA_THRESHOLD:
							continue
						labels[neighbor] = next_label
						queue.append(neighbor)
			component_sizes.append(queue.size())
			next_label += 1
	if component_sizes.is_empty():
		return source
	var largest_label := 0
	for label in range(1, component_sizes.size()):
		if component_sizes[label] > component_sizes[largest_label]:
			largest_label = label
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in height:
		for x in width:
			if labels[y * width + x] == largest_label:
				result.set_pixel(x, y, source.get_pixel(x, y))
	return result

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

func _edge_point(image: Image, bounds: Rect2i, edge: String) -> Vector2:
	var coordinates: Array[Vector2] = []
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if image.get_pixel(x, y).a < ALPHA_THRESHOLD:
				continue
			var selected := (edge == "left" and x < bounds.position.x + EDGE_SAMPLE) \
				or (edge == "right" and x >= bounds.end.x - EDGE_SAMPLE) \
				or (edge == "bottom" and y >= bounds.end.y - EDGE_SAMPLE)
			if selected:
				coordinates.append(Vector2(x, y))
	if coordinates.is_empty():
		return Vector2.ZERO
	if edge == "bottom":
		coordinates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	else:
		coordinates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	return coordinates[coordinates.size() / 2]

func _affine_map(source: Image, source_quad: PackedVector2Array, target_quad: PackedVector2Array) -> Image:
	var target_origin := target_quad[0]
	var target_x := target_quad[1] - target_origin
	var target_y := target_quad[3] - target_origin
	var determinant := target_x.x * target_y.y - target_x.y * target_y.x
	if absf(determinant) < 0.001:
		return Image.new()
	var source_origin := source_quad[0]
	var source_x := source_quad[1] - source_origin
	var source_y := source_quad[3] - source_origin
	var result := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in FRAME_SIZE.y:
		for x in FRAME_SIZE.x:
			var relative := Vector2(x, y) - target_origin
			var u := (relative.x * target_y.y - relative.y * target_y.x) / determinant
			var v := (target_x.x * relative.y - target_x.y * relative.x) / determinant
			var source_point := source_origin + source_x * u + source_y * v
			result.set_pixel(x, y, _sample_bilinear(source, source_point))
	return result

func _sample_bilinear(image: Image, point: Vector2) -> Color:
	if point.x < 0.0 or point.y < 0.0 or point.x > image.get_width() - 1 or point.y > image.get_height() - 1:
		return Color.TRANSPARENT
	var x0 := floori(point.x)
	var y0 := floori(point.y)
	var x1 := mini(x0 + 1, image.get_width() - 1)
	var y1 := mini(y0 + 1, image.get_height() - 1)
	var horizontal := point.x - x0
	var vertical := point.y - y0
	var top := image.get_pixel(x0, y0).lerp(image.get_pixel(x1, y0), horizontal)
	var bottom := image.get_pixel(x0, y1).lerp(image.get_pixel(x1, y1), horizontal)
	return top.lerp(bottom, vertical)

func _draw_quad(image: Image, quad: PackedVector2Array) -> void:
	for index in 4:
		_draw_line(image, quad[index], quad[(index + 1) % 4], Color(0.05, 0.94, 0.64, 0.92))
	for point in quad:
		for y in range(-3, 4):
			for x in range(-3, 4):
				var pixel := Vector2i(roundi(point.x) + x, roundi(point.y) + y)
				if pixel.x >= 0 and pixel.y >= 0 and pixel.x < image.get_width() and pixel.y < image.get_height():
					image.set_pixelv(pixel, Color(1.0, 0.22, 0.20, 1.0))

func _draw_line(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var steps := maxi(1, ceili(from.distance_to(to)))
	for step in range(steps + 1):
		var point := from.lerp(to, float(step) / steps)
		var pixel := Vector2i(roundi(point.x), roundi(point.y))
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < image.get_width() and pixel.y < image.get_height():
			image.set_pixelv(pixel, color)

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
