extends SceneTree
func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	call_deferred("run")
var g
func snap(name: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for c in g.ui:
		if c is RichTextLabel: assert(c.get_content_height() <= c.size.y,"Text overflow: "+c.text)
	root.get_texture().get_image().save_png("res://docs/arcane-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/arcane-preview")
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	for kind: String in ["artificer","crystal","teleport_trap","blast_trap","arcane_tower"]:
		g.library.open(kind)
		await snap(kind)
	g.model = g.Battle.new(57,["artificer","crystal","teleport_trap","blast_trap","arcane_tower","hunter","militia","barricade"])
	g.adventure.index = -1
	g.model.ai_enabled = [false,false]
	g.model.buildings.clear()
	g.model.units.clear()
	for team: int in [0,1]:
		for lane: int in range(3):
			var crystal: Dictionary = g.model.add_building(team,Vector2i(1 if team == 0 else 7,lane),"crystal")
			crystal.hp = [crystal.max_hp,crystal.max_hp*0.5,1.0][lane]
		g.model.add_building(team,Vector2i(3 if team == 0 else 5,3),"teleport_trap")
		g.model.add_building(team,Vector2i(3 if team == 0 else 5,4),"blast_trap")
		g.model.add_building(team,Vector2i(2 if team == 0 else 6,2),"arcane_tower")
	g.enter_battle("Art fixture")
	await snap("battle")
	var crystal: Dictionary = g.model.buildings[1]
	var worker: Dictionary = g.model.spawn_unit(0,1,"artificer",crystal.pos-Vector2(40,0))
	g.attack_animation.observe(g.model)
	g.model.Arcane.repair(g.model,worker)
	g.attack_animation.observe(g.model)
	g.consume_events()
	await snap("repair")
	var trap: Dictionary = g.model.buildings[3]
	var blast: Dictionary = g.model.buildings[4]
	g.model.spawn_unit(1,3,"knight",trap.pos)
	g.model.spawn_unit(1,3,"hunter",trap.pos+Vector2(30,0))
	g.model.Arcane.update_traps(g.model)
	g.model.buildings = g.model.buildings.filter(func(b): return b.hp > 0)
	g.consume_events()
	await snap("teleport")
	trap = blast
	g.model.spawn_unit(1,4,"knight",trap.pos)
	g.model.Arcane.update_traps(g.model)
	g.model.buildings = g.model.buildings.filter(func(b): return b.hp > 0)
	g.consume_events()
	for e in g.effects: e.life = e.duration*0.55
	await snap("blast")
	g.effects.clear()
	var tower: Dictionary = g.model.buildings.filter(func(b): return b.kind == "arcane_tower" and b.team == 0)[0]
	g.model.spawn_unit(1,2,"knight",tower.pos+Vector2(130,0))
	g.model.build_lookups()
	g.model.Arcane.update_building(g.model,tower,0)
	g.consume_events()
	for e in g.effects: e.life = e.duration*0.55
	await snap("tower-attack")
	g.free()
	print("PASS: five card pages, crystal fading, repair and trap effects captured without text overflow")
	quit()
