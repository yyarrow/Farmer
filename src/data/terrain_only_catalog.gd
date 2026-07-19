extends RefCounted

# Image-edited and human-reviewed terrain-only assets for every era.
const READY := {
	"spring_autumn": "res://assets/art/terrain_only/city_spring_terrain_only.png",
	"warring_states": "res://assets/art/terrain_only/city_warring_states_terrain_only.png",
	"qin": "res://assets/art/terrain_only/city_qin_terrain_only.png",
	"han": "res://assets/art/terrain_only/city_han_terrain_only.png",
	"three_kingdoms": "res://assets/art/terrain_only/city_three_kingdoms_terrain_only.png",
	"jin": "res://assets/art/terrain_only/city_jin_terrain_only.png",
	"northern_southern": "res://assets/art/terrain_only/city_northern_southern_terrain_only.png",
	"sui": "res://assets/art/terrain_only/city_sui_terrain_only.png",
	"tang": "res://assets/art/terrain_only/city_tang_terrain_only.png",
	"five_dynasties": "res://assets/art/terrain_only/city_five_dynasties_terrain_only.png",
	"song": "res://assets/art/terrain_only/city_song_terrain_only.png",
	"yuan": "res://assets/art/terrain_only/city_yuan_terrain_only.png",
	"ming": "res://assets/art/terrain_only/city_ming_terrain_only.png",
	"qing": "res://assets/art/terrain_only/city_qing_terrain_only.png",
}

static func has(era_id: String) -> bool:
	return READY.has(era_id)

static func path_for(era_id: String, fallback := "") -> String:
	return str(READY.get(era_id, fallback))
