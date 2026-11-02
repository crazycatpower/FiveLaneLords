extends SceneTree
const B = preload("res://balance.gd")
const Battle = preload("res://battle.gd")
const DS = preload("res://deck_store.gd")
const L = preload("res://layout.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(B.validate().is_empty())
	for lord: String in B.LORDS: assert("barricade" in DS.pool(lord))
	var m = Battle.new(120)
	m.ai_enabled = [false,false]
	m.lord_active = [false,false]
	m.buildings.clear()
	m.units.clear()
	m.refresh_territory()
	m.decks[0][0] = "barricade"
	m.ink[0] = B.MAX_INK
	var cell := Vector2i(0,2)
	assert(m.play(0,0,L.cell_center(cell)))
	assert(m.ink[0] == B.MAX_INK-B.CARDS.barricade.cost)
	var wall: Dictionary = m.building_at(cell)
	assert(wall.kind == "barricade" and wall.hp == B.CARDS.barricade.hp)
	var gold: Array = m.ink.duplicate()
	for i in range(120): m.update_buildings(1.0)
	assert(m.ink == gold and wall.hp == B.CARDS.barricade.hp)
	assert(wall.production == 0 and m.projectiles.is_empty())
	assert(not B.CARDS.barricade.has("damage") and not B.CARDS.barricade.has("explosion_damage"))
	m.spawn_unit(1,2,"militia",L.cell_center(cell)+Vector2(35,0))
	m.build_lookups()
	var enemy: Dictionary = m.units[0]
	assert(m.choose_target(enemy,B.CARDS.militia) == wall)
	var hp: float = enemy.hp
	m.damage(wall,B.CARDS.barricade.hp,1,"militia")
	m.resolve_deaths()
	assert(enemy.hp == hp, "No retaliation or death effect")
	if "--capture" in OS.get_cmdline_user_args():
		var g = load("res://main.tscn").instantiate()
		root.add_child(g)
		g.set_physics_process(false)
		g.sound_enabled = false
		g.library.open("barricade")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/barricade-preview.png")
		g.free()
	print("PASS: neutral barricade, normal deployment, no economy/attack/retaliation, enemy targeting")
	quit()
