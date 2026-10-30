extends RefCounted
# Golden matches: fixed-seed AI-vs-AI battles whose end state is stored in tools/golden_matches.json.
# A refactor must leave every fingerprint unchanged; smoke_test.gd checks this. When a rule or
# number changes on purpose, regenerate the file and commit it with that change:
#   godot_console --headless --path . -s tools/make_golden.gd
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const DeckStore = preload("res://deck_store.gd")
const PATH := "res://tools/golden_matches.json"
const SEEDS := [1,2,3,4,5,6,7,8]
const CAP := 150.0 # seconds of game time per match; long enough for fights, skills and deaths

# Plays one fixed-seed match and returns its end state as strings (exact comparison, no float noise).
static func fingerprint(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lords: Array = B.LORDS.keys()
	var picks: Array = [lords[rng.randi_range(0,lords.size()-1)],lords[rng.randi_range(0,lords.size()-1)]]
	var decks: Array = [DeckStore.random_deck(rng,picks[0]),DeckStore.random_deck(rng,picks[1])]
	var m := Battle.new(seed_value,decks[0].duplicate(),decks[1].duplicate(),picks[0],picks[1])
	m.difficulty = seed_value%3
	m.record_events = false
	m.ai_enabled = [true,true]
	while not m.ended and m.elapsed < CAP:
		m.step(1.0/60.0)
	var hp := 0.0
	for u: Dictionary in m.units: hp += maxf(0.0,u.hp)
	var f := {"seed":str(seed_value),"winner":str(m.winner),"elapsed":"%.2f" % m.elapsed,"units":str(m.units.size()),"buildings":str(m.buildings.size()),"unit_hp":"%.2f" % hp}
	for team: int in range(2):
		f["ink%d" % team] = "%.2f" % m.ink[team]
		f["gates%d" % team] = ",".join(m.gates[team].map(func(g: float) -> String: return "%.2f" % g))
		f["plays%d" % team] = str(m.stats[team].plays)
		f["produced%d" % team] = "%.2f" % m.stats[team].produced
		f["lord_hp%d" % team] = "%.2f" % m.lords[team].hp
	return f

static func load_expected() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data if data is Array else []
