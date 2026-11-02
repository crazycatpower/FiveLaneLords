extends SceneTree
func _initialize() -> void: call_deferred("run")

func snapshot(g, label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for c in g.ui:
		if c is RichTextLabel: assert(c.get_content_height() <= c.size.y, "Dialogue overflow")
	DirAccess.make_dir_recursive_absolute("res://docs/road-toll-preview")
	root.get_texture().get_image().save_png("res://docs/road-toll-preview/"+label+".png")

func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.adventure.progress_path = "user://road-toll-test.json"
	for recruit: String in ["bandit","knight"]:
		g.adventure.recruit = recruit
		g.adventure.cleared = {"first_farm":true}
		g.adventure.start(g,1)
		assert(g.screen == "road_toll_story" and g.model.elapsed == 0)
		g._physics_process(10)
		assert(g.model.elapsed == 0 and g.model.stats[1].plays == 0)
		assert(g.adventure.road_story.lines.any(func(line): return line[2] == recruit))
		while g.screen == "road_toll_story":
			await snapshot(g,recruit+"-intro-"+str(g.adventure.road_story.step))
			g.adventure.road_story.advance(g)
		assert(g.screen == "battle" and g.model.active_lanes == [1,2,3])
		assert(g.model.count_buildings(1,"tower") == 3 and "mob" in g.model.decks[0])
		g._physics_process(0.1)
		assert(g.model.elapsed > 0)
		g.model.finish(0)
		g.adventure.update(g)
		assert(g.screen == "road_toll_story" and g.adventure.road_story.victory)
		assert(g.adventure.is_cleared(1) and g.adventure.selected == 2)
		while g.screen == "road_toll_story":
			await snapshot(g,recruit+"-outro-"+str(g.adventure.road_story.step))
			g.adventure.road_story.advance(g)
		assert(g.screen == "adventure" and g.adventure.selected == 2 and g.adventure.recruit == recruit)
	# A lost battle must not show the victorious discovery of grain.
	g.adventure.start(g,1)
	while g.screen == "road_toll_story": g.adventure.road_story.advance(g)
	g.model.finish(1)
	g.adventure.update(g)
	assert(g.screen == "battle")
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.free()
	await process_frame
	print("PASS: both road-toll branches, paused intro, battle handoff, victory story, bridge unlock and defeat")
	quit()
