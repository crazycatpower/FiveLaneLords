extends RefCounted
const B = preload("res://balance.gd")
# A deck is 8 unique rotating cards (farmland is always in its own slot) plus a chosen lord.
static func valid(deck: Array) -> bool:
	if deck.size() != 8 or "farm" in deck: return false
	var unique := {}
	for kind in deck:
		if not kind is String or not B.CARDS.has(kind) or unique.has(kind): return false
		unique[kind] = true
	return true
static func save_deck(deck: Array, path: String = "user://deck.json", lord: String = "lion") -> bool:
	if not valid(deck) or not B.LORDS.has(lord): return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"cards":deck,"lord":lord}))
	return true
static func load_deck(path: String = "user://deck.json") -> Array:
	return load_full(path).cards
static func load_full(path: String = "user://deck.json") -> Dictionary:
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("cards") is Array and valid(parsed.cards) and B.LORDS.has(parsed.get("lord","")):
			return {"cards":parsed.cards,"lord":parsed.lord}
	return {"cards":B.PRESETS[1].duplicate(),"lord":B.PRESET_LORDS[1]}
static func average(deck: Array) -> float:
	var total := 0.0
	for kind: String in deck: total += B.CARDS[kind].cost
	return total/maxi(1,deck.size())

# Random deck: eight different cards, at least three of them troops so the match can end.
static func random_deck(rng: RandomNumberGenerator) -> Array:
	var units: Array = []
	var others: Array = []
	for kind: String in B.CARDS:
		if kind == "farm": continue
		if B.CARDS[kind].type == "unit": units.append(kind)
		else: others.append(kind)
	var deck: Array = []
	for i: int in range(3): deck.append(units.pop_at(rng.randi_range(0,units.size()-1)))
	var rest: Array = units+others
	while deck.size() < 8: deck.append(rest.pop_at(rng.randi_range(0,rest.size()-1)))
	return deck
