extends SceneTree

const SOURCE_DIR := "res://assets/art/buildings/source/standardized/warring_states"
const PREVIEW_DIR := "res://.qa/building_pilot"
const OUTPUT_ATLAS := "res://assets/art/buildings/eras/warring_states/farm_stages_standardized.png"
const FRAME_SIZE := Vector2i(384, 384)
const TARGET_LEFT := 30
const TARGET_RIGHT := 354
const TARGET_TOP := 188
const TARGET_SIDE := 269
const TARGET_BOTTOM := 350
const ALPHA_THRESHOLD := 0.06

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIR))
	var atlas := Image.create(768, 768, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for stage in 4:
		var input_path := "%s/farm_stage_%d_alpha.png" % [SOURCE_DIR, stage + 1]
		var source := Image.load_from_file(ProjectSettings.globalize_path(input_path))
		if source.is_empty():
			_fail("cannot load %s" % input_path)
			return
		var bounds := _alpha_bounds(source)
		if bounds.size == Vector2i.ZERO:
			_fail("empty alpha bounds in %s" % input_path)
			return
		var scale := float(TARGET_RIGHT - TARGET_LEFT + 1) / float(bounds.size.x)
		var scaled_size := Vector2i(roundi(source.get_width() * scale), roundi(source.get_height() * scale))
		source.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
		var scaled_bounds := _alpha_bounds(source)
		var offset := Vector2i(
			TARGET_LEFT - scaled_bounds.position.x,
			TARGET_BOTTOM - (scaled_bounds.end.y - 1)
		)
		var frame := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
		frame.fill(Color.TRANSPARENT)
		frame.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), offset)
		var pre_warp_bounds := _alpha_bounds(frame)
		var source_bottom := pre_warp_bounds.end.y - 1
		var source_side := _edge_side_y(frame, pre_warp_bounds)
		var source_top := roundi(source_side * 2.0 - source_bottom)
		if source_top >= source_side or source_side >= source_bottom:
			_fail("stage %d cannot infer a ground diamond: top=%d side=%.1f bottom=%d" % [stage + 1, source_top, source_side, source_bottom])
			return
		frame = _warp_ground_plane(frame, source_top, source_bottom)
		var final_bounds := _alpha_bounds(frame)
		if absi(final_bounds.position.x - TARGET_LEFT) > 2 \
			or absi((final_bounds.end.x - 1) - TARGET_RIGHT) > 2 \
			or absi((final_bounds.end.y - 1) - TARGET_BOTTOM) > 2:
			_fail("stage %d normalization missed target: %s" % [stage + 1, final_bounds])
			return
		var final_side := _edge_side_y(frame, final_bounds)
		if absf(final_side - TARGET_SIDE) > 2.0:
			_fail("stage %d side corner missed target: %.1f" % [stage + 1, final_side])
			return
		var preview_path := "%s/warring_farm_stage_%d_standardized.png" % [PREVIEW_DIR, stage + 1]
		if frame.save_png(preview_path) != OK:
			_fail("cannot save %s" % preview_path)
			return
		var atlas_origin := Vector2i((stage % 2) * FRAME_SIZE.x, int(stage / 2) * FRAME_SIZE.y)
		atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME_SIZE), atlas_origin)
		print("STANDARDIZED_FARM_STAGE stage=%d source=%s ground=%d/%.1f/%d final=%s side=%.1f" % [
			stage + 1, bounds, source_top, source_side, source_bottom, final_bounds, final_side,
		])
	if atlas.save_png(OUTPUT_ATLAS) != OK:
		_fail("cannot save %s" % OUTPUT_ATLAS)
		return
	print("STANDARDIZED_FARM_PILOT_OK atlas=%s stages=4" % OUTPUT_ATLAS)
	quit(0)

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

func _edge_side_y(image: Image, bounds: Rect2i) -> float:
	var samples: Array[int] = []
	for x in range(bounds.position.x, mini(bounds.position.x + 5, bounds.end.x)):
		for y in range(bounds.position.y, bounds.end.y):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				samples.append(y)
	for x in range(maxi(bounds.position.x, bounds.end.x - 5), bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				samples.append(y)
	if samples.is_empty():
		return -1.0
	samples.sort()
	return float(samples[samples.size() / 2])

func _warp_ground_plane(source: Image, source_top: int, source_bottom: int) -> Image:
	var result := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var source_span := float(source_bottom - source_top)
	var target_span := float(TARGET_BOTTOM - TARGET_TOP)
	for y in FRAME_SIZE.y:
		var source_y := float(source_top - (TARGET_TOP - y))
		if y >= TARGET_TOP:
			source_y = source_top + float(y - TARGET_TOP) * source_span / target_span
		if source_y < 0.0 or source_y > source.get_height() - 1:
			continue
		var y0 := floori(source_y)
		var y1 := mini(y0 + 1, source.get_height() - 1)
		var weight := source_y - y0
		for x in FRAME_SIZE.x:
			result.set_pixel(x, y, source.get_pixel(x, y0).lerp(source.get_pixel(x, y1), weight))
	return result

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
