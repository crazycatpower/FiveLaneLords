extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.adventure.progress_path = "user://three-lane-test.json"
	for recruit: String in ["bandit","knight"]:
		g.adventure.recruit = recruit
		g.adventure.start(g,1)
		while g.screen == "road_toll_story": g.adventure.road_story.advance(g)
		assert(g.adventure.index == 1 and g.model.active_lanes == [1,2,3])
		assert(recruit in g.model.decks[0] and "mob" in g.model.decks[0])
		assert(g.model.count_buildings(1,"tower") == 3)
		for lane: int in [0,4]:
			assert(not g.model.can_play(0,g.Battle.FARM_SLOT,g.L.cell_center(Vector2i(0,lane))))
		for lane: int in [1,2,3]:
			assert(g.model.buildings.any(func(b): return b.team == 1 and b.kind == "tower" and b.cell == Vector2i(7,lane)))
		g.model.decks[0] = g.adventure.stage_deck(g,1)
		g.model.hand_cd[0][0] = 0
		assert(g.model.play(0,0,g.L.cell_center(Vector2i(0,2))))
		for lane: int in [1,2,3]:
			assert(g.model.units.filter(func(u): return u.kind == "mob" and u.lane == lane).size() == g.B.CARDS.mob.count)
		for tick: int in range(600): g._physics_process(1.0/60)
		assert(g.model.stats[1].plays > 0)
		for u in g.model.units: assert(u.lane in [1,2,3])
		for b in g.model.buildings: assert(b.cell.y in [1,2,3])
	g.adventure.start(g,1)
	while g.screen == "road_toll_story": g.adventure.road_story.advance(g)
	if "--capture" in OS.get_cmdline_user_args():
		g.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://docs/three-lane-preview")
		root.get_texture().get_image().save_png("res://docs/three-lane-preview/start.png")
	g.model.elapsed = 90
	g.adventure.update(g)
	assert(not g.model.ended)
	g.model.finish(0)
	g.adventure.update(g)
	assert(g.model.winner == 0 and g.adventure.is_cleared(1))
	g.adventure.start(g,2)
	assert(g.model.active_lanes.size() == 5)
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.free()
	print("PASS: three lanes, militia mob spread, towers, both recruits, normal AI and normal victory")
	quit()
