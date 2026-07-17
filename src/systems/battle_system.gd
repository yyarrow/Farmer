extends RefCounted

static func morale_factor(value: float) -> float:
	return clampf(0.65 + value / 200.0, 0.70, 1.15)

static func force_power(force: Dictionary, force_morale: float, training: float, unit_definitions: Dictionary) -> int:
	var raw := 0.0
	for id in unit_definitions:
		raw += int(force.get(id, 0)) * float(unit_definitions[id].power)
	return roundi(raw * morale_factor(force_morale) * training)

static func simulate(
	player_force: Dictionary,
	player_morale: float,
	enemy_force: Dictionary,
	sim_rng: RandomNumberGenerator,
	unit_definitions: Dictionary,
	wall_level: int,
	defense_order_id: String,
	defense_order: Dictionary,
	player_training: float
) -> Dictionary:
	var player := {"militia": int(player_force.get("militia", 0)), "archer": int(player_force.get("archer", 0)), "chariot": int(player_force.get("chariot", 0))}
	var enemy := {"militia": int(enemy_force.get("militia", 0)), "archer": int(enemy_force.get("archer", 0)), "chariot": int(enemy_force.get("chariot", 0))}
	var player_before := player.duplicate()
	var enemy_before := enemy.duplicate()
	var player_losses_by_type := {"militia": 0, "archer": 0, "chariot": 0}
	var enemy_losses_by_type := {"militia": 0, "archer": 0, "chariot": 0}
	var player_current_morale := player_morale
	var enemy_current_morale := float(enemy_force.get("morale", 50.0))
	var enemy_training := float(enemy_force.get("training", 1.0))
	var wall_cover := maxf(0.52, 1.0 - wall_level * 0.09)
	var incoming_multiplier := float(defense_order.incoming)
	var ranged_multiplier := float(defense_order.ranged)
	var melee_multiplier := float(defense_order.melee)
	var round_log: Array = []
	for round_index in 3:
		if sum_force(player) <= 0 or sum_force(enemy) <= 0 or player_current_morale < 24.0 or enemy_current_morale < 24.0:
			break
		var player_ranged := int(player.archer) * float(unit_definitions.archer.ranged) * 0.055 * morale_factor(player_current_morale) * player_training * ranged_multiplier * sim_rng.randf_range(0.90, 1.10)
		var enemy_ranged := int(enemy.archer) * float(unit_definitions.archer.ranged) * 0.055 * morale_factor(enemy_current_morale) * enemy_training * wall_cover * incoming_multiplier * sim_rng.randf_range(0.90, 1.10)
		var player_melee_strength := 0.0
		var enemy_melee_strength := 0.0
		for id in unit_definitions:
			player_melee_strength += int(player.get(id, 0)) * float(unit_definitions[id].melee)
			enemy_melee_strength += int(enemy.get(id, 0)) * float(unit_definitions[id].melee)
		var player_clash: float = player_melee_strength * 0.047 * morale_factor(player_current_morale) * player_training * melee_multiplier * sim_rng.randf_range(0.90, 1.10)
		var enemy_clash: float = enemy_melee_strength * 0.047 * morale_factor(enemy_current_morale) * enemy_training * wall_cover * incoming_multiplier * sim_rng.randf_range(0.90, 1.10)
		var player_round_losses := mini(sum_force(player), stochastic_round(enemy_ranged + enemy_clash, sim_rng))
		var enemy_round_losses := mini(sum_force(enemy), stochastic_round(player_ranged + player_clash, sim_rng))
		var lost_player := deal_losses(player, player_round_losses, sim_rng, unit_definitions)
		var lost_enemy := deal_losses(enemy, enemy_round_losses, sim_rng, unit_definitions)
		merge_force_counts(player_losses_by_type, lost_player, unit_definitions)
		merge_force_counts(enemy_losses_by_type, lost_enemy, unit_definitions)
		player_current_morale -= player_round_losses * 2.3 + maxf(0.0, sum_force(enemy) - sum_force(player)) * 0.06
		enemy_current_morale -= enemy_round_losses * 2.3 + maxf(0.0, sum_force(player) - sum_force(enemy)) * 0.06 + wall_level * 1.2
		round_log.append({"round": round_index + 1, "player_losses": player_round_losses, "enemy_losses": enemy_round_losses, "player_morale": roundi(player_current_morale), "enemy_morale": roundi(enemy_current_morale)})
	var player_score := float(force_power(player, player_current_morale, player_training, unit_definitions))
	var enemy_score := float(force_power(enemy, enemy_current_morale, enemy_training, unit_definitions))
	var win_chance := pow(maxf(0.1, player_score), 3.0) / (pow(maxf(0.1, player_score), 3.0) + pow(maxf(0.1, enemy_score), 3.0))
	var won := sim_rng.randf() <= win_chance
	if sum_force(enemy) <= 0 or enemy_current_morale < 24.0:
		won = true
	elif sum_force(player) <= 0 or player_current_morale < 24.0:
		won = false
	if won and sum_force(enemy) > 0:
		var retreat_losses := stochastic_round(sum_force(enemy) * sim_rng.randf_range(0.08, 0.14), sim_rng)
		merge_force_counts(enemy_losses_by_type, deal_losses(enemy, retreat_losses, sim_rng, unit_definitions), unit_definitions)
	elif not won and sum_force(player) > 0:
		var retreat_losses := stochastic_round(sum_force(player) * sim_rng.randf_range(0.08, 0.14), sim_rng)
		merge_force_counts(player_losses_by_type, deal_losses(player, retreat_losses, sim_rng, unit_definitions), unit_definitions)
	var killed := {"militia": 0, "archer": 0, "chariot": 0}
	var injured := {"militia": 0, "archer": 0, "chariot": 0}
	for id in unit_definitions:
		var total_lost := int(player_losses_by_type[id])
		var dead := stochastic_round(total_lost * 0.30, sim_rng)
		killed[id] = dead
		injured[id] = total_lost - dead
	return {
		"won": won,
		"defense_order": defense_order_id,
		"defense_order_name": defense_order.name,
		"player_before": player_before,
		"enemy_before": enemy_before,
		"player_survivors": player,
		"enemy_survivors": enemy,
		"player_power": force_power(player_before, player_morale, player_training, unit_definitions),
		"enemy_power": force_power(enemy_before, float(enemy_force.get("morale", 50.0)), enemy_training, unit_definitions),
		"player_losses": sum_force(player_losses_by_type),
		"enemy_losses": sum_force(enemy_losses_by_type),
		"player_losses_by_type": player_losses_by_type,
		"enemy_losses_by_type": enemy_losses_by_type,
		"killed": killed,
		"wounded": injured,
		"killed_total": sum_force(killed),
		"wounded_total": sum_force(injured),
		"player_morale_after": maxf(10.0, player_current_morale),
		"enemy_morale_after": maxf(0.0, enemy_current_morale),
		"resolution_win_chance": win_chance,
		"rounds": round_log,
	}

static func deal_losses(force: Dictionary, requested: int, sim_rng: RandomNumberGenerator, unit_definitions: Dictionary) -> Dictionary:
	var lost := {"militia": 0, "archer": 0, "chariot": 0}
	for _i in mini(requested, sum_force(force)):
		var total_weight := 0.0
		for id in unit_definitions:
			total_weight += int(force.get(id, 0)) * float(unit_definitions[id].exposure)
		if total_weight <= 0.0:
			break
		var roll := sim_rng.randf() * total_weight
		for id in unit_definitions:
			roll -= int(force.get(id, 0)) * float(unit_definitions[id].exposure)
			if roll <= 0.0 and int(force.get(id, 0)) > 0:
				force[id] = int(force[id]) - 1
				lost[id] += 1
				break
	return lost

static func stochastic_round(value: float, sim_rng: RandomNumberGenerator) -> int:
	var whole := floori(maxf(0.0, value))
	return whole + (1 if sim_rng.randf() < value - whole else 0)

static func sum_force(force: Dictionary) -> int:
	return int(force.get("militia", 0)) + int(force.get("archer", 0)) + int(force.get("chariot", 0))

static func merge_force_counts(target: Dictionary, addition: Dictionary, unit_definitions: Dictionary) -> void:
	for id in unit_definitions:
		target[id] = int(target.get(id, 0)) + int(addition.get(id, 0))
