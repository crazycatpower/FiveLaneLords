extends SceneTree
func _initialize() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.model = g.Battle.new(53,[],[],"adventure","adventure")
	g.adventure.index = -1
	g.model.ai_enabled = [false,false]
	g.enter_battle("破陣斬 · 10 金幣 · 前方三格")
	for team in [0,1]:
		g.model.lords[team].pos = g.L.cell_center(Vector2i(1 if team == 0 else 7,1 if team == 0 else 3))
		for i in range(1,4):
			g.model.spawn_unit(1-team,1 if team == 0 else 3,"knight",g.model.lords[team].pos+Vector2((1 if team == 0 else -1)*g.L.CELL_SIZE.x*i,0))
		g.model.ink[team] = 10
		g.model.cast_skill(team)
	g.consume_events()
	for e in g.effects: e.life = e.duration*0.65
	g.attack_animation.observe(g.model)
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/hero-slash-preview.png")
	g.free()
	print("PASS: red/blue three-cell slash captured")
	quit()
