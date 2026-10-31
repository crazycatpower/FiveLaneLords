extends RefCounted
const B = preload("res://balance.gd")
const Lore = preload("res://card_lore.gd")
static func run(t: SceneTree) -> void:
	var game = load("res://main.tscn").instantiate()
	t.root.add_child(game)
	game.set_physics_process(false)
	game.deck_path = "user://library-test-deck.json"
	for kind: String in B.CARDS:
		t.check(Lore.TEXT.has(kind) and not Lore.TEXT[kind].strip_edges().is_empty(),"card has authored lore: "+kind)
	for lord: String in B.LORDS:
		t.check(Lore.TEXT.has("lord_"+lord),"lord has lore: "+lord)
	game.library.open()
	t.check(game.library.entries().size() == B.CARDS.size()+B.LORDS.size(),"catalog includes every card and lord")
	game.library.category = "building"
	t.check(game.library.entries().all(func(k): return B.CARDS[k].type == "building"),"catalog building filter")
	game.library.open("lord_underworld")
	t.check(game.screen == "codex" and game.library.selected == "lord_underworld","lord detail opens")
	game.library.back()
	t.check(game.screen == "title","title catalog returns to title")
	game.player_lord = "lion"
	game.player_deck = B.PRESETS[0].duplicate()
	game.difficulty = 2
	game.start_battle()
	var deck_before: String = JSON.stringify(game.model.decks)
	var elapsed: float = game.model.elapsed
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.library.INFO_RECT.get_center()
	game._unhandled_input(click)
	t.check(game.screen == "battle_info" and game.model.paused,"battle info click pauses match")
	t.check(game.model.difficulty == 2,"info reads active match difficulty")
	game._physics_process(1)
	t.check(game.model.elapsed == elapsed,"reading match information cannot advance combat")
	game.library.open(game.model.decks[1][0],"battle_info")
	t.check(game.screen == "codex" and game.model.paused,"enemy card opens paused catalog")
	game.library.back()
	t.check(game.screen == "battle_info" and game.model.paused,"catalog returns to paused roster")
	game.library.close_battle_info()
	t.check(game.screen == "battle" and not game.model.paused,"running battle resumes after reading")
	t.check(JSON.stringify(game.model.decks) == deck_before,"reading never modifies either deck")
	game.model.paused = true
	game.library.show_battle_info()
	game.library.close_battle_info()
	t.check(game.model.paused,"already paused battle stays paused")
	game.free()
	t.finished.card_library = true
