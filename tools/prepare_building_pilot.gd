extends SceneTree

const FootprintTemplates = preload("res://src/city_placement/footprint_templates.gd")
const TEMPLATE_DIR := "res://assets/art/buildings/source/templates"
const PILOT_DIR := "res://.qa/building_pilot"
const FARM_ATLAS := "res://assets/art/buildings/eras/warring_states/farm_stages.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMPLATE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PILOT_DIR))
	var quad := FootprintTemplates.source_quad(Vector2i(3, 3))
	var points := ""
	for point in quad:
		points += "%.2f,%.2f " % [point.x, point.y]
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="384" height="384" viewBox="0 0 384 384">
<rect width="384" height="384" fill="#ff00ff"/>
<polygon points="%s" fill="#bca676" stroke="#655038" stroke-width="3" stroke-linejoin="round"/>
<path d="M111 228.5 L273 309.5 M70.5 248.75 L232.5 329.75 M273 228.5 L111 309.5 M313.5 248.75 L151.5 329.75" fill="none" stroke="#947c50" stroke-width="2" opacity="0.72"/>
</svg>""" % points.strip_edges()
	var template := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var template_error := template.load_svg_from_string(svg, 1.0)
	if template_error != OK:
		push_error("cannot render 3x3 building template: %s" % template_error)
		quit(1)
		return
	var template_path := "%s/footprint_3x3.png" % TEMPLATE_DIR
	if template.save_png(template_path) != OK:
		push_error("cannot save %s" % template_path)
		quit(1)
		return

	var atlas := Image.load_from_file(ProjectSettings.globalize_path(FARM_ATLAS))
	if atlas.is_empty() or atlas.get_size() != Vector2i(768, 768):
		push_error("invalid source farm atlas")
		quit(1)
		return
	for stage in 4:
		var origin := Vector2i((stage % 2) * 384, int(stage / 2) * 384)
		var frame := atlas.get_region(Rect2i(origin, Vector2i(384, 384)))
		var path := "%s/warring_farm_stage_%d_reference.png" % [PILOT_DIR, stage + 1]
		if frame.save_png(path) != OK:
			push_error("cannot save %s" % path)
			quit(1)
			return
	print("BUILDING_PILOT_PREP_OK template=%s references=4 quad=%s" % [template_path, quad])
	quit(0)
