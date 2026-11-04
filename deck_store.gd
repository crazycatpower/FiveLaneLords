extends RefCounted
const B = preload("res://balance.gd")
# A deck is 8 unique rotating cards (the lord's home card is always in its own slot) plus a chosen
# lord. With a lord, every card must also be open to that lord's faction (B.card_allowed).
static func valid(deck: Array, lord: String = "", allow_duplicates: bool = false) -> bool:
	if deck.size() != 8 or deck.any(func(k) -> bool: return B.is_home_card(str(k),lord)): return false
	var unique := {}
	for kind in deck:
		if not kind is String or not B.CARDS.has(kind) or B.CARDS[kind].get("summon_only",false) or (unique.has(kind) and not allow_duplicates): return false
		if not lord.is_empty() and not B.card_allowed(kind,lord): return false
		unique[kind] = true
	return true

# The cards a lord may put in the eight, in table order.
static func pool(lord: String = "") -> Array:
	return B.CARDS.keys().filter(func(k: String) -> bool: return not B.CARDS[k].get("summon_only",false) and not B.is_home_card(k,lord) and (lord.is_empty() or B.card_allowed(k,lord)))

# The same deck with every card the lord may not take swapped for the first allowed card not yet in it.
static func fit_to_lord(deck: Array, lord: String) -> Array:
	var result: Array = deck.duplicate()
	var spare: Array = pool(lord).filter(func(k: String) -> bool: return not k in deck)
	for i: int in range(result.size()):
		if (not B.card_allowed(result[i],lord) or B.is_home_card(result[i],lord) or B.CARDS[result[i]].get("summon_only",false)) and not spare.is_empty(): result[i] = spare.pop_front()
	return result
static func save_deck(deck: Array, path: String = "user://deck.json", lord: String = "lion") -> bool:
	if not B.LORDS.has(lord) or not valid(deck,lord): return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"cards":deck,"lord":lord}))
	return true
static func load_deck(path: String = "user://deck.json") -> Array:
	return load_full(path).cards
static func load_full(path: String = "user://deck.json") -> Dictionary:
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("cards") is Array and B.LORDS.has(parsed.get("lord","")) and valid(parsed.cards,parsed.lord):
			return {"cards":parsed.cards,"lord":parsed.lord}
	return {"cards":B.PRESETS[1].duplicate(),"lord":B.PRESET_LORDS[1]}
static func average(deck: Array) -> float:
	var total := 0.0
	for kind: String in deck: total += B.CARDS[kind].cost
	return total/maxi(1,deck.size())

# Random deck: eight different cards, at least three of them troops so the match can end.
static func random_deck(rng: RandomNumberGenerator, lord: String = "") -> Array:
	var units: Array = []
	var others: Array = []
	for kind: String in pool(lord):
		if B.CARDS[kind].type == "unit": units.append(kind)
		else: others.append(kind)
	var deck: Array = []
	for i: int in range(3): deck.append(units.pop_at(rng.randi_range(0,units.size()-1)))
	var rest: Array = units+others
	while deck.size() < 8: deck.append(rest.pop_at(rng.randi_range(0,rest.size()-1)))
	return deck
