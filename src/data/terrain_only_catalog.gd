extends RefCounted

# Curated terrain-only assets. Missing eras deliberately fall back to their
# existing background until an image-edited and human-reviewed asset is ready.
const READY := {
	"spring_autumn": "res://assets/art/terrain_only/city_spring_terrain_only.png",
	"warring_states": "res://assets/art/terrain_only/city_warring_states_terrain_only.png",
	"tang": "res://assets/art/terrain_only/city_tang_terrain_only.png",
}

static func has(era_id: String) -> bool:
	return READY.has(era_id)

static func path_for(era_id: String, fallback := "") -> String:
	return str(READY.get(era_id, fallback))
