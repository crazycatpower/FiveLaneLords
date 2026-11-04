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
	root.get_texture().get_image().save_png("res://docs/dark-wizard-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/dark-wizard-preview")
	g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.sound_enabled=false
	g.library.open("dark_wizard")
	await snap("codex")
	g.model=g.Battle.new(1,[],[],"vampire","vampire")
	g.model.ai_enabled=[false,false]
	g.adventure.index=-1
	g.enter_battle("Wizard preview")
	var wizards: Array=[]
	for side: int in [0,1]:
		var cell:=Vector2i(2 if side == 0 else 6,2)
		g.model.deploy(side,"dark_wizard",cell)
		var u: Dictionary=g.model.units.back()
		u.draw=u.pos+Vector2(0,u.dy)
		wizards.append(u)
		var ally: Dictionary=g.model.spawn_unit(side,3,"knight",u.pos+Vector2(0,g.L.CELL_SIZE.y))
		ally.draw=ally.pos+Vector2(0,ally.dy)
	await snap("rear-deploy")
	for side: int in [0,1]: g.model.damage(wizards[side],10000,1-side,"rain")
	g.consume_events()
	for e in g.effects: e.life=e.duration*.55
	await snap("absorb")
	g.effects.clear()
	for side: int in [0,1]:
		var target: Dictionary=g.model.spawn_unit(1-side,2,"militia",wizards[side].pos+Vector2(100 if side == 0 else -100,0))
		g.model.attack(wizards[side],target)
	g.model.update_projectiles(g.B.ARROW_TIME*.5)
	g.attack_animation.observe(g.model)
	g.model.elapsed+=.1
	await snap("attack")
	g.free()
	print("PASS: dark wizard codex, mirrored rear deployment, soul absorption and attack captured")
	quit()
