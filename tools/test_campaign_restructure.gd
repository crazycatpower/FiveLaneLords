extends SceneTree
func _initialize() -> void: call_deferred("run")

func capture(g, label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for c in g.ui:
		if c is RichTextLabel: assert(c.get_content_height() <= c.size.y, "Dialogue overflow: "+c.text)
	if label.is_empty(): return
	DirAccess.make_dir_recursive_absolute("res://docs/campaign-restructure")
	root.get_texture().get_image().save_png("res://docs/campaign-restructure/"+label+".png")

func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.adventure.progress_path = "user://campaign-restructure-test.json"
	assert(g.adventure.STAGES.size() == 10)
	for recruit: String in ["bandit","knight"]:
		g.adventure.cleared = {}
		g.adventure.custom_deck = []
		g.adventure.recruit = recruit
		for stage: int in range(10):
			var before: Array = g.adventure.unlocked_cards()
			g.adventure.start(g,stage)
			assert(g.adventure.index == stage)
			assert(g.adventure.unlocked_cards() == before, "Starting must not award cards")
			assert(g.model.invasion_victory == [true,true])
			for k: String in g.model.decks[1]:
				assert(g.model.decks[1].count(k) == g.adventure.STAGES[stage].enemy_deck.count(k))
			assert(g.DeckStore.valid(g.model.decks[1],g.model.lords[1].lord,true))
			var kinds: Dictionary = {}
			for k: String in g.model.decks[1]:
				assert(g.B.CARDS.has(k))
				kinds[k] = true
			assert(kinds.size() == mini(stage+1,8))
			assert(g.model.lord_active[1] == (stage == 9))
			if stage < 3: assert(g.model.home_cards[1].is_empty())
			while g.screen == "road_toll_story":
				var step: int = g.adventure.road_story.step
				await capture(g,"stage-%d-intro" % (stage+1) if recruit == "bandit" and step == 0 else "")
				g.adventure.road_story.advance(g)
			g.model.finish(0)
			g.adventure.update(g)
			assert(g.adventure.is_cleared(stage))
			var rewards: Array = g.adventure.STAGES[stage].rewards
			for card: String in rewards: assert(card in g.adventure.unlocked_cards())
			while g.screen == "road_toll_story":
				var step: int = g.adventure.road_story.step
				await capture(g,"stage-%d-outro" % (stage+1) if recruit == "bandit" and step == 0 else "")
				g.adventure.road_story.advance(g)
			assert(g.adventure.recruit == recruit)
			var restored = load("res://adventure.gd").new()
			restored.progress_path = g.adventure.progress_path
			restored.load_progress()
			assert(restored.unlocked_cards() == g.adventure.unlocked_cards())
		assert(g.adventure.cleared_count() == 10)
		assert(["knight","drummer","fire","ox","harvest","shieldguard","tower","catapult"].all(func(k): return k in g.adventure.unlocked_cards()))
		g.adventure.show(g)
		await capture(g,"completed-map")
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.free()
	await process_frame
	print("PASS: ten-stage enemy progression, both recruits, all dialogue, rewards and persistence")
	quit()
