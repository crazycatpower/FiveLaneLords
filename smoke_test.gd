extends SceneTree
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func tick(m: RefCounted, seconds: float) -> void:
	for i: int in range(roundi(seconds*60)): m.step(1.0/60.0)
func offer(m: RefCounted, kind: String, team: int = 0) -> void:
	m.decks[team][0] = kind
	m.ink[team] = 50.0
	m.cooldown[team] = 0.0
func run() -> void:
	test_core()
	await preview()
	print("%s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
func test_core() -> void:
	var m := Battle.new(42)
	check(m.ink == [10.0,10.0],"opening ink")
	check(m.decks[0].size() == 8,"eight cards")
	tick(m,2)
	check(m.ink == [11.0,11.0],"base income two seconds")
	var farm := m.add_building(0,Vector2i(1,0),"farm")
	tick(m,12.9)
	check(m.stats[0].drops == 0,"farm waits three plus ten seconds")
	tick(m,0.1)
	check(m.stats[0].drops == 1,"farm produces two ink after thirteen seconds")
	m.ink[0] = 49.0
	m.gain_ink(0,2)
	check(m.ink[0] == 50 and m.stats[0].wasted == 1,"overflow counted")
	m = Battle.new(42)
	farm = m.add_building(0,Vector2i(1,0),"farm")
	var farmer := m.spawn_unit(0,0,"farmer",farm.pos)
	tick(m,1)
	check(farmer.work_left > 0 and farmer.pos == farm.pos,"farmer stops to cultivate")
	tick(m,0.6)
	check(farm.boost_until > m.elapsed+14 and m.stats[0].cultivated == 1,"cultivation boosts fifteen seconds")
	tick(m,2)
	check(farmer.pos.x > farm.pos.x and farmer.worked.size() == 1,"farmer resumes forward once per field")
	var behind := m.add_building(0,Vector2i(0,0),"farm")
	tick(m,1)
	check(behind.boost_until == 0,"farmer never returns to a field behind")
	m = Battle.new(1)
	for row: int in range(5):
		for col: int in range(3):
			offer(m,"farm")
			check(m.play(0,0,L.cell_center(Vector2i(col,row))),"farm count has no arbitrary cap")
	check(m.count_buildings(0) == 15,"all fifteen spaces can be farms")
	offer(m,"militia")
	check(m.play(0,0,L.cell_center(Vector2i(0,0))),"units share a building cell")
	check(not m.play(0,0,L.cell_center(Vector2i(0,0))),"global 0.8 second cooldown")
	offer(m,"farm")
	check(not m.play(0,0,L.cell_center(Vector2i(0,0))),"buildings cannot share cell")
	check(not m.play(0,0,L.cell_center(Vector2i(4,0))),"building territory")
	offer(m,"rain")
	check(m.play(0,0,L.cell_center(Vector2i(8,0))),"spell can target enemy territory")
	m.decks[0] = ["farm","farmer","militia","tower","rain","farmer","militia","tower"]
	m.buildings.clear()
	offer(m,"farm")
	m.play(0,0,L.cell_center(Vector2i(0,0)))
	for n: int in range(3):
		check(not "farm" in m.decks[0].slice(0,4),"played card absent before fourth subsequent play")
		m.ink[0] = 50
		m.cooldown[0] = 0
		m.play(0,0,L.cell_center(Vector2i(1,n)))
	check(not "farm" in m.decks[0].slice(0,4),"still queued after three plays")
	m.ink[0] = 50
	m.cooldown[0] = 0
	m.play(0,0,L.cell_center(Vector2i(2,4)))
	check("farm" in m.decks[0].slice(0,4),"returns after four subsequent plays")
	for side: int in range(2):
		m = Battle.new(1)
		var attacker := m.spawn_unit(1-side,0,"militia",Vector2(L.gate_stop(side),L.cell_center(Vector2i(0,0)).y))
		var defender := m.spawn_unit(side,0,"militia",L.spawn_position(side,0))
		tick(m,0.2)
		check(attacker.hp < 85 and defender.hp < 85,"gate fights on both sides")
	m = Battle.new(1)
	var u := m.spawn_unit(0,0,"militia",Vector2(800,162))
	m.spawn_unit(1,0,"militia",Vector2(700,162))
	tick(m,0.2)
	check(u.pos.x > 800,"does not pursue enemies behind")
	m.paused = true
	var t: float = m.elapsed
	tick(m,1)
	check(m.elapsed == t,"pause freezes simulation")
	var a := Battle.new(77)
	var b := Battle.new(77)
	check(a.decks == b.decks,"seeded shuffle reproducible")
	for row: int in range(5):
		for col: int in range(9): check(m.cell_at(L.cell_center(Vector2i(col,row))) == Vector2i(col,row),"grid roundtrip")
func preview() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.model.add_building(0,Vector2i(1,1),"farm")
	game.model.add_building(1,Vector2i(7,3),"farm")
	for lane: int in range(5):
		game.model.spawn_unit(0,lane,"militia",Vector2(650+lane*24,L.cell_center(Vector2i(0,lane)).y))
		game.model.spawn_unit(1,lane,"militia",Vector2(1060-lane*24,L.cell_center(Vector2i(0,lane)).y))
	game.queue_redraw()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview.png")
	game.free()
