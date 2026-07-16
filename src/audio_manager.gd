extends Node

signal settings_changed

const SETTINGS_PATH := "user://qinghe_settings.json"
const MUSIC_PATHS := {
	"spring": "res://assets/audio/qinghe_theme.wav",
	"summer": "res://assets/audio/qinghe_summer.wav",
	"autumn": "res://assets/audio/qinghe_autumn.wav",
	"winter": "res://assets/audio/qinghe_winter.wav",
}
const MUSIC_LOOP_INTRO_SECONDS := 2.0
const MUSIC_CROSSFADE_SECONDS := 2.4
const SFX_PATHS := {
	"ui_tap": "res://assets/audio/ui_tap.wav",
	"build": "res://assets/audio/build.wav",
	"upgrade": "res://assets/audio/upgrade.wav",
	"trade": "res://assets/audio/trade.wav",
	"recruit": "res://assets/audio/recruit.wav",
	"command": "res://assets/audio/command.wav",
	"battle_win": "res://assets/audio/battle_win.wav",
	"battle_loss": "res://assets/audio/battle_loss.wav",
	"event": "res://assets/audio/event.wav",
}

var settings := {
	"master": 0.88,
	"music": 0.62,
	"sfx": 0.82,
	"muted": false,
	"haptics": true,
	"diagnostics_enabled": true,
}
var music_player: AudioStreamPlayer
var music_players: Array[AudioStreamPlayer] = []
var current_music_id := "spring"
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams := {}
var _sfx_cursor := 0
var _active_music_index := 0
var _music_gains: Array[float] = [0.0, 0.0]
var _duck_gain := 1.0
var _season_tween: Tween
var _duck_tween: Tween

func _ready() -> void:
	_setup_buses()
	load_settings()
	_create_players()
	apply_settings()
	call_deferred("start_music")

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _create_players() -> void:
	for i in 2:
		var music_channel := AudioStreamPlayer.new()
		music_channel.bus = "Music"
		add_child(music_channel)
		music_players.append(music_channel)
	music_player = music_players[0]
	music_player.stream = _load_music_stream(MUSIC_PATHS.spring)
	for i in 5:
		var sfx_channel := AudioStreamPlayer.new()
		sfx_channel.bus = "SFX"
		add_child(sfx_channel)
		sfx_players.append(sfx_channel)
	for id in SFX_PATHS:
		sfx_streams[id] = load(SFX_PATHS[id])

func _load_music_stream(path: String) -> AudioStream:
	var music_stream: AudioStream = load(path)
	if music_stream is AudioStreamWAV:
		music_stream = music_stream.duplicate()
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music_stream.loop_begin = int(MUSIC_LOOP_INTRO_SECONDS * music_stream.mix_rate)
		music_stream.loop_end = int(music_stream.get_length() * music_stream.mix_rate)
	return music_stream

func start_music() -> void:
	if music_players.is_empty():
		return
	var index := _active_music_index
	var player := music_players[index]
	if player.stream == null:
		player.stream = _load_music_stream(MUSIC_PATHS[current_music_id])
	if player.playing:
		return
	_kill_season_tween()
	_music_gains[index] = 0.0
	_apply_music_gains()
	player.play()
	_season_tween = get_tree().create_tween()
	_season_tween.tween_method(Callable(self, "_set_player_gain").bind(index), 0.0, 1.0, 1.4)

func set_music_season(season: String, immediate := false) -> void:
	if not MUSIC_PATHS.has(season) or music_players.is_empty():
		return
	if season == current_music_id:
		if immediate:
			_finish_current_music()
			if not music_players[_active_music_index].playing:
				_music_gains[_active_music_index] = 1.0
				_apply_music_gains()
				music_players[_active_music_index].play()
		elif not music_players[_active_music_index].playing:
			start_music()
		return
	_finish_current_music()
	var old_index := _active_music_index
	var new_index := (old_index + 1) % music_players.size()
	var old_player := music_players[old_index]
	var new_player := music_players[new_index]
	new_player.stop()
	new_player.stream = _load_music_stream(MUSIC_PATHS[season])
	_music_gains[new_index] = 0.0
	new_player.play()
	_active_music_index = new_index
	music_player = new_player
	current_music_id = season
	if immediate:
		_music_gains[new_index] = 1.0
		_music_gains[old_index] = 0.0
		old_player.stop()
		old_player.stream = null
		_apply_music_gains()
		return
	if not old_player.playing:
		_music_gains[old_index] = 0.0
		old_player.stream = null
		_apply_music_gains()
		_season_tween = get_tree().create_tween()
		_season_tween.tween_method(Callable(self, "_set_player_gain").bind(new_index), 0.0, 1.0, 1.4)
		return
	_apply_music_gains()
	_season_tween = get_tree().create_tween()
	_season_tween.tween_method(
		Callable(self, "_set_season_crossfade").bind(old_index, new_index),
		0.0,
		1.0,
		MUSIC_CROSSFADE_SECONDS
	)
	_season_tween.tween_callback(Callable(self, "_complete_season_crossfade").bind(old_index, new_index))

func _set_season_crossfade(value: float, old_index: int, new_index: int) -> void:
	# Equal-power curves avoid the audible dip produced by a linear crossfade.
	_music_gains[old_index] = cos(value * PI * 0.5)
	_music_gains[new_index] = sin(value * PI * 0.5)
	_apply_music_gains()

func _complete_season_crossfade(old_index: int, new_index: int) -> void:
	if _active_music_index != new_index:
		return
	var old_player := music_players[old_index]
	old_player.stop()
	old_player.stream = null
	_music_gains[old_index] = 0.0
	_music_gains[new_index] = 1.0
	_apply_music_gains()

func _finish_current_music() -> void:
	_kill_season_tween()
	for i in music_players.size():
		if i == _active_music_index:
			_music_gains[i] = 1.0
			continue
		music_players[i].stop()
		music_players[i].stream = null
		_music_gains[i] = 0.0
	_apply_music_gains()

func _set_player_gain(value: float, index: int) -> void:
	if index < _music_gains.size():
		_music_gains[index] = value
		_apply_music_gains()

func _set_duck_gain(value: float) -> void:
	_duck_gain = value
	_apply_music_gains()

func _apply_music_gains() -> void:
	for i in music_players.size():
		var combined := maxf(0.001, _music_gains[i] * _duck_gain)
		music_players[i].volume_db = linear_to_db(combined)

func _kill_season_tween() -> void:
	if _season_tween and _season_tween.is_valid():
		_season_tween.kill()
	_season_tween = null

func _kill_duck_tween() -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null

func _notification(what: int) -> void:
	if music_players.is_empty():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		for player in music_players:
			player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		for player in music_players:
			player.stream_paused = false
		if not music_players[_active_music_index].playing:
			start_music()
		else:
			_fade_duck_from(db_to_linear(-12.0), 0.9)

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	_kill_season_tween()
	_kill_duck_tween()
	for player in music_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.free()
	music_players.clear()
	music_player = null
	for player in sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.free()
	sfx_players.clear()
	sfx_streams.clear()

func play_sfx(id: String) -> void:
	if not sfx_streams.has(id) or sfx_players.is_empty():
		return
	var player := sfx_players[_sfx_cursor % sfx_players.size()]
	_sfx_cursor += 1
	player.stream = sfx_streams[id]
	player.play()
	if id in ["battle_win", "battle_loss"]:
		_duck_music()

func _duck_music() -> void:
	if music_players.is_empty() or not music_players[_active_music_index].playing:
		return
	_kill_duck_tween()
	_duck_gain = db_to_linear(-7.0)
	_apply_music_gains()
	_duck_tween = get_tree().create_tween()
	_duck_tween.tween_interval(0.55)
	_duck_tween.tween_method(Callable(self, "_set_duck_gain"), _duck_gain, 1.0, 1.35)

func _fade_duck_from(from_gain: float, duration: float) -> void:
	_kill_duck_tween()
	_duck_gain = from_gain
	_apply_music_gains()
	_duck_tween = get_tree().create_tween()
	_duck_tween.tween_method(Callable(self, "_set_duck_gain"), from_gain, 1.0, duration)

func set_volume(channel: String, value: float, persist := true) -> void:
	if not settings.has(channel):
		return
	settings[channel] = clampf(value, 0.0, 1.0)
	apply_settings()
	if persist:
		save_settings()
	settings_changed.emit()

func set_muted(value: bool) -> void:
	settings.muted = value
	apply_settings()
	save_settings()
	settings_changed.emit()

func set_haptics_enabled(value: bool) -> void:
	settings.haptics = value
	save_settings()
	settings_changed.emit()

func set_diagnostics_enabled(value: bool) -> void:
	settings.diagnostics_enabled = value
	save_settings()
	settings_changed.emit()

func apply_settings() -> void:
	_set_bus("Master", float(settings.master), bool(settings.muted))
	_set_bus("Music", float(settings.music), false)
	_set_bus("SFX", float(settings.sfx), false)

func _set_bus(bus_name: String, linear: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, linear)))
	AudioServer.set_bus_mute(index, muted or linear <= 0.001)

func save_settings() -> void:
	var temp_path := SETTINGS_PATH + ".tmp"
	var backup_path := SETTINGS_PATH + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(settings))
	file.flush()
	file = null
	if FileAccess.file_exists(SETTINGS_PATH):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(SETTINGS_PATH), ProjectSettings.globalize_path(backup_path)) != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			return
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(SETTINGS_PATH)) != OK and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(SETTINGS_PATH))

func load_settings() -> void:
	var parsed := _read_settings(SETTINGS_PATH)
	if parsed.is_empty():
		parsed = _read_settings(SETTINGS_PATH + ".bak")
	for channel in ["master", "music", "sfx"]:
		var value = parsed.get(channel)
		if value is int or value is float:
			settings[channel] = clampf(float(value), 0.0, 1.0)
	for option in ["muted", "haptics", "diagnostics_enabled"]:
		if parsed.get(option) is bool:
			settings[option] = bool(parsed[option])

func _read_settings(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
