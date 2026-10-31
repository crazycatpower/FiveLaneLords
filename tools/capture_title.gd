extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/title-preview")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	for lord: String in game.B.LORDS:
		game.player_lord = lord
		game.show_title()
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.save_png("res://docs/title-preview/%s.png" % lord)
		if lord == "lion": shot.save_png("res://title-preview.png")
	game.free()
	quit()
