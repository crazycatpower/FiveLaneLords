extends SceneTree
# Worker for tools/autobalance.py and tools/evolve_ai.py: plays random-deck, random-lord AI matches
# and writes one JSON line per match. Same seed -> same decks, lords and match.
#   godot_console --headless --path . -s tools/random_sim.gd -- --start=1 --count=100 --out=PATH [--cap=900]
# AI strategy weights (enemy_ai.gd params; a JSON object, {} = the hand-written AI):
#   --params-red=FILE --params-blue=FILE   weights for each side
#   --mirror --cand=FILE [--base=FILE]     both sides get the same deck and lord; every seed is played
#                                          twice, the candidate once as red and once as blue
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const DeckStore = preload("res://deck_store.gd")

func read_params(path: String) -> Dictionary:
	if path.is_empty(): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _initialize() -> void:
	var start := 1
	var count := 10
	var cap := 900.0
	var out := "user://random_sim.jsonl"
	var mirror := false
	var paths := {"red":"","blue":"","cand":"","base":""}
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=",1)
		if arg.begins_with("--start="): start = int(value)
		elif arg.begins_with("--count="): count = int(value)
		elif arg.begins_with("--cap="): cap = float(value)
		elif arg.begins_with("--out="): out = value
		elif arg == "--mirror": mirror = true
		elif arg.begins_with("--params-red="): paths.red = value
		elif arg.begins_with("--params-blue="): paths.blue = value
		elif arg.begins_with("--cand="): paths.cand = value
		elif arg.begins_with("--base="): paths.base = value
	var cand := read_params(paths.cand)
	var base := read_params(paths.base)
	var file := FileAccess.open(out,FileAccess.WRITE)
	var lords: Array = B.LORDS.keys()
	for seed_value: int in range(start,start+count):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var decks: Array = [DeckStore.random_deck(rng),DeckStore.random_deck(rng)]
		var picks: Array = [lords[rng.randi_range(0,lords.size()-1)],lords[rng.randi_range(0,lords.size()-1)]]
		if mirror:
			decks[1] = decks[0].duplicate()
			picks[1] = picks[0]
			for cand_side: int in range(2):
				var params: Array = [cand,base] if cand_side == 0 else [base,cand]
				var r := play(seed_value,decks,picks,params,cap)
				r.cand_side = cand_side
				file.store_line(JSON.stringify(r))
		else:
			file.store_line(JSON.stringify(play(seed_value,decks,picks,[read_params(paths.red),read_params(paths.blue)],cap)))
		file.flush()
	file.close()
	quit()

func play(seed_value: int, decks: Array, picks: Array, params: Array, cap: float) -> Dictionary:
	var m := Battle.new(seed_value,decks[0].duplicate(),decks[1].duplicate(),picks[0],picks[1])
	m.difficulty = 1
	m.record_events = false
	m.ai_enabled = [true,true]
	var first_play: Array = [{},{}]
	var observed_plays: Array[int] = [0,0]
	m.ai_params = [params[0],params[1]]
	while not m.ended and m.elapsed < cap:
		m.step(1.0/60.0)
		# Read counters only. Do not enable events or consume random values.
		for team: int in range(2):
			if m.stats[team].plays == observed_plays[team]: continue
			observed_plays[team] = m.stats[team].plays
			for kind: String in m.stats[team].used:
				if not first_play[team].has(kind): first_play[team][kind] = m.elapsed
		m.events.clear()
	return {"seed":seed_value,"decks":decks,"lords":picks,"winner":m.winner if m.ended else -1,"t":snappedf(m.elapsed,0.1),"breach":snappedf(m.first_breach,0.1),"farms_lost_early":[m.stats[0].farms_lost_early,m.stats[1].farms_lost_early],"skills":[m.stats[0].get("skills",0),m.stats[1].get("skills",0)],"used":[m.stats[0].used,m.stats[1].used],"card_stats":[card_stats(m,0,decks[0],first_play[0]),card_stats(m,1,decks[1],first_play[1])],"damage_by_kind":[m.stats[0].damage,m.stats[1].damage]}

func card_stats(m: RefCounted, team: int, deck: Array, first: Dictionary) -> Dictionary:
	var result := {}
	for kind: String in ["farm"]+deck:
		result[kind] = {
			"plays":m.stats[team].used.get(kind,0),
			"first_play":first.get(kind,null),
			"spent":m.stats[team].spent.get(kind,0.0),
			# Combat buckets are unit kinds, not originating cards. Legion damage cannot be
			# recovered from them; null means unavailable, not zero damage.
			"damage":null if B.CARDS[kind].has("members") else m.stats[team].damage.get(kind,0.0)
		}
	return result
