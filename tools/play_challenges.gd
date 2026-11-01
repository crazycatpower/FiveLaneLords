extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var failures := 0
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	for scenario in [1,2]:
		g.challenge.start(g,scenario)
		while not g.model.ended and g.model.elapsed < 181:
			g.model.cast_skill(0)
			if scenario == 1:
				for slot in range(4):
					g.model.play(0,slot,g.L.cell_center(Vector2i(0,2)))
			g._physics_process(1.0/30.0)
		print("PLAYTHROUGH scenario=%d time=%.1f winner=%d produced=%.1f skills=%d" % [scenario,g.model.elapsed,g.model.winner,g.model.stats[0].produced,g.model.stats[0].get("skills",0)])
		if g.model.winner != 0: failures += 1
	g.free()
	quit(1 if failures else 0)
