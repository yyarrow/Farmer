extends RefCounted

# The painted city is a skeleton. Buildings live in twelve independent sockets
# shared by every city tier; tiers only reveal more sockets and pan range.
const MAX_SLOTS := 12
const UNIQUE_BUILDINGS := ["wall"]

const SLOTS := [
	{"id": "slot_01", "position": Vector2(45, 206), "size": Vector2(100, 82), "z": 1},
	{"id": "slot_02", "position": Vector2(160, 199), "size": Vector2(100, 82), "z": 2},
	{"id": "slot_03", "position": Vector2(278, 203), "size": Vector2(100, 82), "z": 3},
	{"id": "slot_04", "position": Vector2(395, 211), "size": Vector2(100, 82), "z": 4},
	{"id": "slot_05", "position": Vector2(28, 294), "size": Vector2(100, 82), "z": 5},
	{"id": "slot_06", "position": Vector2(145, 287), "size": Vector2(100, 82), "z": 6},
	{"id": "slot_07", "position": Vector2(267, 289), "size": Vector2(100, 82), "z": 7},
	{"id": "slot_08", "position": Vector2(389, 301), "size": Vector2(100, 82), "z": 8},
	{"id": "slot_09", "position": Vector2(44, 386), "size": Vector2(100, 82), "z": 9},
	{"id": "slot_10", "position": Vector2(163, 381), "size": Vector2(100, 82), "z": 10},
	{"id": "slot_11", "position": Vector2(285, 385), "size": Vector2(100, 82), "z": 11},
	{"id": "slot_12", "position": Vector2(405, 397), "size": Vector2(100, 82), "z": 12},
]

# Slot ids remain stable for saves, while every painted skeleton supplies a
# compact, data-only 4x3 perspective grid. Later city tiers zoom and pan this
# grid horizontally, so the third row deliberately stays above the HUD.
const ERA_SLOT_GRIDS := {
	"spring_autumn": {"columns": [75, 205, 340, 475], "rows": [245, 325, 405]},
	"warring_states": {"columns": [70, 200, 335, 470], "rows": [242, 320, 398]},
	"qin": {"columns": [72, 202, 337, 472], "rows": [240, 316, 392]},
	"han": {"columns": [70, 200, 335, 470], "rows": [238, 312, 386]},
	"three_kingdoms": {
		"columns": [75, 205, 340, 480],
		"rows": [245, 325, 405],
		"offsets": [Vector2.ZERO, Vector2(0, -5), Vector2(-5, -1), Vector2(-5, 7), Vector2(-5, 0), Vector2(-5, -5), Vector2(-5, 1), Vector2(-5, 10), Vector2.ZERO, Vector2(0, -8), Vector2(0, -5), Vector2(0, 5)],
	},
	"jin": {"columns": [70, 200, 335, 470], "rows": [235, 305, 380]},
	"northern_southern": {"columns": [70, 200, 335, 470], "rows": [230, 300, 372]},
	"sui": {"columns": [70, 200, 340, 480], "rows": [220, 295, 365]},
	"tang": {"columns": [70, 200, 340, 480], "rows": [220, 292, 362]},
	"five_dynasties": {"columns": [70, 200, 335, 470], "rows": [222, 292, 360]},
	"song": {"columns": [70, 200, 335, 470], "rows": [230, 305, 380]},
	"yuan": {"columns": [68, 195, 340, 480], "rows": [225, 305, 380]},
	"ming": {"columns": [70, 200, 335, 470], "rows": [230, 305, 375]},
	"qing": {"columns": [70, 200, 335, 470], "rows": [220, 290, 360]},
}
const ROW_FOOTPRINTS := [Vector2(86, 50), Vector2(98, 57), Vector2(112, 65)]
const ROW_ART_SCALES := [0.73, 0.84, 0.96]

# The painted lots use the same oblique two-axis perspective in every era.
# These axes turn a socket center into the actual ground plane used by the
# background lot, empty-slot affordance, hit target and building foot line.
# Era overrides are intentionally data-only so a future skeleton can tune its
# camera without touching rendering or save data.
const DEFAULT_PLOT_AXES := {
	"x": Vector2(1.0, -0.13),
	"y": Vector2(0.24, 1.0),
}
const ERA_PLOT_AXES := {
	"spring_autumn": {"x": Vector2(1.0, -0.11), "y": Vector2(0.26, 1.0)},
	"warring_states": {"x": Vector2(1.0, -0.12), "y": Vector2(0.24, 1.0)},
	"qin": {"x": Vector2(1.0, -0.12), "y": Vector2(0.23, 1.0)},
	"han": {"x": Vector2(1.0, -0.12), "y": Vector2(0.24, 1.0)},
	"three_kingdoms": {"x": Vector2(1.0, -0.13), "y": Vector2(0.25, 1.0)},
	"jin": {"x": Vector2(1.0, -0.13), "y": Vector2(0.25, 1.0)},
	"northern_southern": {"x": Vector2(1.0, -0.12), "y": Vector2(0.24, 1.0)},
	"sui": {"x": Vector2(1.0, -0.06), "y": Vector2(0.16, 1.0)},
	"tang": {"x": Vector2(1.0, -0.13), "y": Vector2(0.24, 1.0)},
	"five_dynasties": {"x": Vector2(1.0, -0.13), "y": Vector2(0.25, 1.0)},
	"song": {"x": Vector2(1.0, -0.10), "y": Vector2(0.24, 1.0)},
	"yuan": {"x": Vector2(1.0, -0.09), "y": Vector2(0.27, 1.0)},
	"ming": {"x": Vector2(1.0, -0.12), "y": Vector2(0.24, 1.0)},
	"qing": {"x": Vector2(1.0, -0.11), "y": Vector2(0.24, 1.0)},
}

# Preferred migration/ambient anchors. They are only defaults; instance slots
# remain the source of truth after the player moves a building.
const BUILDING_SLOT_DEFAULTS := {
	"farm": "slot_09",
	"woodcut": "slot_01",
	"quarry": "slot_12",
	"house": "slot_07",
	"market": "slot_05",
	"warehouse": "slot_06",
	"barracks": "slot_04",
	"wall": "slot_03",
}

const BUILDING_POSITIONS := {
	"farm": Vector2(44, 386),
	"woodcut": Vector2(45, 206),
	"quarry": Vector2(405, 397),
	"house": Vector2(267, 289),
	"market": Vector2(28, 294),
	"warehouse": Vector2(145, 287),
	"barracks": Vector2(395, 211),
	"wall": Vector2(278, 203),
}

const BUILDING_SIZES := {
	"farm": Vector2(100, 82),
	"woodcut": Vector2(100, 82),
	"quarry": Vector2(100, 82),
	"house": Vector2(100, 82),
	"market": Vector2(100, 82),
	"warehouse": Vector2(100, 82),
	"barracks": Vector2(100, 82),
	"wall": Vector2(100, 82),
}

const EFFECT_POSITIONS := {
	"trade": Vector2(96, 338),
	"recruit": Vector2(445, 268),
	"defense_order": Vector2(438, 281),
	"policy": Vector2(270, 410),
	"siege": Vector2(330, 238),
	"shortage": Vector2(270, 460),
	"storage_full": Vector2(270, 350),
}

static func slot(id: String, era_id := "") -> Dictionary:
	for index in SLOTS.size():
		var data: Dictionary = SLOTS[index]
		if str(data.id) == id:
			var resolved: Dictionary = data.duplicate()
			var grid: Dictionary = ERA_SLOT_GRIDS.get(era_id, {})
			if not grid.is_empty():
				var row := int(index / 4)
				var column := index % 4
				resolved.anchor = Vector2(float(grid.columns[column]), float(grid.rows[row]))
				var offsets: Array = grid.get("offsets", [])
				if index < offsets.size():
					var offset: Vector2 = offsets[index]
					resolved.anchor += offset
				resolved.footprint = ROW_FOOTPRINTS[row]
				resolved.art_scale = ROW_ART_SCALES[row]
				var axes: Dictionary = ERA_PLOT_AXES.get(era_id, DEFAULT_PLOT_AXES)
				var axis_x: Vector2 = Vector2(axes.x).normalized()
				var axis_y: Vector2 = Vector2(axes.y).normalized()
				var half_x := axis_x * float(resolved.footprint.x) * 0.5
				var half_y := axis_y * float(resolved.footprint.y) * 0.5
				resolved.plot_axis_x = axis_x
				resolved.plot_axis_y = axis_y
				resolved.plot_polygon = PackedVector2Array([
					resolved.anchor - half_x - half_y,
					resolved.anchor + half_x - half_y,
					resolved.anchor + half_x + half_y,
					resolved.anchor - half_x + half_y,
				])
				# Art sheets share a bottom-center origin. Seat that origin slightly
				# toward the lot's front edge instead of on the abstract center dot.
				resolved.art_anchor = resolved.anchor + axis_y * float(resolved.footprint.y) * 0.27
				resolved.position = resolved.anchor - resolved.footprint * 0.5
				resolved.size = resolved.footprint
				# Only the three perspective rows need depth sorting. Keeping this
				# local to the world layer prevents roofs from drawing over HUD cards.
				resolved.z = row + 1
			else:
				resolved.anchor = resolved.position + resolved.size * 0.5
				resolved.footprint = resolved.size
				resolved.art_scale = 0.86
				resolved.plot_axis_x = Vector2.RIGHT
				resolved.plot_axis_y = Vector2.DOWN
				resolved.plot_polygon = PackedVector2Array([
					resolved.position,
					resolved.position + Vector2(resolved.size.x, 0),
					resolved.position + resolved.size,
					resolved.position + Vector2(0, resolved.size.y),
				])
				resolved.art_anchor = resolved.anchor + Vector2(0, resolved.size.y * 0.27)
				resolved.z = int(index / 4) + 1
			return resolved
	return {}

static func unlocked_slots(count: int) -> Array:
	return SLOTS.slice(0, clampi(count, 0, MAX_SLOTS))

static func first_open_slot(instances: Array, unlocked_count: int, preferred := "") -> String:
	var occupied := {}
	for instance in instances:
		occupied[str(instance.get("slot_id", ""))] = true
	if not preferred.is_empty() and not occupied.has(preferred):
		for data in unlocked_slots(unlocked_count):
			if str(data.id) == preferred:
				return preferred
	for data in unlocked_slots(unlocked_count):
		if not occupied.has(str(data.id)):
			return str(data.id)
	return ""
