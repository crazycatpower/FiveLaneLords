extends SceneTree
# Records trailer footage with Godot's Movie Maker (fixed 30 fps, independent of machine speed).
# Both sides are played by the AI but the screen is the player's view (red hand, gold, lords).
#   godot_console --path . --write-movie C:/out/battle.avi --fixed-fps 30 -s tools/record_trailer.gd -- --shot=battle
# Shots: battle (mid-game, all lanes), lion (獅王號令), underworld (亡者大軍), finale (gate falls, red wins).
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const DeckStore = preload("res://deck_store.gd")

var game
var shot := "battle"
var frame := 0
var length := 300 # frames to record
var cast_at := -1 # frame on which red casts its lord skill (-1 = never)
var tail := -1 # frames still to record after the match ends (finale)
var ready := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.get_slice("=",1)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://trailer-deck.json"
	call_deferred("prepare") # after the game's own _ready (which shows the title screen)

func prepare() -> void:
	match shot:
		"battle":
			setup(7,"lion","underworld",58.0)
			length = 30*12
		"lion":
			setup(11,"lion","iron",48.0)
			length = 30*6
			cast_at = 20
		"underworld":
			setup(12,"underworld","harvest",50.0)
			length = 30*6
			cast_at = 20
		"finale":
			var found := find_red_win()
			setup(found.seed,found.red,found.blue,maxf(0.0,found.end-7.0))
			length = 30*14
	print("shot %s ready at %.1f s" % [shot,game.model.elapsed])
	ready = true

# A battle with seeded random decks, fast-forwarded (no drawing) to the moment recording starts.
func setup(seed_value: int, red: String, blue: String, start: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var decks := [DeckStore.random_deck(rng,red),DeckStore.random_deck(rng,blue)]
	game.spectating = false
	game.model = Battle.new(seed_value,decks[0],decks[1],red,blue)
	game.model.difficulty = 1
	game.model.ai_enabled = [true,true]
	game.enter_battle("")
	while game.model.elapsed < start and not game.model.ended:
		game.model.step(1.0/60.0)
		game.model.events.clear()
	game.notice = ""

func find_red_win() -> Dictionary:
	for seed_value: int in range(1,80):
		for pair: Array in [["lion","underworld"],["harvest","underworld"],["iron","underworld"]]:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var m := Battle.new(seed_value,DeckStore.random_deck(rng,pair[0]),DeckStore.random_deck(rng,pair[1]),pair[0],pair[1])
			m.record_events = false
			m.ai_enabled = [true,true]
			while not m.ended and m.elapsed < 300.0: m.step(1.0/60.0)
			if m.ended and m.winner == 0 and m.elapsed > 90.0: return {"seed":seed_value,"red":pair[0],"blue":pair[1],"end":m.elapsed}
	return {"seed":1,"red":"lion","blue":"underworld","end":120.0}

func _process(_delta: float) -> bool:
	if not ready: return false
	frame += 1
	if frame == cast_at:
		game.model.ink[0] = B.skill_cost(game.model.lords[0].lord)
		game.model.skill_cd[0] = 0.0
		game.model.lords[0].hp = maxf(game.model.lords[0].hp,1.0)
		game.model.cast_skill(0)
	if shot == "finale" and game.model.ended and tail < 0: tail = 30*3
	if tail >= 0:
		tail -= 1
		return tail <= 0
	return frame >= length
