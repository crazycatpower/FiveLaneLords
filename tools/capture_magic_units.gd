extends SceneTree
var g
const KEYS = ["blink_blade","arcane_golem","arcane_archer","chronomancer","phase_rider"]
func _initialize() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	call_deferred("run")
func snap(name: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for c in g.ui:
		if c is RichTextLabel: assert(c.get_content_height() <= c.size.y,"Text overflow: "+c.text)
	root.get_texture().get_image().save_png("res://docs/magic-units-preview/"+name+".png")
func fixture() -> void:
	g.model = g.Battle.new(57,[],[],"mage","mage")
	g.model.ai_enabled = [false,false]
	g.model.buildings.clear()
	g.model.units.clear()
	g.effects.clear()
	g.adventure.index = -1
	g.enter_battle("Magic preview")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/magic-units-preview")
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	for kind: String in KEYS:
		g.library.open(kind)
		await snap(kind)
	for kind: String in KEYS:
		fixture()
		for team: int in [0,1]:
			var lane: int = 1 if team == 0 else 3
			var p: Vector2 = g.L.cell_center(Vector2i(3 if team == 0 else 5,lane))
			var dir := 1.0 if team == 0 else -1.0
			var u: Dictionary = g.model.spawn_unit(team,lane,kind,p)
			var target: Dictionary = g.model.spawn_unit(1-team,lane,"knight",p+Vector2(dir*100,0))
			g.model.build_lookups()
			match kind:
				"blink_blade": g.model.damage(u,10,1-team,"rain")
				"arcane_golem":
					for row in range(3): g.model.add_building(team,Vector2i(1 if team == 0 else 7,row),"crystal")
					u.hp -= 500
					var worker: Dictionary = g.model.spawn_unit(team,lane,"artificer",p-Vector2(dir*50,0))
					g.model.Arcane.repair(g.model,worker)
				"arcane_archer":
					g.model.spawn_unit(1-team,lane,"bandit",p+Vector2(dir*230,0))
					g.model.attack(u,target)
				"chronomancer": g.model.attack(u,target)
				"phase_rider": target.pos = p+Vector2(dir*30,0)
		g.model.update_projectiles(g.B.ARROW_TIME*.35)
		g.attack_animation.observe(g.model)
		g.consume_events()
		for e in g.effects: e.life = e.duration*.65
		await snap(kind+"-battle")
	fixture()
	for team: int in [0,1]:
		var p: Vector2 = g.L.cell_center(Vector2i(3 if team == 0 else 5,1 if team == 0 else 3))
		var u: Dictionary = g.model.spawn_unit(team,1 if team == 0 else 3,"hunter",p)
		var target: Dictionary = g.model.spawn_unit(1-team,u.lane,"knight",p+Vector2(180 if team == 0 else -180,0))
		g.model.shoot(u,target,10)
	g.model.update_projectiles(g.B.ARROW_TIME*.1)
	await snap("hunter-arrows")
	g.free()
	print("PASS: five codex pages, five mechanisms, mirrored hunter arrows")
	quit()
