extends SceneTree

const EraCatalog = preload("res://src/data/eras/spring_autumn.gd")
const BattleSystem = preload("res://src/systems/battle_system.gd")
const EconomySystem = preload("res://src/systems/economy_system.gd")
const ProgressionSystem = preload("res://src/systems/progression_system.gd")
const SaveValidator = preload("res://src/persistence/save_validator.gd")
const UiPresentation = preload("res://src/ui/presentation_formatter.gd")
const CityLayout = preload("res://src/data/city_layout.gd")
const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const BuildingProfiles = preload("res://src/city_placement/building_profiles.gd")
const ArtAlignment = preload("res://src/city_placement/art_alignment.gd")
const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")
const PlacementSolver = preload("res://src/city_placement/placement_solver.gd")
const CityViewTransform = preload("res://src/city_placement/city_view_transform.gd")
const RoadNetwork = preload("res://src/city_placement/road_network.gd")
const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state := root.get_node("State")
	state.reset_game()

	var first_resources := EraCatalog.initial_resources()
	var second_resources := EraCatalog.initial_resources()
	first_resources.grain = 0.0
	_check(float(second_resources.grain) == 360.0, "era factories do not share mutable state")

	var pure_ledger := EconomySystem.daily_ledger(
		state.get_season_data(), state.buildings, state.population, state.units,
		state.get_wounded_count(), state.current_day, state.buffs, state.UNITS
	)
	_check(pure_ledger == state.get_daily_ledger(), "state economy facade matches pure system")
	_check(ProgressionSystem.prosperity(state.buildings, state.population, state.get_army_count(), state.chapter) == state.get_prosperity(), "state progression facade matches pure system")

	var state_rng := RandomNumberGenerator.new()
	state_rng.seed = 424242
	var pure_rng := RandomNumberGenerator.new()
	pure_rng.seed = 424242
	var facade_battle: Dictionary = state._simulate_battle(state.units, state.morale, state.enemy_army, state_rng)
	var pure_battle := BattleSystem.simulate(
		state.units, state.morale, state.enemy_army, pure_rng, state.UNITS,
		int(state.buildings.wall), state.defense_order, state.get_defense_order_data(), state.get_training()
	)
	_check(facade_battle == pure_battle, "state battle facade preserves deterministic result")

	var snapshot: Dictionary = state.get_snapshot()
	_check(SaveValidator.is_valid(snapshot, state._save_validation_context()), "current snapshot passes extracted validator")
	snapshot.population = state.get_population_cap() + 1
	_check(not SaveValidator.is_valid(snapshot, state._save_validation_context()), "cross-field invalid snapshot is rejected")
	_check(UiPresentation.save_time_with_bias(0.0, 480) == "1970-01-01  08:00", "presentation formatter preserves local timestamp")
	var sample_cell := Vector2i(4, 6)
	_check(CityLayout.grid_to_screen(sample_cell) == PlacementEngine.grid_to_screen(sample_cell), "city layout compatibility facade matches pure placement engine")
	_check(CityLayout.can_place("house", sample_cell, [], 12) == PlacementEngine.can_place("house", sample_cell, [], 12), "placement validation is owned by the pure engine")
	for module in [PlacementEngine, BuildingProfiles, ArtAlignment, FootprintTemplates, PlacementSolver, CityViewTransform, RoadNetwork, DefenseLayout]:
		var source := str(module.source_code)
		_check("game_state.gd" not in source and "main.gd" not in source and "city_visuals.gd" not in source, "city placement module remains independent from runtime state and UI")

	state.reset_game()
	if failures.is_empty():
		print("ARCHITECTURE_CONTRACT_OK boundaries=12")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
