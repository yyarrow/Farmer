extends Node2D

const RoadNetwork = preload("res://src/city_placement/road_network.gd")

const DEFAULT_PALETTE := {
	"surface": Color("#b79b68"),
	"edge": Color("#715b3e"),
	"rut": Color("#806946"),
	"stone": Color("#d3bd88"),
}

var network := {}
var palette := DEFAULT_PALETTE.duplicate()

func configure(next_network: Dictionary, colors := {}) -> void:
	network = next_network.duplicate(true)
	palette = DEFAULT_PALETTE.duplicate()
	for key in colors:
		if palette.has(key):
			palette[key] = Color(colors[key])
	queue_redraw()

func _draw() -> void:
	if network.is_empty() or not bool(network.get("success", false)):
		return
	var masks: Dictionary = network.get("connectivity_masks", {})
	for cell in network.get("road_cells", []):
		var micro_cell := Vector2i(cell)
		var polygon := RoadNetwork.micro_cell_polygon(micro_cell)
		draw_colored_polygon(polygon, Color(palette.surface))
		var mask := int(masks.get(micro_cell, 0))
		_draw_exposed_edges(polygon, mask)
		_draw_ruts(polygon, mask)
		_draw_surface_detail(micro_cell, polygon)

func _draw_exposed_edges(polygon: PackedVector2Array, mask: int) -> void:
	for direction_index in RoadNetwork.DIRECTIONS.size():
		if mask & int(RoadNetwork.DIRECTION_MASKS[direction_index]):
			continue
		var next_corner := (direction_index + 1) % polygon.size()
		draw_line(polygon[direction_index], polygon[next_corner], Color(palette.edge), 0.8, true)

func _draw_ruts(polygon: PackedVector2Array, mask: int) -> void:
	var center := (polygon[0] + polygon[2]) * 0.5
	for direction_index in RoadNetwork.DIRECTIONS.size():
		if not mask & int(RoadNetwork.DIRECTION_MASKS[direction_index]):
			continue
		var next_corner := (direction_index + 1) % polygon.size()
		var edge_midpoint := (polygon[direction_index] + polygon[next_corner]) * 0.5
		draw_line(center, edge_midpoint, Color(palette.rut, 0.46), 0.7, true)

func _draw_surface_detail(cell: Vector2i, polygon: PackedVector2Array) -> void:
	var signature := absi(cell.x * 37 + cell.y * 61)
	if signature % 4 != 0:
		return
	var center := (polygon[0] + polygon[2]) * 0.5
	var offset := Vector2(float(signature % 5 - 2), float(signature % 3 - 1) * 0.55)
	draw_circle(center + offset, 0.65, Color(palette.stone, 0.54))
