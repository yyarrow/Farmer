extends RefCounted

const EraSchema = preload("res://src/data/era_schema.gd")
const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")
const WarringStates = preload("res://src/data/eras/warring_states.gd")
const Qin = preload("res://src/data/eras/qin.gd")
const Han = preload("res://src/data/eras/han.gd")
const ThreeKingdoms = preload("res://src/data/eras/three_kingdoms.gd")
const Jin = preload("res://src/data/eras/jin.gd")
const NorthernSouthern = preload("res://src/data/eras/northern_southern.gd")
const Sui = preload("res://src/data/eras/sui.gd")
const Tang = preload("res://src/data/eras/tang.gd")
const FiveDynasties = preload("res://src/data/eras/five_dynasties.gd")

const DEFAULT_ID := SpringAutumn.ID
const ORDER := [SpringAutumn.ID, WarringStates.ID, Qin.ID, Han.ID, ThreeKingdoms.ID, Jin.ID, NorthernSouthern.ID, Sui.ID, Tang.ID, FiveDynasties.ID]

static func has(id: String) -> bool:
	return id in ORDER

static func definition(id: String) -> Dictionary:
	var raw: Dictionary
	match id:
		FiveDynasties.ID:
			raw = FiveDynasties.definition()
		Tang.ID:
			raw = Tang.definition()
		Sui.ID:
			raw = Sui.definition()
		NorthernSouthern.ID:
			raw = NorthernSouthern.definition()
		Jin.ID:
			raw = Jin.definition()
		ThreeKingdoms.ID:
			raw = ThreeKingdoms.definition()
		Han.ID:
			raw = Han.definition()
		Qin.ID:
			raw = Qin.definition()
		WarringStates.ID:
			raw = WarringStates.definition()
		_:
			raw = SpringAutumn.definition()
	return EraSchema.normalize(raw)

static func definitions() -> Dictionary:
	var result := {}
	for id in ORDER:
		result[id] = definition(id)
	return result

static func next_id(id: String) -> String:
	return str(definition(id).next_id)
