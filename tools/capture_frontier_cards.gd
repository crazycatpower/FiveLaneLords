extends SceneTree
var g
func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	call_deferred("run")
func snap(label: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for c in g.ui:
		if c is RichTextLabel and c.get_content_height() > c.size.y:
			printerr("Text overflow: %s %s / %s" % [label,c.get_content_height(),c.size.y])
			quit(1)
			return
	root.get_texture().get_image().save_png("res://docs/frontier-preview/"+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/frontier-preview")
	g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.sound_enabled=false
	for kind: String in ["manor_retainer","axe_thrower","rolling_boulder"]:
		g.library.open(kind)
		await snap(kind)
	g.model=g.Battle.new(1,["manor_retainer","axe_thrower","rolling_boulder","hunter","militia","rain","knight","healer"],[],"lion","iron")
	g.model.ai_enabled=[false,false]
	g.adventure.index=-1
	g.enter_battle("Frontier card preview")
	for side: int in [0,1]:
		var forward := 1.0 if side == 0 else -1.0
		var cell := Vector2i(2 if side == 0 else 6,1)
		var p: Vector2 = g.L.cell_center(cell)
		var guard: Dictionary = g.model.spawn_unit(side,1,"manor_retainer",p)
		guard.face = -forward
		var axe: Dictionary = g.model.spawn_unit(side,2,"axe_thrower",p+Vector2(0,g.L.CELL_SIZE.y))
		var target: Dictionary = g.model.spawn_unit(1-side,2,"shieldguard",axe.pos+Vector2(70*forward,0))
		g.attack_animation.observe(g.model)
		g.model.attack(axe,target)
		g.model.cast_spell({"kind":"rolling_boulder","team":side,"pos":g.L.cell_center(Vector2i(2 if side == 0 else 6,3 if side == 0 else 4))})
		g.model.spawn_unit(side,3 if side == 0 else 4,"knight",g.L.cell_center(Vector2i(4,3 if side == 0 else 4)))
	for u: Dictionary in g.model.units: u.draw=u.pos+Vector2(0,u.dy)
	g.attack_animation.observe(g.model)
	g.model.update_projectiles(0.12)
	g.model.elapsed += 0.12
	await snap("battle")
	g.model.update_projectiles(0.9)
	g.consume_events()
	await snap("friendly-fire")
	g.free()
	print("PASS: three codex cards, mirrored patrol/axes and rolling friendly fire captured")
	quit()
