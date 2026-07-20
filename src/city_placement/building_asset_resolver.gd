extends RefCounted

# Pure path selection for building stage sheets. Runtime resource lookup is
# injected so the fallback contract can be tested without State or a scene.

static func resolve(
	era_id: String,
	building_type: String,
	standardized_enabled: bool,
	path_exists: Callable
) -> Dictionary:
	var candidates := _candidates(era_id, building_type, standardized_enabled)
	for candidate in candidates:
		if path_exists.call(str(candidate.path)):
			return candidate
	# Preserve the existing final fallback: loading the root sheet remains the
	# caller's last attempt even when import metadata is temporarily unavailable.
	return candidates[-1]

static func standardized_path(era_id: String, building_type: String) -> String:
	return "res://assets/art/buildings/eras/%s/%s_stages_standardized.png" % [era_id, building_type]

static func era_legacy_path(era_id: String, building_type: String) -> String:
	return "res://assets/art/buildings/eras/%s/%s_stages.png" % [era_id, building_type]

static func root_legacy_path(building_type: String) -> String:
	return "res://assets/art/buildings/%s_stages.png" % building_type

static func _candidates(era_id: String, building_type: String, standardized_enabled: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if standardized_enabled:
		result.append({
			"path": standardized_path(era_id, building_type),
			"standardized": true,
		})
	result.append({
		"path": era_legacy_path(era_id, building_type),
		"standardized": false,
	})
	result.append({
		"path": root_legacy_path(building_type),
		"standardized": false,
	})
	return result
