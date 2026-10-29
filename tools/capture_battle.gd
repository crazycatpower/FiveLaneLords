extends SceneTree
# QA screenshot of a real AI-vs-AI battle at a given moment (random decks from the seed).
# Needs a window (no --headless):
#   godot_console --path . -s tools/capture_battle.gd -- --seed=3 --time=90 --out=C:/path/shot.png
const B = preload("res://balance.gd")
const DeckStore = preload("res://deck_store.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var seed_value := 3
	var at := 90.0
	var out := "user://battle-shot.png"
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=",1)
		if arg.begins_with("--seed="): seed_value = int(value)
		elif arg.begins_with("--time="): at = float(value)
		elif arg.begins_with("--out="): out = value
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://capture-deck.json"
	game.sound_enabled = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	game.watch_decks = [DeckStore.random_deck(rng),DeckStore.random_deck(rng)]
	game.watch_lords = [B.LORDS.keys()[seed_value%3],B.LORDS.keys()[(seed_value+1)%3]]
	game.watch_source = [-1,-1]
	game.spectating = true
	game.start_battle()
	game.set_physics_process(false)
	# Fast-forward without effects, then play the last second normally so effects are on screen.
	while game.model.elapsed < at-1.0 and not game.model.ended:
		game.model.step(1.0/60.0)
		game.model.events.clear()
	for i: int in range(60):
		if game.model.ended: break
		game._physics_process(1.0/60.0)
		game._process(1.0/60.0)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	DirAccess.remove_absolute("user://capture-deck.json")
	print("saved ",out," at ",snappedf(game.model.elapsed,0.1)," s")
	quit()
