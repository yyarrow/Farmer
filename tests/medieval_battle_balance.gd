extends SceneTree

const RUNS := 3000

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state := root.get_node("State")
	state.persistence_enabled = false
	var era_scenarios := {
		"three_kingdoms": [
			{"id": "obsolete", "force": {"militia": 50, "archer": 18, "chariot": 5}, "wall": 2, "barracks": 2, "warehouse": 1, "morale": 68.0},
			{"id": "transition", "force": {"militia": 58, "archer": 20, "chariot": 6}, "wall": 3, "barracks": 3, "warehouse": 2, "morale": 76.0},
			{"id": "prepared", "force": {"militia": 84, "archer": 34, "chariot": 16}, "wall": 4, "barracks": 4, "warehouse": 5, "morale": 82.0},
		],
		"jin": [
			{"id": "obsolete", "force": {"militia": 56, "archer": 20, "chariot": 5}, "wall": 2, "barracks": 2, "warehouse": 1, "morale": 68.0},
			{"id": "transition", "force": {"militia": 70, "archer": 26, "chariot": 8}, "wall": 3, "barracks": 3, "warehouse": 2, "morale": 77.0},
			{"id": "prepared", "force": {"militia": 90, "archer": 36, "chariot": 18}, "wall": 4, "barracks": 4, "warehouse": 5, "morale": 83.0},
		],
		"northern_southern": [
			{"id": "obsolete", "force": {"militia": 62, "archer": 22, "chariot": 5}, "wall": 2, "barracks": 2, "warehouse": 1, "morale": 68.0},
			{"id": "transition", "force": {"militia": 84, "archer": 32, "chariot": 14}, "wall": 3, "barracks": 3, "warehouse": 3, "morale": 78.0},
			{"id": "prepared", "force": {"militia": 96, "archer": 38, "chariot": 20}, "wall": 4, "barracks": 4, "warehouse": 5, "morale": 84.0},
		],
	}
	for era_id in era_scenarios:
		state.reset_game()
		state._configure_era(era_id)
		state.defense_order = "steady"
		var enemy: Dictionary = state._make_enemy_army(1)
		var results := {}
		for scenario in era_scenarios[era_id]:
			state.buildings.wall = int(scenario.wall)
			state.buildings.barracks = int(scenario.barracks)
			state.buildings.warehouse = int(scenario.warehouse)
			var metrics := _simulate(state, scenario.force, float(scenario.morale), enemy, int(hash("%s_%s" % [era_id, scenario.id])) & 0x7fffffff)
			results[scenario.id] = metrics
			print("MEDIEVAL_BATTLE_CASE %s/%s win=%.1f%% own=%.2f enemy=%.2f" % [era_id, scenario.id, metrics.win_rate * 100.0, metrics.player_losses, metrics.enemy_losses])
		_check(float(results.obsolete.win_rate) <= 0.35, "%s obsolete army must remain unsafe" % era_id)
		_check(float(results.transition.win_rate) >= 0.40 and float(results.transition.win_rate) <= 0.90, "%s transition army should face a fair first defense" % era_id)
		_check(float(results.prepared.win_rate) >= float(results.transition.win_rate) + 0.08, "%s preparation must materially improve survival" % era_id)
		_check(float(results.transition.player_losses) >= 5.0 and float(results.prepared.player_losses) >= 3.0, "%s victories must consume personnel" % era_id)
	if failures.is_empty():
		print("MEDIEVAL_BATTLE_BALANCE_OK runs=%d eras=%d" % [RUNS, era_scenarios.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _simulate(state: Node, force: Dictionary, morale: float, enemy: Dictionary, seed: int) -> Dictionary:
	var sim_rng := RandomNumberGenerator.new()
	sim_rng.seed = seed
	var wins := 0
	var player_losses := 0
	var enemy_losses := 0
	for _i in RUNS:
		var result: Dictionary = state._simulate_battle(force, morale, enemy, sim_rng)
		wins += 1 if bool(result.won) else 0
		player_losses += int(result.player_losses)
		enemy_losses += int(result.enemy_losses)
	return {"win_rate": float(wins) / RUNS, "player_losses": float(player_losses) / RUNS, "enemy_losses": float(enemy_losses) / RUNS}

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
