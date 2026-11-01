extends SceneTree
# Screenshots of the adventure map and a stage in progress (docs/progression-preview), then each
# scripted stage autoplayed by the player AI as a rough difficulty check. Uses its own progress file.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/progression-preview")
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.sound_enabled = false
	g.adventure.progress_path = "user://capture-adventure.json"
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.show_title()
	await snap("title")
	g.adventure.load_progress()
	for i: int in range(4): g.adventure.cleared[g.adventure.STAGES[i].id] = true
	g.adventure.save_progress()
	g.adventure.selected = 4
	g.show_adventure()
	await snap("adventure")
	g.show_title()
	await snap("title-progress")
	g.adventure.start(g,4)
	g.model.elapsed = 60
	g.adventure.update(g)
	g.queue_redraw()
	await snap("stage")
	g.model.elapsed = 120
	g.adventure.update(g)
	g.queue_redraw()
	await snap("result")
	for i: int in range(g.adventure.STAGES.size()):
		g.adventure.start(g,i)
		g.model.ai_enabled[0] = true
		while not g.model.ended and g.model.elapsed < 600:
			if g.adventure.STAGES[i].kind != "conquer" or g.model.elapsed > 1: g.model.cast_skill(0)
			g._physics_process(1.0/30.0)
		print("stage %d %s: time %.1f winner %d outcome %s produced %.1f" % [i+1,g.adventure.STAGES[i].name,g.model.elapsed,g.model.winner,g.adventure.outcome,g.model.stats[0].produced])
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.free()
	quit()
func snap(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/progression-preview/"+label+".png")
