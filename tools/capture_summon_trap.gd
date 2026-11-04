extends SceneTree
var g
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	call_deferred("run")
func snap(name: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for c in g.ui:
		if c is RichTextLabel: assert(c.get_content_height() <= c.size.y,"Text overflow")
	root.get_texture().get_image().save_png("res://docs/summon-trap-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/summon-trap-preview")
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	for kind: String in ["summon_trap","chimera"]:
		g.library.open(kind)
		await snap(kind)
	g.model = g.Battle.new(92,[],[],"rune","rune")
	g.model.ai_enabled = [false,false]
	g.adventure.index = -1
	g.enter_battle("Summon preview")
	var traps: Array = []
	for side: int in [0,1]:
		traps.append(g.model.add_building(side,Vector2i(3 if side == 0 else 5,2),"summon_trap"))
	await snap("ready")
	for charge: int in range(3):
		for side: int in [0,1]:
			var u: Dictionary = g.model.spawn_unit(1-side,2,"militia",traps[side].pos)
			u.spawn_delay = 0
		preload("res://arcane_mechanics.gd").update_traps(g.model)
		g.consume_events()
		for u: Dictionary in g.model.units:
			u.spawn_delay = 0
			if u.kind == "chimera":
				u.pos.x += 35 if u.team == 0 else -35
				u.draw = u.pos+Vector2(0,u.dy)
		for e in g.effects: e.life = e.duration*.6
		await snap("charges-"+str(2-charge))
	g.free()
	print("PASS: summon trap screenshots captured")
	quit()
