extends SceneTree
# Worker for tools/autobalance.py: plays random-deck, random-lord AI matches and writes one JSON
# line per match. Same seed -> same decks, lords and match.
#   godot_console --headless --path . -s tools/random_sim.gd -- --start=1 --count=100 --out=PATH [--cap=900]
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const DeckStore = preload("res://deck_store.gd")

func _initialize() -> void:
	var start := 1
	var count := 10
	var cap := 900.0
	var out := "user://random_sim.jsonl"
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=",1)
		if arg.begins_with("--start="): start = int(value)
		elif arg.begins_with("--count="): count = int(value)
		elif arg.begins_with("--cap="): cap = float(value)
		elif arg.begins_with("--out="): out = value
	var file := FileAccess.open(out,FileAccess.WRITE)
	var lords: Array = B.LORDS.keys()
	for seed_value: int in range(start,start+count):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var decks: Array = [DeckStore.random_deck(rng),DeckStore.random_deck(rng)]
		var picks: Array = [lords[rng.randi_range(0,lords.size()-1)],lords[rng.randi_range(0,lords.size()-1)]]
		var m := Battle.new(seed_value,decks[0].duplicate(),decks[1].duplicate(),picks[0],picks[1])
		m.difficulty = 1
		m.record_events = false
		m.ai_enabled = [true,true]
		while not m.ended and m.elapsed < cap:
			m.step(1.0/60.0)
			m.events.clear()
		file.store_line(JSON.stringify({"seed":seed_value,"decks":decks,"lords":picks,"winner":m.winner if m.ended else -1,"t":snappedf(m.elapsed,0.1),"breach":snappedf(m.first_breach,0.1),"farms_lost_early":[m.stats[0].farms_lost_early,m.stats[1].farms_lost_early],"used":[m.stats[0].used,m.stats[1].used]}))
		file.flush()
	file.close()
	quit()
