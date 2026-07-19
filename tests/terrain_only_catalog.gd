extends SceneTree

const EraRegistry = preload("res://src/data/era_registry.gd")
const TerrainOnlyCatalog = preload("res://src/data/terrain_only_catalog.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var file := FileAccess.open("res://assets/art/terrain_only/manifest.json", FileAccess.READ)
	_check(file != null, "terrain-only manifest is readable")
	var manifest: Dictionary = JSON.parse_string(file.get_as_text()) if file else {}
	var entries: Array = manifest.get("eras", [])
	_check(entries.size() == EraRegistry.ORDER.size(), "manifest accounts for every configured era")
	var ids := []
	var ready := 0
	for entry in entries:
		ids.append(str(entry.id))
		_check(ResourceLoader.exists(str(entry.source)), "%s source terrain exists" % entry.id)
		if str(entry.status) != "ready":
			continue
		ready += 1
		_check(TerrainOnlyCatalog.has(str(entry.id)), "%s ready asset is exposed by the catalog" % entry.id)
		_check(TerrainOnlyCatalog.path_for(str(entry.id)) == str(entry.target), "%s catalog path matches the reviewed target" % entry.id)
		var source := Image.load_from_file(str(entry.source).trim_prefix("res://"))
		var target := Image.load_from_file(str(entry.target).trim_prefix("res://"))
		_check(not source.is_empty() and not target.is_empty(), "%s reviewed images decode" % entry.id)
		_check(target.get_size() == source.get_size(), "%s terrain-only asset preserves exact source dimensions" % entry.id)
	_check(ids == EraRegistry.ORDER, "manifest order is the canonical era order")
	_check(ready == 7 and TerrainOnlyCatalog.READY.size() == 7, "seven reviewed terrains are ready without overstating pending eras")

	if failures.is_empty():
		print("TERRAIN_ONLY_CATALOG_OK eras=%d ready=%d" % [entries.size(), ready])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
