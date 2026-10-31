extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var start := Time.get_ticks_msec()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	print("main ready: %d ms" % (Time.get_ticks_msec()-start))
	game.free()
	quit()
