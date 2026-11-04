extends SceneTree
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")
const DS = preload("res://deck_store.gd")
func _initialize() -> void:
	call_deferred("run")
func shot(game: Node, name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/faction-expansion-preview/"+name+".png") != OK: quit(1)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/faction-expansion-preview")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://capture-expansion-deck.json"
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	for lord: String in ["underworld","lion"]:
		game.player_lord = lord
		game.player_deck = DS.fit_to_lord(["corpse_giant","curse","catapult","drummer","shieldguard","skeleton","ghoul","militia"],lord)
		for tab: String in ["unit","building","spell"]:
			game.deck_tab = tab
			game.deck_page = 0
			game.show_deck()
			await shot(game,lord+"-"+tab)
	game.player_lord = "underworld"
	game.player_deck = DS.fit_to_lord(["corpse_giant","curse","catapult","drummer","shieldguard","skeleton","ghoul","militia"],"underworld")
	game.start_battle()
	game.model.ai_enabled = [false,false]
	game.model.lord_active = [false,false]
	for team: int in range(2):
		var col := 3 if team == 0 else 5
		game.model.spawn_unit(team,0,"corpse_giant",L.cell_center(Vector2i(col,0)))
		game.model.spawn_unit(team,1,"shieldguard",L.cell_center(Vector2i(col,1)))
		game.model.spawn_unit(team,2,"drummer",L.cell_center(Vector2i(col,2)))
		game.model.spawn_unit(team,2,"militia",L.cell_center(Vector2i(col,2))+Vector2(60 if team == 0 else -60,0))
		game.model.spawn_unit(team,4,"catapult",L.cell_center(Vector2i(col,4)))
	game.model.cast_spell({"kind":"curse","team":0,"pos":L.cell_center(Vector2i(5,1))})
	game.model.build_lookups()
	game.model.update_units(0)
	game.model.update_projectiles(B.CARDS.catapult.flight_time*0.5)
	game.consume_events()
	game.notice = "三陣營擴充：屍爆、詛咒、拋射、鼓舞、盾牆"
	await shot(game,"battle-fixture")
	var giant: Dictionary = game.model.units.filter(func(u: Dictionary) -> bool: return u.kind == "corpse_giant" and u.team == 0)[0]
	game.model.damage(giant,giant.hp,1,"rain")
	game.model.resolve_deaths()
	game.model.remove_dead()
	game.consume_events()
	await shot(game,"death-fade")
	game._process(0.4)
	await shot(game,"death-spawn")
	game.model.units.clear()
	game.model.buildings.clear()
	game.model.projectiles.clear()
	game.effects.clear()
	for team: int in range(2):
		var col := 3 if team == 0 else 5
		game.model.add_building(team,Vector2i(col,0),"bonewall")
		game.model.spawn_unit(team,4,"catapult",L.cell_center(Vector2i(col,4)))
		var reaper: Dictionary = game.model.spawn_unit(team,2,"reaper",L.cell_center(Vector2i(col,2)))
		game.model.event("slash",reaper.pos+Vector2(55 if team == 0 else -55,0),team,{"lane":2})
	game.consume_events()
	await shot(game,"team-directions")
	for b: Dictionary in game.model.buildings:
		game.model.damage(b,b.hp,1-b.team,"rain")
	game.model.remove_dead()
	game.consume_events()
	game._process(0.1)
	await shot(game,"building-death-directions")
	game.free()
	quit()
