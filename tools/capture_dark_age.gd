extends SceneTree
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")
const DECK := ["militia","skeleton","ghoul","necromancer","reaper","raven","plague","bonewall"] # the tombstone is the underworld lord's home card, not one of the eight
func _initialize() -> void:
	call_deferred("run")
func shot(game: Node, name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/dark-age-preview/"+name+".png") != OK:
		quit(1)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/dark-age-preview")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.deck_path = "user://capture-dark-deck.json" # never overwrite the player's saved deck
	game.player_deck = DECK.duplicate()
	game.player_lord = "underworld"
	for tab: String in ["unit","building","spell"]:
		game.deck_tab = tab
		for page: int in range(ceili(game.tab_size()/8.0)):
			game.deck_page = page
			game.show_deck()
			await shot(game,"deck-"+tab+str(page))
	game.show_watch()
	await shot(game,"watch")
	game.start_battle()
	game.model = Battle.new(31,DECK,DECK,"underworld","underworld")
	game.model.ai_enabled = [false,false]
	game.model.lord_active = [false,false]
	for team: int in range(2):
		for lane: int in [0,2,4]: game.model.add_building(team,Vector2i(1 if team == 0 else 7,lane),"grave")
		game.model.add_building(team,Vector2i(3 if team == 0 else 5,3),"bonewall")
		for i: int in range(5):
			game.model.spawn_unit(team,i,["skeleton","ghoul","necromancer","reaper","raven"][i],L.cell_center(Vector2i(3 if team == 0 else 5,i)))
		game.model.ink[team] = 30
		game.model.cast_skill(team)
	game.model.cast_spell({"kind":"plague","team":0,"pos":L.cell_center(Vector2i(4,1))})
	game.consume_events()
	await shot(game,"battle-fixture")
	game.model = Battle.new(17,DECK,B.PRESETS[1],"underworld","iron")
	game.model.record_events = false
	game.model.ai_enabled = [true,true]
	while game.model.elapsed < 90 and not game.model.ended: game.model.step(1.0/60.0)
	game.effects.clear()
	game.queue_redraw()
	await shot(game,"battle-live")
	game.free()
	quit()
