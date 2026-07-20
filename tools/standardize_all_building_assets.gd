extends SceneTree

const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")

const FRAME_SIZE := Vector2i(384, 384)
const ATLAS_SIZE := FRAME_SIZE * 2
const SOURCE_ALPHA_THRESHOLD := 0.025
const VISIBLE_ALPHA_THRESHOLD := 0.06
const MIN_COMPONENT_PIXELS := 8
const SAFE_MARGIN := 10
# The canonical ground diamond is 324px wide and already leaves a 30px frame
# margin on each side. Using 316px here made regenerated lots intrinsically
# narrower than the placement contract even when their authored camera was
# correct.
const MAX_SUBJECT_WIDTH := 324
const MAX_SUBJECT_HEIGHT := 326
const OUTPUT_SUFFIX := "_stages_standardized.png"
const QA_DIR := "res://.qa/building_standardization"
const MANIFEST_PATH := "res://assets/art/buildings/standardization_manifest.json"
const IMAGEGEN_SOURCE_ROOT := "res://tmp/imagegen"

const ERAS := [
	"spring_autumn",
	"warring_states",
	"qin",
	"han",
	"three_kingdoms",
	"jin",
	"northern_southern",
	"sui",
	"tang",
	"five_dynasties",
	"song",
	"yuan",
	"ming",
	"qing",
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

var _manifest := {
	"schema": 1,
	"frame_size": [FRAME_SIZE.x, FRAME_SIZE.y],
	"atlas_layout": "2x2 stages, stage order 1/2/3/4",
	"camera": "2:1 isometric",
	"entrance": "south/front footprint socket",
	"transform": "uniform scale and translation only; never affine stretch",
	"root_fallback_policy": "deprecated; era atlases are authoritative",
	"assets": {},
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_DIR))
	var selected_eras := _selected_eras()
	var selected_buildings := _selected_buildings()
	if selected_eras.is_empty() or selected_buildings.is_empty():
		return
	for era_id in selected_eras:
		if not _standardize_era(era_id, selected_buildings):
			return
	if not _save_manifest():
		return
	print("ALL_ERA_BUILDING_STANDARDIZATION_OK eras=%d atlases=%d stages=%d" % [
		selected_eras.size(), selected_eras.size() * selected_buildings.size(),
		selected_eras.size() * selected_buildings.size() * 4,
	])
	quit(0)

func _selected_eras() -> Array[String]:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--era="):
			requested = argument.trim_prefix("--era=")
	if requested.is_empty() or requested == "all":
		var all_eras: Array[String] = []
		for era_id in ERAS:
			all_eras.append(era_id)
		return all_eras
	if not requested in ERAS:
		_fail("unknown era: %s" % requested)
		return []
	return [requested]

func _selected_buildings() -> Array[String]:
	var requested := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--buildings="):
			requested = argument.trim_prefix("--buildings=")
	var result: Array[String] = []
	if requested == "all":
		for building_type in BUILDINGS:
			result.append(building_type)
		return result
	for building_type in requested.split(",", false):
		if not BUILDINGS.has(building_type):
			_fail("unknown building type: %s" % building_type)
			return []
		result.append(building_type)
	return result

func _standardize_era(era_id: String, building_types: Array[String]) -> bool:
	var contact := Image.create(FRAME_SIZE.x * 2, FRAME_SIZE.y / 2 * building_types.size(), false, Image.FORMAT_RGBA8)
	contact.fill(Color(0.08, 0.075, 0.06, 1.0))
	var era_assets := {}
	for building_index in building_types.size():
		var building_type: String = building_types[building_index]
		var footprint: Vector2i = BUILDINGS[building_type]
		var directory := "res://assets/art/buildings/eras/%s" % era_id
		var source_path := "%s/%s_stages.png" % [directory, building_type]
		var output_path := "%s/%s%s" % [directory, building_type, OUTPUT_SUFFIX]
		var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if source.is_empty() or source.get_size() != ATLAS_SIZE:
			return _fail("%s must be a readable %sx%s source atlas" % [source_path, ATLAS_SIZE.x, ATLAS_SIZE.y])
		if era_id == "warring_states" and FileAccess.file_exists(output_path):
			var authoritative := Image.load_from_file(ProjectSettings.globalize_path(output_path))
			if authoritative.is_empty() or authoritative.get_size() != ATLAS_SIZE:
				return _fail("invalid authoritative atlas %s" % output_path)
			# These approved sheets predate the common contract. Keep their authored
			# scale and socket intact, but remove meaningful pixels from the four-pixel
			# frame safety band so neighboring atlas stages can never bleed together.
			if _clear_meaningful_frame_edge_bleed(authoritative):
				if authoritative.save_png(output_path) != OK:
					return _fail("cannot save %s" % output_path)
			era_assets[building_type] = _manifest_entry(footprint, "authoritative", [])
			_blit_contact_row(contact, authoritative, building_index)
			continue
		var extracted := _load_imagegen_stages(era_id, building_type)
		var existing_record := _existing_asset_record(era_id, building_type)
		# Generated source layers are authoring-only and intentionally not shipped.
		# A clean checkout must preserve the approved standardized atlas instead of
		# silently replacing it with the inferior legacy source on the next run.
		if extracted.is_empty() and existing_record.get("method", "") == "imagegen_regenerated" and FileAccess.file_exists(output_path):
			var approved := Image.load_from_file(ProjectSettings.globalize_path(output_path))
			if approved.is_empty() or approved.get_size() != ATLAS_SIZE:
				return _fail("invalid approved generated atlas %s" % output_path)
			era_assets[building_type] = existing_record
			_blit_contact_row(contact, approved, building_index)
			continue
		var production_method := "imagegen_regenerated" if not extracted.is_empty() else "deterministic_relayout"
		if extracted.is_empty():
			extracted = _extract_stages(source)
		if extracted.size() != 4:
			return _fail("%s could not recover four stages" % source_path)
		# Connected stages from one legacy atlas share one source camera scale.
		# Independently generated stages instead normalize their natural ground
		# contour to the same canonical footprint width.
		var shared_scale := -1.0 if production_method == "imagegen_regenerated" else _shared_stage_scale(extracted, footprint)
		var output := Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		var stage_records: Array[Dictionary] = []
		for stage in 4:
			var stage_data: Dictionary = extracted[stage]
			var composed := _compose_frame(stage_data.image, footprint, shared_scale)
			var standardized: Image = composed.image
			if standardized.is_empty():
				return _fail("%s stage %d could not be standardized" % [source_path, stage + 1])
			var origin := Vector2i((stage % 2) * FRAME_SIZE.x, int(stage / 2) * FRAME_SIZE.y)
			output.blit_rect(standardized, Rect2i(Vector2i.ZERO, FRAME_SIZE), origin)
			stage_records.append({
				"stage": stage + 1,
				"source_bounds": _rect_array(stage_data.bounds),
				"component_count": stage_data.component_count,
				"uniform_scale": snappedf(float(composed.scale), 0.0001),
				"socket": _vector_array(FootprintTemplates.source_socket(footprint)),
			})
		if output.save_png(output_path) != OK:
			return _fail("cannot save %s" % output_path)
		era_assets[building_type] = _manifest_entry(footprint, production_method, stage_records)
		_blit_contact_row(contact, output, building_index)
	_manifest.assets[era_id] = era_assets
	var contact_path := "%s/%s_contact.png" % [QA_DIR, era_id]
	if contact.save_png(contact_path) != OK:
		return _fail("cannot save %s" % contact_path)
	print("STANDARDIZED_ERA_OK era=%s atlases=%d stages=%d contact=%s" % [era_id, building_types.size(), building_types.size() * 4, contact_path])
	return true

func _existing_asset_record(era_id: String, building_type: String) -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		return {}
	var assets: Dictionary = parsed.get("assets", {})
	var era_assets: Dictionary = assets.get(era_id, {})
	return era_assets.get(building_type, {})

func _extract_stages(atlas: Image) -> Array[Dictionary]:
	var width := atlas.get_width()
	var height := atlas.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var stage_images: Array[Image] = []
	var component_counts := PackedInt32Array([0, 0, 0, 0])
	for unused in 4:
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		stage_images.append(image)
	for y in height:
		for x in width:
			var index := y * width + x
			if visited[index] != 0:
				continue
			visited[index] = 1
			if atlas.get_pixel(x, y).a < SOURCE_ALPHA_THRESHOLD:
				continue
			var queue := PackedInt32Array([index])
			var cursor := 0
			var quadrant_counts := PackedInt32Array([0, 0, 0, 0])
			while cursor < queue.size():
				var current := queue[cursor]
				cursor += 1
				var current_x := current % width
				var current_y := int(current / width)
				quadrant_counts[_quadrant_for(current_x, current_y)] += 1
				for offset_y in range(-1, 2):
					for offset_x in range(-1, 2):
						if offset_x == 0 and offset_y == 0:
							continue
						var neighbor_x := current_x + offset_x
						var neighbor_y := current_y + offset_y
						if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= height:
							continue
						var neighbor := neighbor_y * width + neighbor_x
						if visited[neighbor] != 0:
							continue
						visited[neighbor] = 1
						if atlas.get_pixel(neighbor_x, neighbor_y).a >= SOURCE_ALPHA_THRESHOLD:
							queue.append(neighbor)
			if queue.size() < MIN_COMPONENT_PIXELS:
				continue
			var owner := 0
			for quadrant in range(1, 4):
				if quadrant_counts[quadrant] > quadrant_counts[owner]:
					owner = quadrant
			component_counts[owner] += 1
			for pixel_index in queue:
				var pixel_x := pixel_index % width
				var pixel_y := int(pixel_index / width)
				stage_images[owner].set_pixel(pixel_x, pixel_y, atlas.get_pixel(pixel_x, pixel_y))
	var result: Array[Dictionary] = []
	for stage in 4:
		var bounds := _alpha_bounds(stage_images[stage])
		if bounds.size == Vector2i.ZERO:
			return []
		var crop := stage_images[stage].get_region(bounds)
		result.append({
			"image": crop,
			"bounds": bounds,
			"component_count": component_counts[stage],
			"scale": 1.0,
		})
	return result

func _load_imagegen_stages(era_id: String, building_type: String) -> Array[Dictionary]:
	var source_directory := "%s/%s_%s" % [IMAGEGEN_SOURCE_ROOT, era_id, building_type]
	var result: Array[Dictionary] = []
	for stage in 4:
		var path := "%s/stage_%d_alpha.png" % [source_directory, stage + 1]
		if not FileAccess.file_exists(path):
			return []
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		var bounds := _alpha_bounds(image)
		if image.is_empty() or bounds.size == Vector2i.ZERO:
			return []
		result.append({
			"image": image.get_region(bounds),
			"bounds": bounds,
			"component_count": 1,
			"scale": 1.0,
		})
	return result

func _shared_stage_scale(stages: Array[Dictionary], footprint: Vector2i) -> float:
	var scale := 1.0
	for stage_data in stages:
		var image: Image = stage_data.image
		scale = minf(scale, _fit_scale(image, footprint))
	return scale

func _fit_scale(source: Image, footprint: Vector2i) -> float:
	var width := float(maxi(1, source.get_width()))
	var height := float(maxi(1, source.get_height()))
	var contact_x := clampf(_bottom_alpha_median_x(source), 0.0, width - 1.0)
	var socket := FootprintTemplates.source_socket(footprint)
	var scale := minf(1.0, minf(float(MAX_SUBJECT_WIDTH) / width, float(MAX_SUBJECT_HEIGHT) / height))
	# Non-square lots place the road socket away from frame centre. Fit both sides
	# around that real contact before translating, instead of clamping afterwards
	# (which silently detached wide market, warehouse and gate art from the road).
	if contact_x > 0.0:
		scale = minf(scale, (socket.x - SAFE_MARGIN) / contact_x)
	var right_span := width - 1.0 - contact_x
	if right_span > 0.0:
		scale = minf(scale, (FRAME_SIZE.x - SAFE_MARGIN - socket.x) / right_span)
	if height > 1.0:
		scale = minf(scale, (socket.y - SAFE_MARGIN) / (height - 1.0))
	return maxf(scale, 0.001)

func _compose_frame(source: Image, footprint: Vector2i, scale: float) -> Dictionary:
	var frame := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	frame.fill(Color.TRANSPARENT)
	if scale <= 0.0:
		scale = _fit_scale(source, footprint)
	var scaled_size := Vector2i(maxi(1, roundi(source.get_width() * scale)), maxi(1, roundi(source.get_height() * scale)))
	var scaled := source.duplicate()
	if scaled.get_size() != scaled_size:
		scaled.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	var bottom_x := _bottom_alpha_median_x(scaled)
	var socket := FootprintTemplates.source_socket(footprint)
	var destination := Vector2i(roundi(socket.x - bottom_x), roundi(socket.y - scaled.get_height() + 1))
	destination.x = clampi(destination.x, SAFE_MARGIN, FRAME_SIZE.x - SAFE_MARGIN - scaled.get_width())
	destination.y = clampi(destination.y, SAFE_MARGIN, FRAME_SIZE.y - SAFE_MARGIN - scaled.get_height())
	frame.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), destination)
	return {"image": frame, "scale": scale}

func _blit_contact_row(contact: Image, atlas: Image, row: int) -> void:
	for stage in 4:
		var origin := Vector2i((stage % 2) * FRAME_SIZE.x, int(stage / 2) * FRAME_SIZE.y)
		var frame := atlas.get_region(Rect2i(origin, FRAME_SIZE))
		frame.resize(FRAME_SIZE.x / 2, FRAME_SIZE.y / 2, Image.INTERPOLATE_LANCZOS)
		contact.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(stage * frame.get_width(), row * frame.get_height()))

func _clear_meaningful_frame_edge_bleed(atlas: Image) -> bool:
	var changed := false
	for stage in 4:
		var origin := Vector2i((stage % 2) * FRAME_SIZE.x, int(stage / 2) * FRAME_SIZE.y)
		for y in FRAME_SIZE.y:
			for x in FRAME_SIZE.x:
				if x >= 4 and x < FRAME_SIZE.x - 4 and y >= 4 and y < FRAME_SIZE.y - 4:
					continue
				var pixel_position := origin + Vector2i(x, y)
				if atlas.get_pixelv(pixel_position).a < VISIBLE_ALPHA_THRESHOLD:
					continue
				atlas.set_pixelv(pixel_position, Color.TRANSPARENT)
				changed = true
	return changed

func _manifest_entry(footprint: Vector2i, method: String, stages: Array) -> Dictionary:
	var quad := FootprintTemplates.source_quad(footprint)
	return {
		"footprint": [footprint.x, footprint.y],
		"canonical_quad": [_vector_array(quad[0]), _vector_array(quad[1]), _vector_array(quad[2]), _vector_array(quad[3])],
		"socket": _vector_array(FootprintTemplates.source_socket(footprint)),
		"method": method,
		"stages": stages,
	}

func _save_manifest() -> bool:
	var manifest_path := ProjectSettings.globalize_path(MANIFEST_PATH)
	var existing := {}
	if FileAccess.file_exists(MANIFEST_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			existing = parsed
	var selected_assets: Dictionary = _manifest.assets
	var merged_assets := {}
	if existing.has("assets"):
		for era_id in existing.assets:
			merged_assets[era_id] = existing.assets[era_id]
	for era_id in selected_assets:
		var merged_era: Dictionary = merged_assets.get(era_id, {})
		var selected_era: Dictionary = selected_assets[era_id]
		for building_type in selected_era:
			merged_era[building_type] = selected_era[building_type]
		merged_assets[era_id] = merged_era
	_manifest.assets = merged_assets
	_normalize_manifest_integers()
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return _fail("cannot open %s" % MANIFEST_PATH)
	file.store_string(JSON.stringify(_manifest, "\t", false) + "\n")
	return true

func _normalize_manifest_integers() -> void:
	# JSON parses every number as float. Restore schema/count/rectangle fields so
	# adding one era does not rewrite all previously approved manifest records.
	for era_id in _manifest.assets:
		var era_assets: Dictionary = _manifest.assets[era_id]
		for building_type in era_assets:
			var record: Dictionary = era_assets[building_type]
			var footprint: Array = record.get("footprint", [])
			if footprint.size() == 2:
				record.footprint = [int(footprint[0]), int(footprint[1])]
			var stages: Array = record.get("stages", [])
			for stage_record in stages:
				if not stage_record is Dictionary:
					continue
				stage_record.stage = int(stage_record.get("stage", 0))
				stage_record.component_count = int(stage_record.get("component_count", 0))
				var bounds: Array = stage_record.get("source_bounds", [])
				if bounds.size() == 4:
					stage_record.source_bounds = [int(bounds[0]), int(bounds[1]), int(bounds[2]), int(bounds[3])]

func _quadrant_for(x: int, y: int) -> int:
	return int(x >= FRAME_SIZE.x) + int(y >= FRAME_SIZE.y) * 2

func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < VISIBLE_ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	return Rect2i() if max_x < 0 else Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _bottom_alpha_median_x(image: Image) -> float:
	var bounds := _alpha_bounds(image)
	var coordinates := PackedInt32Array()
	# The render socket is a real ground contact, not the visual mass centre.
	# Restrict the sample to the lowest three rows so stairs, fences and tall
	# façades cannot pull the authored entrance away from the plot anchor.
	for y in range(maxi(bounds.position.y, bounds.end.y - 3), bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if image.get_pixel(x, y).a >= VISIBLE_ALPHA_THRESHOLD:
				coordinates.append(x)
	if coordinates.is_empty():
		return image.get_width() * 0.5
	coordinates.sort()
	return coordinates[coordinates.size() / 2]

func _rect_array(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _vector_array(vector: Vector2) -> Array[float]:
	return [snappedf(vector.x, 0.01), snappedf(vector.y, 0.01)]

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
