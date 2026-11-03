extends SceneTree
var g
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	call_deferred("run")
func snap(name: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/mage-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/mage-preview")
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.player_lord = "mage"
	g.player_deck = g.DeckStore.fit_to_lord(g.B.PRESETS[0],"mage")
	g.show_deck()
	await snap("deck")
	g.library.open("lord_mage")
	await snap("codex")
	g.model = g.Battle.new(81,g.player_deck,g.B.PRESETS[0],"mage","lion")
	g.adventure.index = -1
	g.model.ai_enabled = [false,false]
	g.enter_battle("法師領主 · 時間凍結驗收")
	for lane in range(5):
		g.model.spawn_unit(0,lane,"militia",g.L.cell_center(Vector2i(3,lane)))
		g.model.spawn_unit(0,lane,"hunter",g.L.cell_center(Vector2i(2,lane)))
		g.model.spawn_unit(1,lane,"knight",g.L.cell_center(Vector2i(4,lane)))
	g.model.ink[0] = 50
	await snap("before")
	g.model.cast_skill(0)
	for i in range(30): g._physics_process(1.0/60.0)
	await snap("wave")
	for i in range(180): g._physics_process(1.0/60.0)
	await snap("frozen")
	for i in range(96): g._physics_process(1.0/60.0)
	await snap("resumed")
	assert(not g.ui_time_locked())
	g.free()
	print("PASS: mage deck, codex, ripple, freeze and resume captured")
	quit()
