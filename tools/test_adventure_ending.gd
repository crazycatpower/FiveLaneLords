extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(g, name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/ending-preview")
	root.get_texture().get_image().save_png("res://docs/ending-preview/"+name+".png")
	for control in g.ui:
		if control is RichTextLabel:
			assert(control.get_content_height() <= control.size.y, "Dialogue overflows: "+control.text)

func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.adventure.progress_path = "user://ending-regression.json"
	for recruit: String in ["bandit","knight"]:
		g.adventure.cleared = {}
		g.adventure.recruit = ""
		g.adventure.start(g,0)
		g.model.finish(0)
		g.adventure.update(g)
		assert(g.screen == "adventure_ending")
		assert(not g.adventure.is_cleared(0))
		assert(g.adventure.ending.step == 0)
		await capture(g,"plea")
		g.adventure.ending.step = 1
		g.adventure.ending.show(g)
		await capture(g,"knight")
		g.adventure.ending.step = 2
		g.adventure.ending.show(g)
		await capture(g,"choice")
		g.adventure.ending.choose(g,recruit)
		assert(g.adventure.recruit == recruit and g.adventure.is_cleared(0))
		assert(g.adventure.ending.step == 3)
		g.adventure.ending.choose(g,"knight" if recruit == "bandit" else "bandit")
		assert(g.adventure.recruit == recruit, "Double click must not change reward")
		await capture(g,"reward-"+recruit)
		var restored = load("res://adventure.gd").new()
		restored.progress_path = g.adventure.progress_path
		restored.load_progress()
		assert(restored.recruit == recruit and restored.unlocked(1))
		var deck: Array = restored.stage_deck(g,1)
		assert(recruit in deck and deck.size() == 8)
		assert(g.DeckStore.valid(deck,restored.stage_lord(g,1)))
		assert(not recruit in restored.stage_deck(g,0), "Opening deck must stay unchanged")
		g.adventure.start(g,0)
		g.model.finish(0)
		g.adventure.update(g)
		assert(g.screen == "battle", "Replay must not award again")
	g.adventure.recruit = ""
	g.adventure.start(g,0)
	g.model.finish(1)
	g.adventure.update(g)
	assert(g.screen == "battle" and g.adventure.recruit.is_empty())
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.free()
	print("PASS: ending dialogue, both rewards, persistence, deck delivery, replay and defeat")
	quit()
