extends Node

signal unexpected_exit_detected(summary: String)

const DIAG_DIR := "user://diagnostics"
const EVENT_PATH := "user://diagnostics/events.jsonl"
const STATE_PATH := "user://diagnostics/session_state.json"
const MAX_EVENT_BYTES := 768 * 1024
const MAX_EXPORT_EVENTS := 240

var session_id := ""
var session_started := 0.0
var previous_unclean_exit := false
var _heartbeat_accum := 0.0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIAG_DIR))
	_detect_previous_exit()
	session_id = "%d-%06d" % [int(Time.get_unix_time_from_system()), randi_range(0, 999999)]
	session_started = Time.get_unix_time_from_system()
	_write_session_state(false, "running")
	track("app_start", {
		"version": ProjectSettings.get_setting("application/config/version", "0.2.1"),
		"os": OS.get_name(),
		"model": OS.get_model_name(),
		"locale": OS.get_locale(),
		"screen": str(DisplayServer.screen_get_size()),
	})
	if previous_unclean_exit:
		call_deferred("_emit_unclean_warning")

func _process(delta: float) -> void:
	_heartbeat_accum += delta
	if _heartbeat_accum >= 60.0:
		_heartbeat_accum = 0.0
		track("heartbeat", {
			"fps": Engine.get_frames_per_second(),
			"memory_mb": snappedf(float(OS.get_static_memory_usage()) / 1048576.0, 0.1),
			"uptime": roundi(Time.get_unix_time_from_system() - session_started),
		})
		_write_session_state(false, "running")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		track("app_background", {})
		_write_session_state(true, "background")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		track("app_resume", {})
		_write_session_state(false, "running")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		track("app_close", {})
		_write_session_state(true, "closed")

func track(event_name: String, payload: Dictionary = {}) -> void:
	if not bool(Audio.settings.get("diagnostics_enabled", true)):
		return
	_rotate_if_needed()
	var event := {
		"ts": Time.get_datetime_string_from_system(false, true),
		"unix": Time.get_unix_time_from_system(),
		"session": session_id,
		"event": event_name,
		"data": _sanitize(payload),
	}
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(EVENT_PATH) else FileAccess.WRITE
	var file := FileAccess.open(EVENT_PATH, mode)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(event))

func track_error(code: String, message: String, context: Dictionary = {}) -> void:
	track("error", {"code": code, "message": message.left(500), "context": context})

func _sanitize(value):
	if value is Dictionary:
		var clean := {}
		for key in value:
			clean[str(key)] = _sanitize(value[key])
		return clean
	if value is Array:
		var clean_array := []
		for item in value:
			clean_array.append(_sanitize(item))
		return clean_array
	if value is String:
		return value.left(1000)
	return value

func _detect_previous_exit() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if parsed is Dictionary:
		previous_unclean_exit = not bool(parsed.get("clean", true))

func _emit_unclean_warning() -> void:
	track("previous_unexpected_exit", {})
	unexpected_exit_detected.emit("检测到上次运行可能异常中断，诊断记录已保留")

func _write_session_state(clean: bool, reason: String) -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"clean": clean,
			"reason": reason,
			"session": session_id,
			"updated_at": Time.get_unix_time_from_system(),
		}))

func _rotate_if_needed() -> void:
	if not FileAccess.file_exists(EVENT_PATH):
		return
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	if file and file.get_length() > MAX_EVENT_BYTES:
		var lines := FileAccess.get_file_as_string(EVENT_PATH).split("\n", false)
		var keep_from := maxi(0, lines.size() - 500)
		var kept := PackedStringArray()
		for i in range(keep_from, lines.size()):
			kept.append(lines[i])
		var out := FileAccess.open(EVENT_PATH, FileAccess.WRITE)
		if out:
			out.store_string("\n".join(kept) + "\n")

func build_report(game_snapshot: Dictionary, save_slots: Array) -> String:
	var lines := FileAccess.get_file_as_string(EVENT_PATH).split("\n", false) if FileAccess.file_exists(EVENT_PATH) else PackedStringArray()
	var start := maxi(0, lines.size() - MAX_EXPORT_EVENTS)
	var recent := PackedStringArray()
	for i in range(start, lines.size()):
		recent.append(lines[i])
	var report := {
		"report_version": 1,
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"app_version": ProjectSettings.get_setting("application/config/version", "0.2.1"),
		"device": {"os": OS.get_name(), "model": OS.get_model_name(), "locale": OS.get_locale()},
		"session": session_id,
		"previous_unclean_exit": previous_unclean_exit,
		"game_snapshot": game_snapshot,
		"save_slots": save_slots,
		"godot_log_tail": _tail_text("user://diagnostics/godot.log", 65536),
		"recent_events": recent,
	}
	var text := JSON.stringify(report, "  ")
	var export_path := "%s/qinghe-report-%d.json" % [DIAG_DIR, int(Time.get_unix_time_from_system())]
	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		file.store_string(text)
	track("diagnostic_export", {"path": export_path, "events": recent.size()})
	DisplayServer.clipboard_set(text)
	return export_path

func _tail_text(path: String, max_bytes: int) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var start := maxi(0, file.get_length() - max_bytes)
	file.seek(start)
	return file.get_buffer(file.get_length() - start).get_string_from_utf8()

func clear_logs() -> void:
	if FileAccess.file_exists(EVENT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EVENT_PATH))
	track("diagnostics_cleared", {})
