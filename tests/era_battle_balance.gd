extends SceneTree

const RUNS := 4000

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state := root.get_node("State")
	state.persistence_enabled = false
	state.reset_game()
	state._configure_era("warring_states")
	state.defense_order = "steady"
	var enemy: Dictionary = state._make_enemy_army(1)
	var scenarios := [
		{"id": "unprepared", "name": "旧式散兵", "force": {"militia": 20, "archer": 0, "chariot": 0}, "wall": 0, "barracks": 0, "morale": 65.0},
		{"id": "transition", "name": "更迭守军", "force": {"militia": 45, "archer": 15, "chariot": 0}, "wall": 2, "barracks": 2, "morale": 70.0},
		{"id": "prepared", "name": "整军备战", "force": {"militia": 50, "archer": 20, "chariot": 5}, "wall": 3, "barracks": 3, "morale": 78.0},
	]
	var results := {}
	for scenario in scenarios:
		state.buildings.wall = int(scenario.wall)
		state.buildings.barracks = int(scenario.barracks)
		var metrics := _simulate(state, scenario.force, float(scenario.morale), enemy, int(hash(str(scenario.id))) & 0x7fffffff)
		results[scenario.id] = metrics
		print("ERA_BATTLE_CASE %s win=%.1f%% own=%.2f enemy=%.2f" % [scenario.name, metrics.win_rate * 100.0, metrics.player_losses, metrics.enemy_losses])

	_check(float(results.unprepared.win_rate) <= 0.18, "unprepared force should not trivialize Warring States")
	_check(float(results.transition.win_rate) >= 0.55 and float(results.transition.win_rate) <= 0.90, "representative era-transition army has a fair first defense")
	_check(float(results.prepared.win_rate) >= float(results.transition.win_rate) + 0.08, "preparation materially improves Warring States survival")
	_check(float(results.transition.player_losses) > 0.0 and float(results.prepared.player_losses) > 0.0, "Warring States victories still consume soldiers")

	if failures.is_empty():
		print("ERA_BATTLE_BALANCE_OK runs=%d" % RUNS)
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
	return {
		"win_rate": float(wins) / RUNS,
		"player_losses": float(player_losses) / RUNS,
		"enemy_losses": float(enemy_losses) / RUNS,
	}

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
