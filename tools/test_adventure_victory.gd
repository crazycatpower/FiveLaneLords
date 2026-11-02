extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.adventure.progress_path = "user://normal-victory-test.json"
	g.adventure.recruit = "knight"
	for i: int in range(g.adventure.STAGES.size()):
		g.adventure.start(g,i)
		assert(g.adventure.index == i)
		assert(g.model.invasion_victory == [true,true])
		assert(not g.adventure.STAGES[i].has("limit"))
		g.model.elapsed = 1000
		g.model.stats[0].produced = 10000
		g.model.stats[0].skills = 100
		g.adventure.update(g)
		assert(not g.model.ended and g.adventure.outcome.is_empty())
		g.review.break_lane = 0
		g.model.finish(0)
		g.adventure.update(g)
		assert(g.model.winner == 0 and g.adventure.is_cleared(i))
		g.adventure.start(g,i)
		g.model.finish(1)
		g.adventure.update(g)
		assert(g.model.winner == 1 and g.adventure.outcome.begins_with("挑戰失敗"))
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.free()
	print("PASS: all nine stages use normal victory; no time, lane, gold or skill objectives")
	quit()
