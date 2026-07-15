extends SceneTree

var failures: Array[String] = []
var battle_results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("State")
	var audio = root.get_node("Audio")
	var telemetry = root.get_node("Telemetry")
	state.battle_finished.connect(func(result: Dictionary): battle_results.append(result))
	state.reset_game()
	state.tutorial_seen = true
	_fill_resources(state)

	# Every building reaches every level and remains within its declared maximum.
	for id in state.BUILDINGS:
		while int(state.buildings[id]) < int(state.BUILDINGS[id].max):
			_fill_resources(state)
			_check(state.upgrade_building(id), "upgrade %s" % id)
		_check(int(state.buildings[id]) == 5, "%s reaches level 5" % id)

	# All economy actions, unit unlocks and policies execute.
	_fill_resources(state)
	for trade in ["sell_grain", "buy_grain", "sell_wood", "buy_stone"]:
		_check(state.trade(trade), "trade %s" % trade)
	for unit in state.UNITS:
		_fill_resources(state)
		_check(state.recruit(unit), "recruit %s" % unit)
	for policy in ["irrigate", "tax_relief", "reward_army"]:
		_fill_resources(state)
		_check(state.enact_policy(policy), "policy %s" % policy)

	# Each random event branch resolves without leaving a modal event behind.
	for event_data in state.EVENTS:
		for choice in [0, 1]:
			_fill_resources(state)
			state.current_event = event_data.duplicate(true)
			_check(state.resolve_event(choice), "event %s choice %d resolves" % [event_data.id, choice])
			_check(state.current_event.is_empty(), "event %s choice %d" % [event_data.id, choice])

	# Unaffordable event investments stay pending instead of silently executing another option.
	state.current_event = state.EVENTS[2].duplicate(true)
	state.resources.grain = 0.0
	state.resources.coins = 0.0
	_check(not state.is_event_choice_available(0), "unaffordable merchant investment is disabled")
	_check(not state.resolve_event(0) and not state.current_event.is_empty(), "unaffordable event choice remains pending")
	_check(state.resources.coins == 0.0 and state.resolve_event(1), "empty merchant sale grants no free proceeds")

	# Deterministic strong and weak siege cases.
	battle_results.clear()
	state.units = {"militia": 100, "archer": 100, "chariot": 100}
	state.morale = 100.0
	state._resolve_siege()
	_check(not battle_results.is_empty() and bool(battle_results[-1].won), "high defense wins siege")
	_check(int(battle_results[-1].player_losses) == int(battle_results[-1].killed_total) + int(battle_results[-1].wounded_total), "battle losses reconcile")
	_check(int(battle_results[-1].enemy_losses) > 0, "battle inflicts real enemy casualties")
	battle_results.clear()
	state.units = {"militia": 0, "archer": 0, "chariot": 0}
	state.buildings.wall = 0
	state.buildings.barracks = 0
	state.current_day = 40
	state._resolve_siege()
	_check(not battle_results.is_empty() and not bool(battle_results[-1].won), "zero defense loses siege")
	_check(state.attack_wave == 2 and state.next_attack_day == 49, "defeat retries the current tier with two recovery days")

	# Enemy intelligence is a persisted roster, not a hidden difficulty score.
	state.reset_game()
	_check(state._sum_force(state.enemy_army) == 25, "first enemy roster has real manpower")
	_check(not bool(state.get_enemy_display().known), "enemy starts unscouted")
	state.enemy_army.scouted = true
	var enemy_snapshot: Dictionary = state.get_snapshot()
	state.enemy_army = {}
	state._apply_snapshot(enemy_snapshot, false)
	_check(bool(state.get_enemy_display().known) and state.get_enemy_display().composition.contains("戈卒"), "enemy intelligence persists")

	# Patrol can delay each enemy roster only once, and destroying it advances the wave.
	state.reset_game()
	_fill_resources(state)
	state.units = {"militia": 100, "archer": 0, "chariot": 0}
	state.enemy_army = state._make_enemy_army(1)
	_seed_successful_patrol(state)
	_check(state.patrol(), "first patrol resolves")
	var once_delayed_until: int = state.next_attack_day
	state.current_day += 1
	_seed_successful_patrol(state)
	_check(state.patrol(), "second patrol resolves")
	_check(state.next_attack_day == once_delayed_until, "same enemy roster is delayed at most once")
	state.enemy_army = state._make_enemy_army(1)
	state.enemy_army.militia = 1
	state.enemy_army.archer = 0
	state.enemy_army.chariot = 0
	state.last_patrol_day = 0
	state.current_day += 1
	_seed_successful_patrol(state)
	_check(state.patrol() and state.attack_wave == 2 and state._sum_force(state.enemy_army) > 0, "field victory replaces a destroyed enemy roster")

	# Late war remains challenging but bounded after the final enemy tier.
	var tier_eight: Dictionary = state._make_enemy_army(state.MAX_ENEMY_TIER)
	var tier_thirty: Dictionary = state._make_enemy_army(30)
	var tier_eight_power: int = state._force_power(tier_eight, tier_eight.morale, tier_eight.training)
	var tier_thirty_power: int = state._force_power(tier_thirty, tier_thirty.morale, tier_thirty.training)
	_check(abs(tier_thirty_power - tier_eight_power) <= 8, "late enemy power stops growing beyond player capacity")
	state.reset_game()
	state.current_day = 80
	state.chapter = 3
	state.attack_wave = state.MAX_ENEMY_TIER
	state.enemy_army = state._make_enemy_army(state.attack_wave)
	state.units = {"militia": 100, "archer": 100, "chariot": 100}
	state.morale = 100.0
	state._resolve_siege()
	_check(state.attack_wave == state.MAX_ENEMY_TIER + 1 and state.next_attack_day == 87, "late war victory enters slower border-raid cadence")

	# Save slot CRUD and metadata.
	state.current_day = 42
	state.chapter = 2
	_fill_resources(state)
	_check(state.manual_save(1), "manual save")
	state.current_day = 3
	_check(state.load_slot(1), "manual load")
	_check(state.current_day == 42, "manual save restores day")
	var slots: Array = state.list_save_slots()
	_check(bool(slots[0].exists) and int(slots[0].chapter) == 2, "slot metadata")
	_check(state.delete_slot(1), "manual delete")
	_check(not bool(state.list_save_slots()[0].exists), "slot deleted")

	# A truncated primary save falls back to the previous atomic backup.
	state.delete_slot(2)
	state.current_day = 51
	_check(state.manual_save(2), "backup fixture first save")
	state.current_day = 52
	_check(state.manual_save(2), "backup fixture second save")
	var corrupt := FileAccess.open(state._slot_path(2), FileAccess.WRITE)
	corrupt.store_string("{truncated")
	corrupt = null
	state.current_day = 1
	_check(state.load_slot(2) and state.current_day == 51, "corrupt primary recovers previous save")
	_check(state.delete_slot(2), "recovered slot delete removes backup")

	# Settings persist and diagnostics export contains a snapshot.
	audio.set_volume("music", 0.37)
	audio.load_settings()
	_check(absf(float(audio.settings.music) - 0.37) < 0.001, "music volume persists")
	var music_stream: AudioStreamWAV = audio.music_player.stream
	_check(music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops forward")
	_check(music_stream.loop_begin == int(audio.MUSIC_LOOP_INTRO_SECONDS * music_stream.mix_rate), "music loops after crossfade intro")
	audio.set_volume("music", 0.42)
	var corrupt_settings := FileAccess.open(audio.SETTINGS_PATH, FileAccess.WRITE)
	corrupt_settings.store_string("{truncated")
	corrupt_settings = null
	audio.settings.music = 0.99
	audio.load_settings()
	_check(absf(float(audio.settings.music) - 0.37) < 0.001, "corrupt audio settings recover previous values")
	if FileAccess.file_exists(telemetry.EVENT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(telemetry.EVENT_PATH))
	telemetry.track("fresh_install_probe", {})
	_check(FileAccess.file_exists(telemetry.EVENT_PATH), "first diagnostic event creates its file")
	var report_path: String = telemetry.build_report(state.get_snapshot(), state.list_save_slots())
	_check(FileAccess.file_exists(report_path), "diagnostic report exported")
	_check(FileAccess.get_file_as_string(report_path).contains("game_snapshot"), "diagnostic report content")

	# Offline progress only grants capped production: it never advances days or triggers danger.
	state.reset_game()
	state.current_day = 5
	state.next_attack_day = 7
	state.resources = {"grain": 20.0, "wood": 20.0, "stone": 20.0, "coins": 20.0}
	var offline_data: Dictionary = state.get_snapshot()
	offline_data.saved_at = Time.get_unix_time_from_system() - 120.0
	state._apply_snapshot(offline_data, true)
	_check(state.current_day == 5 and state.next_attack_day == 7, "offline progress does not advance danger")
	_check(state.current_event.is_empty() and state.resources.grain > 20.0, "offline progress grants safe production")
	state.current_event = state.EVENTS[0].duplicate(true)
	var event_snapshot: Dictionary = state.get_snapshot()
	state.current_event = {}
	state._apply_snapshot(event_snapshot, false)
	_check(not state.current_event.is_empty(), "pending event persists in save")
	state.resolve_event(1)

	# Version 2 saves migrate units to people and currency to visible historical units.
	var legacy_snapshot := {"format_version": 2, "resources": {"grain": 180.0, "wood": 125.0, "stone": 82.0, "coins": 150.0}, "buildings": {"farm": 1, "woodcut": 1, "house": 1, "warehouse": 1}, "units": {"militia": 4, "archer": 1, "chariot": 0}, "population": 22, "current_day": 2, "chapter": 1}
	state._apply_snapshot(legacy_snapshot, false)
	_check(state.resources.grain == 360.0 and state.resources.coins == 1500.0, "legacy resources migrate")
	_check(state.population == 110 and state.units.militia == 20 and state.units.archer == 5, "legacy population and units migrate")

	# Art sheets are RGBA and contain transparent pixels.
	for id in state.BUILDINGS:
		var texture: Texture2D = load("res://assets/art/buildings/%s_stages.png" % id)
		var image := texture.get_image()
		_check(not image.is_empty(), "art sheet loads %s" % id)
		_check(image.detect_alpha() != Image.ALPHA_NONE, "art sheet alpha %s" % id)

	# Long economy soak: 20,000 ticks, manually resolving events as they arise.
	state.reset_game()
	state.tutorial_seen = true
	for i in 20000:
		state._tick_economy(0.1)
		if not state.current_event.is_empty():
			state.resolve_event(i % 2)
		for key in state.resources:
			_check(is_finite(float(state.resources[key])), "finite %s at tick %d" % [key, i])
			_check(float(state.resources[key]) >= 0.0, "nonnegative %s at tick %d" % [key, i])

	state.reset_game()
	audio.set_volume("music", 0.62)
	if failures.is_empty():
		print("FULL_FLOW_OK ticks=20000 buildings=8 events=10 saves=3 diagnostics=ok")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _fill_resources(state) -> void:
	state.resources = {"grain": 100000.0, "wood": 100000.0, "stone": 100000.0, "coins": 100000.0}
	state.population = maxi(state.population, 500)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _seed_successful_patrol(state) -> void:
	for candidate in range(1, 1000):
		state.rng.seed = candidate
		if state.rng.randf() < 0.80:
			state.rng.seed = candidate
			return
