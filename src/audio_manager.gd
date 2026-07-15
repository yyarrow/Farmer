extends Node

signal settings_changed

const SETTINGS_PATH := "user://qinghe_settings.json"
const MUSIC_PATH := "res://assets/audio/qinghe_theme.wav"
const MUSIC_LOOP_INTRO_SECONDS := 2.0
const SFX_PATHS := {
	"ui_tap": "res://assets/audio/ui_tap.wav",
	"build": "res://assets/audio/build.wav",
	"upgrade": "res://assets/audio/upgrade.wav",
	"trade": "res://assets/audio/trade.wav",
	"recruit": "res://assets/audio/recruit.wav",
	"battle_win": "res://assets/audio/battle_win.wav",
	"battle_loss": "res://assets/audio/battle_loss.wav",
	"event": "res://assets/audio/event.wav",
}

var settings := {
	"master": 0.88,
	"music": 0.62,
	"sfx": 0.82,
	"muted": false,
	"diagnostics_enabled": true,
}
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams := {}
var _sfx_cursor := 0
var _music_tween: Tween

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
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	var music_stream = load(MUSIC_PATH)
	if music_stream is AudioStreamWAV:
		music_stream = music_stream.duplicate()
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music_stream.loop_begin = int(MUSIC_LOOP_INTRO_SECONDS * music_stream.mix_rate)
		music_stream.loop_end = int(music_stream.get_length() * music_stream.mix_rate)
	music_player.stream = music_stream
	add_child(music_player)
	for i in 5:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	for id in SFX_PATHS:
		sfx_streams[id] = load(SFX_PATHS[id])

func start_music() -> void:
	if music_player and not music_player.playing:
		music_player.volume_db = -18.0
		music_player.play()
		_fade_music_to(0.0, 1.4)

func _notification(what: int) -> void:
	if not music_player:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		music_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		music_player.stream_paused = false
		if not music_player.playing:
			start_music()
		else:
			music_player.volume_db = -12.0
			_fade_music_to(0.0, 0.9)

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
	if not music_player or not music_player.playing:
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	music_player.volume_db = -7.0
	_music_tween = get_tree().create_tween()
	_music_tween.tween_interval(0.55)
	_music_tween.tween_property(music_player, "volume_db", 0.0, 1.35)

func _fade_music_to(target_db: float, duration: float) -> void:
	if not music_player:
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = get_tree().create_tween()
	_music_tween.tween_property(music_player, "volume_db", target_db, duration)

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
	for option in ["muted", "diagnostics_enabled"]:
		if parsed.get(option) is bool:
			settings[option] = bool(parsed[option])

func _read_settings(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
