extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/progression-preview")
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.sound_enabled = false
	g.show_challenges()
	await snap("challenges")
	g.challenge.start(g,0)
	g.model.gates[0][2] = 0
	for i: int in range(9): g.model.spawn_unit(1,2,"militia",g.L.cell_center(Vector2i(0,2))+Vector2(i*14,0))
	g.queue_redraw()
	await snap("pressure")
	g.model.elapsed = 75
	g.model.events.append({"kind":"invaded","team":1,"lane":2,"unit_kind":"militia"})
	g.model.finish(1)
	g.consume_events()
	g.challenge.update(g)
	g.queue_redraw()
	await snap("result")
	g.show_review()
	await snap("review")
	for i: int in range(3):
		g.challenge.start(g,i)
		g.model.ai_enabled[0] = true
		while not g.model.ended and g.model.elapsed < 181: g._physics_process(1.0/30.0)
		print("scenario %d: time %.1f winner %d produced %.1f skill %d" % [i,g.model.elapsed,g.model.winner,g.model.stats[0].produced,g.model.stats[0].get("skills",0)])
		g.queue_redraw()
		await snap("scenario-%d" % i)
	g.free()
	quit()
func snap(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/progression-preview/"+label+".png")
