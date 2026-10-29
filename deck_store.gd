extends RefCounted
const B = preload("res://balance.gd")
static func valid(deck: Array) -> bool:
	if deck.size() != 8 or not "farm" in deck: return false
	var unique := {}
	for kind in deck:
		if not kind is String or not B.CARDS.has(kind) or unique.has(kind): return false
		unique[kind] = true
	return true
static func save_deck(deck: Array, path: String = "user://deck.json") -> bool:
	if not valid(deck): return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(deck))
	return true
static func load_deck(path: String = "user://deck.json") -> Array:
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array and valid(parsed): return parsed
	return B.PRESETS[1].duplicate()
static func average(deck: Array) -> float:
	var total := 0.0
	for kind: String in deck: total += B.CARDS[kind].cost
	return total/maxi(1,deck.size())
