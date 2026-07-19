extends SceneTree

const EraRegistry = preload("res://src/data/era_registry.gd")
const BuildingProfiles = preload("res://src/city_placement/building_profiles.gd")
const ArtAlignment = preload("res://src/city_placement/art_alignment.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var frames := 0
	var max_bottom_padding := 0
	var anchor := Vector2(270, 410)
	for era_id in EraRegistry.ORDER:
		for building_type in BuildingProfiles.PROFILES:
			var path := "res://assets/art/buildings/eras/%s/%s_stages.png" % [era_id, building_type]
			_check(ResourceLoader.exists(path), "missing building art %s" % path)
			if not ResourceLoader.exists(path):
				continue
			var texture: Texture2D = load(path)
			for stage in 4:
				frames += 1
				var metrics := ArtAlignment.frame_metrics(texture, stage)
				_check(not metrics.is_empty(), "%s stage %d has measurable art" % [path, stage + 1])
				if metrics.is_empty():
					continue
				var padding := int(metrics.bottom_padding)
				max_bottom_padding = maxi(max_bottom_padding, padding)
				_check(padding >= 0 and padding < int(metrics.source_size.y), "%s stage %d contact stays in frame" % [path, stage + 1])
				var layout := ArtAlignment.frame_layout(texture, stage, BuildingProfiles.maximum_art_size(building_type), anchor)
				_check(Vector2(layout.visible_contact).distance_to(anchor) < 0.01, "%s stage %d visible contact matches plot anchor" % [path, stage + 1])
				_check(absf(Rect2(layout.visible_rect).end.y - anchor.y) < 0.01, "%s stage %d visible art sits on plot anchor" % [path, stage + 1])
	if failures.is_empty():
		print("ART_ALIGNMENT_OK frames=%d max_bottom_padding=%d" % [frames, max_bottom_padding])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
