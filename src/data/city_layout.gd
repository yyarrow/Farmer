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

static func slot(id: String) -> Dictionary:
	for data in SLOTS:
		if str(data.id) == id:
			return data
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
