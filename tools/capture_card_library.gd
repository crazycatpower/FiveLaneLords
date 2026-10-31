extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/card-library-preview")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	for kind: String in ["farm","grave","guard","lord_underworld"]:
		game.library.open(kind)
		await snap(kind)
	game.show_watch()
	game.watch_lords = ["lion","underworld"]
	game.watch_decks[0] = game.DeckStore.fit_to_lord(game.B.PRESETS[0].duplicate(),"lion")
	game.watch_decks[1] = game.DeckStore.fit_to_lord(game.B.PRESETS[0].duplicate(),"underworld")
	game.spectating = true
	game.start_battle()
	game.library.show_battle_info()
	await snap("battle-info")
	game.library.close_battle_info()
	await snap("battle")
	game.free()
	quit()
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/card-library-preview/"+name+".png")
