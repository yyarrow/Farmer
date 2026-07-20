extends SceneTree

const RoadNetwork = preload("res://src/city_placement/road_network.gd")
const CityLayout = preload("res://src/data/city_layout.gd")
const CityRoadVisuals = preload("res://src/city_road_visuals.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var placed := [
		{"id": "farm", "type": "farm", "grid_origin": [2, 1]},
		{"id": "house", "type": "house", "grid_origin": [9, 5]},
	]
	var network := CityLayout.infrastructure_network(placed, 12)
	var visuals := CityRoadVisuals.new()
	visuals.configure(network, {"surface": Color("#aa9060")})
	_check(bool(visuals.network.success), "road visual accepts a successful derived network")
	_check(visuals.network.road_cells == network.road_cells, "road visual preserves deterministic cell order")
	_check(visuals.network.gate_approach_cells == [network.gate + Vector2i.DOWN], "road visual receives the expanded gate approach")
	var visual_cells := visuals.visual_cells()
	_check(visual_cells.has(network.gate) and visual_cells.has(network.gate + Vector2i.DOWN), "road surface remains continuous from the interior root to the moved gate")
	var masks := visuals.visual_connectivity_masks()
	_check(int(masks[network.gate]) & RoadNetwork.SOUTH, "interior gate root connects south into the exterior approach")
	_check(int(masks[network.gate + Vector2i.DOWN]) & RoadNetwork.NORTH, "exterior approach connects north back into the city road")
	_check(Color(visuals.palette.surface) == Color("#aa9060"), "era palette can override the road surface")
	_check(Color(visuals.palette.edge) == CityRoadVisuals.DEFAULT_PALETTE.edge, "unspecified road colors retain defaults")
	visuals.configure({"success": false, "road_cells": []})
	_check(not bool(visuals.network.success), "failed routing produces an empty-safe visual state")
	visuals.free()
	if failures.is_empty():
		print("CITY_ROAD_VISUALS_OK cells=%d" % network.road_cells.size())
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
