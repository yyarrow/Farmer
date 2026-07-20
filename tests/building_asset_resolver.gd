extends SceneTree

const BuildingAssetResolver = preload("res://src/city_placement/building_asset_resolver.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var available := {
		BuildingAssetResolver.standardized_path("spring_autumn", "farm"): true,
		BuildingAssetResolver.era_legacy_path("spring_autumn", "farm"): true,
		BuildingAssetResolver.standardized_path("warring_states", "farm"): true,
		BuildingAssetResolver.era_legacy_path("warring_states", "farm"): true,
		BuildingAssetResolver.era_legacy_path("qin", "farm"): true,
		BuildingAssetResolver.root_legacy_path("farm"): true,
	}
	var exists := func(path: String): return available.has(path)

	var spring := BuildingAssetResolver.resolve("spring_autumn", "farm", true, exists)
	_check(bool(spring.standardized), "Spring and Autumn uses its available standardized sheet")
	_check(str(spring.path) == BuildingAssetResolver.standardized_path("spring_autumn", "farm"), "Spring and Autumn path is era-local")

	var warring := BuildingAssetResolver.resolve("warring_states", "farm", true, exists)
	_check(bool(warring.standardized), "Warring States keeps its available standardized sheet")

	var qin := BuildingAssetResolver.resolve("qin", "farm", true, exists)
	_check(not bool(qin.standardized), "Qin falls back when its standardized sheet is absent")
	_check(str(qin.path) == BuildingAssetResolver.era_legacy_path("qin", "farm"), "Qin prefers its legacy era sheet before root")

	var unknown := BuildingAssetResolver.resolve("unknown_era", "farm", true, exists)
	_check(str(unknown.path) == BuildingAssetResolver.root_legacy_path("farm"), "unknown era falls back to the root sheet")

	var disabled := BuildingAssetResolver.resolve("warring_states", "farm", false, exists)
	_check(not bool(disabled.standardized), "pilot flag disables standardized art")
	_check(str(disabled.path) == BuildingAssetResolver.era_legacy_path("warring_states", "farm"), "disabled pilot keeps the era legacy fallback")

	if failures.is_empty():
		print("BUILDING_ASSET_RESOLVER_OK scenarios=5")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
