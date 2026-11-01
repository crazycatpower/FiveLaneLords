extends SceneTree
func _initialize(): call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute("res://docs/opening-preview")
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.sound_enabled = false
	g.adventure.start(g,0)
	for at in [5,9,13,18,23,35]:
		while g.model.elapsed < at and not g.model.ended:
			g._physics_process(1.0/60)
			g._process(1.0/60)
		g.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/opening-preview/%d.png" % at)
	g.free()
	quit()
