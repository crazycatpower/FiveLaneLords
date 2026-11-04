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
		if c is RichTextLabel and c.get_content_height() > c.size.y:
			printerr("Text overflow: "+str(c.get_content_height())+" / "+str(c.size.y))
			quit(1)
			return
	root.get_texture().get_image().save_png("res://docs/lord-priority-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/lord-priority-preview")
	g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.sound_enabled=false
	g.model=g.Battle.new(1,[],[],"lion","iron")
	g.model.ai_enabled=[false,false]
	g.adventure.index=-1
	g.enter_battle("Defense priority")
	for side: int in [0,1]:
		var home: float=g.L.gate_stop(side)
		var direction:=1 if side == 0 else -1
		var lord: Dictionary=g.model.lords[side]
		lord.pos.y=g.L.cell_center(Vector2i(0,2)).y
		lord.hp=lord.max_hp*.15
		lord.last_hit=g.model.elapsed
		for i in range(4): g.model.spawn_unit(1-side,2,"knight",Vector2(home+direction*(70+i*20),lord.pos.y))
		g.model.gates[side][3]=0
		g.model.spawn_unit(1-side,3,"militia",Vector2(home-direction*25,g.L.cell_center(Vector2i(0,3)).y))
	await snap("before")
	for i in range(90):
		for lord in g.model.lords: g.model.Lord.step(g.model,lord,1.0/60)
		g.model.elapsed+=1.0/60
	g.consume_events()
	await snap("return-to-defend")
	g.free()
	print("PASS: mirrored rear-intruder defense captured")
	quit()
