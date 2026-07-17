extends RefCounted

const EraSchema = preload("res://src/data/era_schema.gd")
const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")
const WarringStates = preload("res://src/data/eras/warring_states.gd")
const Qin = preload("res://src/data/eras/qin.gd")
const Han = preload("res://src/data/eras/han.gd")

const DEFAULT_ID := SpringAutumn.ID
const ORDER := [SpringAutumn.ID, WarringStates.ID, Qin.ID, Han.ID]

static func has(id: String) -> bool:
	return id in ORDER

static func definition(id: String) -> Dictionary:
	var raw: Dictionary
	match id:
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
