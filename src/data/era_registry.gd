extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")
const WarringStates = preload("res://src/data/eras/warring_states.gd")

const DEFAULT_ID := SpringAutumn.ID
const ORDER := [SpringAutumn.ID, WarringStates.ID]

static func has(id: String) -> bool:
	return id in ORDER

static func definition(id: String) -> Dictionary:
	match id:
		WarringStates.ID:
			return WarringStates.definition()
		_:
			return SpringAutumn.definition()

static func definitions() -> Dictionary:
	var result := {}
	for id in ORDER:
		result[id] = definition(id)
	return result

static func next_id(id: String) -> String:
	return str(definition(id).next_id)
