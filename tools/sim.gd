extends SceneTree
# T9 balance simulator: AI vs AI, fixed 1/60 s steps, reproducible per seed. Run ONCE and read
# the report; do not loop it while tuning numbers.
#
#   godot_console --headless --path . -s tools/sim.gd -- [options]
#     --matrix              every preset against every other preset (default)
#     --deck-a=0|1|2|card,card,...   --deck-b=...   one pairing instead of the matrix
#     --games=N             seeds per pairing (default 4)
#     --seed=N              first seed (default 1)
#     --difficulty=0|1|2    AI difficulty for both sides (default 1)
#     --cap=SECONDS         stop a match unresolved after this long (default 900)
#     --output=PATH         JSON report (default user://simulation.json)
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const DeckStore = preload("res://deck_store.gd")

var first_seed := 1
var games := 4
var difficulty := 1
var cap := 900.0
var deck_a := ""
var deck_b := ""
var output := "user://simulation.json"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=",1)
		if arg.begins_with("--seed="): first_seed = int(value)
		elif arg.begins_with("--games="): games = maxi(1,int(value))
		elif arg.begins_with("--difficulty="): difficulty = clampi(int(value),0,2)
		elif arg.begins_with("--cap="): cap = float(value)
		elif arg.begins_with("--deck-a="): deck_a = value
		elif arg.begins_with("--deck-b="): deck_b = value
		elif arg.begins_with("--output="): output = value
	call_deferred("run")

func parse_deck(value: String) -> Array:
	if value.is_valid_int(): return B.PRESETS[clampi(int(value),0,2)].duplicate()
	return Array(value.split(","))

# Presets bring their own lord; custom decks use the neutral one.
func lord_for(deck: Array) -> String:
	var index := B.PRESETS.find(deck)
	return B.PRESET_LORDS[index] if index >= 0 else "lion"

func deck_name(deck: Array) -> String:
	var index := B.PRESETS.find(deck)
	return B.PRESET_NAMES[index] if index >= 0 else ",".join(deck)

func play_match(a: Array, b: Array, seed_value: int) -> Dictionary:
	var m := Battle.new(seed_value,a.duplicate(),b.duplicate(),lord_for(a),lord_for(b))
	m.difficulty = difficulty
	m.ai_enabled = [true,true]
	var first_breach := -1.0
	var samples: Array = []
	var next_sample := 30.0
	while not m.ended and m.elapsed < cap:
		m.step(1.0/60.0)
		for e: Dictionary in m.events:
			if e.kind == "breach" and first_breach < 0: first_breach = m.elapsed
		m.events.clear()
		if m.elapsed >= next_sample:
			samples.append({"t":int(next_sample),"rate":[snappedf(m.production_rate(0),0.01),snappedf(m.production_rate(1),0.01)],"farms":[m.count_buildings(0),m.count_buildings(1)],"ink":[int(m.ink[0]),int(m.ink[1])]})
			next_sample += 30.0
	return {"seed":seed_value,"a":deck_name(a),"b":deck_name(b),"winner":m.winner if m.ended else -1,"seconds":snappedf(m.elapsed,0.1),"first_breach":snappedf(first_breach,0.1),"stats":m.stats.duplicate(true),"samples":samples}

func run() -> void:
	var pairs: Array = []
	if deck_a.is_empty() or deck_b.is_empty():
		for i: int in range(3):
			for j: int in range(3):
				if i != j: pairs.append([B.PRESETS[i],B.PRESETS[j]])
	else:
		var a := parse_deck(deck_a)
		var b := parse_deck(deck_b)
		if not DeckStore.valid(a) or not DeckStore.valid(b):
			printerr("Invalid deck: use 0/1/2 or eight unique card ids (farmland is always in its own slot)")
			quit(1)
			return
		pairs.append([a,b])
	var matches: Array = []
	var deck_record := {}   # deck name -> [wins, losses, unresolved]
	var card_used := {}
	var card_spent := {}
	var card_damage := {}
	var produced := 0.0
	var wasted := 0.0
	for pair: Array in pairs:
		for g: int in range(games):
			var r := play_match(pair[0],pair[1],first_seed+g)
			matches.append(r)
			print("%-6s vs %-6s seed %d -> %s at %d s (first breach %s)" % [r.a,r.b,r.seed,["red","blue"][r.winner] if r.winner >= 0 else "none",int(r.seconds),str(int(r.first_breach)) if r.first_breach >= 0 else "-"])
			for side: int in range(2):
				var name: String = r.a if side == 0 else r.b
				if not deck_record.has(name): deck_record[name] = [0,0,0]
				if r.winner < 0: deck_record[name][2] += 1
				elif r.winner == side: deck_record[name][0] += 1
				else: deck_record[name][1] += 1
				var st: Dictionary = r.stats[side]
				produced += st.produced
				wasted += st.wasted
				for kind: String in st.used: card_used[kind] = card_used.get(kind,0)+st.used[kind]
				for kind: String in st.spent: card_spent[kind] = card_spent.get(kind,0.0)+st.spent[kind]
				for kind: String in st.damage: card_damage[kind] = card_damage.get(kind,0.0)+st.damage[kind]
	var resolved: Array = matches.filter(func(r: Dictionary) -> bool: return r.winner >= 0)
	var lengths: Array = resolved.map(func(r: Dictionary) -> float: return r.seconds)
	lengths.sort()
	print("\n== summary (%d matches, difficulty %d, cap %d s)" % [matches.size(),difficulty,int(cap)])
	print("unresolved: %d   median length of decided games: %s s" % [matches.size()-resolved.size(),str(int(lengths[lengths.size()/2])) if not lengths.is_empty() else "-"])
	for name: String in deck_record:
		var rec: Array = deck_record[name]
		print("%-8s won %d  lost %d  unresolved %d  (win rate of decided %d%%)" % [name,rec[0],rec[1],rec[2],roundi(100.0*rec[0]/maxi(1,rec[0]+rec[1]))])
	print("ink wasted at the 50 cap: %.1f%% of production" % (100.0*wasted/maxf(1,produced)))
	var rows: Array = []
	var total_ratio := 0.0
	var counted := 0
	for kind: String in card_used:
		var ratio: float = card_damage.get(kind,0.0)/maxf(1,card_spent.get(kind,0.0))
		rows.append([kind,card_used[kind],ratio])
		if card_damage.get(kind,0.0) > 0:
			total_ratio += ratio
			counted += 1
	rows.sort_custom(func(x: Array,y: Array) -> bool: return x[2] > y[2])
	var average := total_ratio/maxi(1,counted)
	print("damage per ink (average of damaging cards %.1f):" % average)
	for row: Array in rows:
		print("  %-6s %2d ink  played %4d  damage/ink %6.1f%s" % [B.CARDS[row[0]].name,B.CARDS[row[0]].cost,row[1],row[2],"  <- over 2x average" if row[2] > 2*average else ""])
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"difficulty":difficulty,"cap":cap,"matches":matches},"  "))
		print("report: ",ProjectSettings.globalize_path(output))
	quit()
