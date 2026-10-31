extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var start := Time.get_ticks_msec()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	var elapsed := Time.get_ticks_msec()-start
	var prepared := 0
	for kind: String in game.textures:
		if game.blue_art[kind] == game.textures[kind]: continue
		if not game.blue_art[kind].resource_path.begins_with("res://assets/generated-palette/"):
			push_error("Runtime conversion instead of prepared asset: "+kind)
			quit(1)
			return
		prepared += 1
	if game.screen != "title" or prepared == 0:
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://title-preview.png")
	print("PASS direct title: %d ms, %d prepared palette references, no runtime conversion" % [elapsed,prepared])
	game.free()
	quit()
