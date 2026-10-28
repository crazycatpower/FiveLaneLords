extends SceneTree

# Run: godot_console --headless --path . -s smoke_test.gd   (exit code 0 = pass)
# Without --headless it also re-shoots preview.png.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	# A script error inside run() stops it before quit(); never leave a headless run hanging.
	create_timer(30.0).timeout.connect(_timed_out)
	call_deferred("run")

func _timed_out() -> void:
	printerr("FAIL: smoke test did not finish (a script error probably stopped it)")
	quit(2)

func check(ok: bool, what: String = "") -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL check #%d %s" % [checks, what])

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lord.set_physics_process(false)
	check(Vector2(root.content_scale_size) == Vector2(1600,900), "1600x900 logical viewport")
	check(game.CELL_SIZE == Vector2(118,116) and game.GRID_ORIGIN == Vector2(269,104), "planned grid geometry")
	check(game.buildings[0].has_all(["kind","team","cell","hp","expires","boost_until"]), "building schema")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			check(game.rng.seed == int(argument.substr(7)), "command-line seed applied at startup")
	game.configure_rng(PackedStringArray(["--seed=42"]))
	game.spawn_unit(0,0,"militia",game.cell_center(Vector2i(1,0)))
	var seeded_phase: float = game.units.back().phase
	game.units.clear()
	game.configure_rng(PackedStringArray(["--seed=42"]))
	game.spawn_unit(0,0,"militia",game.cell_center(Vector2i(1,0)))
	check(game.units.back().phase == seeded_phase and game.units.back().kind == "militia", "seed reproducibility and unit kind")
	game.units.clear()
	for side: int in range(2):
		check(absf(game.LAYOUT.spawn_position(side,0).x-game.LAYOUT.gate_stop(side)) == 20, "gate stop within melee of deployment")
	var initial_income: float = game.income()
	game.add_building(1,Vector2i(8,0),"farm")
	check(game.income() == initial_income and game.farm_count(1) == 1, "enemy buildings do not add player income")
	game.buildings.back().hp = 0
	check(game.building_at(Vector2i(8,0)).is_empty() and game.farm_count(1) == 0, "destroyed buildings are not occupied or productive")
	game.buildings.pop_back()
	check(not game.LAYOUT.PAUSE_RECT.intersects(game.LAYOUT.CASTLE_BARS[1]), "pause button does not cover enemy health")
	for button: Button in game.buttons:
		check(Rect2(Vector2.ZERO,game.LAYOUT.VIEWPORT_SIZE).encloses(Rect2(button.position,button.size*button.scale)), "controls stay inside viewport")
	game.selected = 4
	game.recruit()
	check(game.gold == 100 and game.units.is_empty())
	check(not game.place_card(Vector2i(3,4)), "column 4 is outside the deploy zone")
	check(not game.place_card(Vector2i(-1,4)))
	check(not game.place_card(Vector2i(0,5)))
	check(game.gold == 100)
	check(game.place_card(Vector2i(2,4)))
	check(game.units.size() == 1 and game.units[0].lane == 4)
	check(game.units[0].pos == game.cell_center(Vector2i(2,4)))
	check(game.gold == 75)
	game.build_farm()
	check(not game.place_card(Vector2i(2,4)), "occupied by a soldier")
	check(not game.place_card(Vector2i(0,0)), "existing farm")
	check(not game.place_card(Vector2i(8,4)), "enemy territory")
	check(game.gold == 75)
	check(game.place_card(Vector2i(1,4)))
	check(not game.building_at(Vector2i(1,4)).is_empty() and game.income() == 6.0)
	check(game.gold == 15)
	game.selected_card = "farm"
	check(not game.place_card(Vector2i(1,3)), "insufficient gold")
	game.gold = 200
	game.paused = true
	check(not game.place_card(Vector2i(1,3)), "paused")
	game.paused = false
	game.ended = true
	check(not game.place_card(Vector2i(1,3)), "ended")
	game.ended = false
	game.recruit_cd = 0
	game.recruit()
	var gold_before: float = game.gold
	var farm_count: int = game.farm_count(0)
	check(game.place_card(Vector2i(0,0)), "militia may stand on a farm")
	check(game.gold == gold_before-25 and game.farm_count(0) == farm_count)
	check(game.units.back().pos == game.cell_center(Vector2i(0,0)))
	game.buildings.clear()
	for row: int in range(5):
		for col: int in range(3):
			game.add_building(0,Vector2i(col,row),"farm")
	game.recruit_cd = 0
	game.recruit()
	check(game.place_card(Vector2i(2,3)), "all 15 farm cells remain deployable")
	game.build_farm()
	check(not game.place_card(Vector2i(2,3)))
	check(game.cell_at(game.GRID_ORIGIN+Vector2(-0.1,0)) == Vector2i(-1,-1))
	check(game.cell_at(game.GRID_ORIGIN+game.CELL_SIZE*Vector2(9,5)) == Vector2i(-1,-1))
	for row: int in range(5):
		for col: int in range(9):
			check(game.cell_at(game.cell_center(Vector2i(col,row))) == Vector2i(col,row), "cell %d,%d" % [col,row])
	game.units.clear()
	game.spawn_unit(1,2,"militia",game.LAYOUT.spawn_position(1,2))
	game.units[0].pos = game.lord.position
	game.skill()
	check(game.units[0].hp == 20, "lord skill hits for 65")
	game.lord.damage(300)
	check(game.lord.respawn == 9.0)
	game.lord._physics_process(9.1)
	check(game.lord.hp == 260 and game.lord.visible, "lord respawns")
	game.units.clear()
	game.spawn_unit(0,1,"militia",game.LAYOUT.spawn_position(0,1))
	game.units[0].pos.x = game.LAYOUT.gate_stop(1)
	game.gates[1][1] = 1
	game._physics_process(1.0)
	check(game.gates[1][1] == 0, "gate breaks")
	game.castle[1] = 1
	game._physics_process(1.0)
	check(game.ended and game.castle[1] == 0, "victory")
	game.ended = false
	game.paused = true
	var time: float = game.elapsed
	game._physics_process(3.0)
	check(game.elapsed == time, "pause stops the clock")

	# Keyboard deploy, feedback, restart guard, formations.
	game.paused = false
	game.units.clear()
	game.buildings.clear()
	game.gold = 500
	game.recruit_cd = 0
	game.recruit()
	game._unhandled_input(key(KEY_4))
	check(game.units.size() == 1 and game.units[0].lane == 3 and game.units[0].pos == game.cell_center(Vector2i(2,3)), "Q then 4: militia at the front of lane 4")
	game.build_farm()
	game._unhandled_input(key(KEY_4))
	check(game.farm_count(0) == 1 and game.buildings[0].cell == Vector2i(0,3), "F then 4: farm at the back of lane 4")
	game._unhandled_input(key(KEY_4))
	check(game.units.size() == 1 and game.farm_count(0) == 1, "a lone 4 with no card selected places nothing")
	for i: int in range(2):
		game.spawn_unit(0,3,"militia",game.LAYOUT.spawn_position(0,3))
		game.units.back().pos = game.units[0].pos
	game.layout_formations()
	var shown: Array[float] = []
	for unit: Dictionary in game.units:
		shown.append(unit.draw.x)
		check(unit.pos == game.units[0].pos, "formations only move the drawing")
	shown.sort()
	var gap: float = game.FORMATION_GAP
	check(shown[2] == game.units[0].pos.x and shown[2]-shown[1] >= gap and shown[1]-shown[0] >= gap, "three militia on one spot are drawn as a column")
	game.gold = 10
	game.recruit()
	check(game.selected_card.is_empty() and "金幣不足" in game.notice, "Q without gold says why")
	game._unhandled_input(key(KEY_R))
	check("Esc" in game.notice, "R mid-battle does not restart")
	game.free()

	# Soldiers standing at a gate used to be 50 px from the enemy spawn / deploy cells (melee is 47) and were never fought.
	var duel = load("res://main.tscn").instantiate()
	root.add_child(duel)
	duel.set_physics_process(false)
	duel.lord.set_physics_process(false)
	duel.enemy_timer = 9999.0
	duel.spawn_unit(0,4,"militia",duel.LAYOUT.spawn_position(0,4))
	duel.units.back().pos.x = duel.LAYOUT.gate_stop(1)
	duel.spawn_unit(1,4,"militia",duel.LAYOUT.spawn_position(1,4))
	for i: int in range(180):
		duel._physics_process(1.0/60.0)
	check(duel.units[0].hp < 85 and duel.units[1].hp < 85, "a fresh enemy spawn fights the militia at its gate")
	check(duel.gates[1][4] == 180, "the gate is left alone while a foe is in sight")
	duel.units.clear()
	duel.spawn_unit(1,0,"militia",duel.LAYOUT.spawn_position(1,0))
	duel.units.back().pos.x = duel.LAYOUT.gate_stop(0)
	duel.gold = 500
	duel.recruit()
	duel.place_card(Vector2i(0,0))
	for i: int in range(180):
		duel._physics_process(1.0/60.0)
	check(duel.units[0].hp < 85 and duel.units[1].hp < 85, "militia deployed next to a gate raider fight it")
	check(duel.units[1].face == -1.0, "the defender turns to face the raider")
	duel.units.clear()
	duel.spawn_unit(1,2,"militia",duel.LAYOUT.spawn_position(1,2))
	duel.units.back().pos.x = duel.LAYOUT.gate_stop(0)
	duel.gates[0][2] = 5
	duel._physics_process(1.0)
	check(duel.gates[0][2] == 0 and "城門被攻破" in duel.notice and duel.alarm[2] > 0, "a fallen gate is announced and its lane flashes")
	duel.free()

	var preview = load("res://main.tscn").instantiate()
	root.add_child(preview)
	preview.set_physics_process(false)
	preview.lord.set_physics_process(false)
	preview.add_building(0,Vector2i(1,2),"farm")
	preview.add_building(0,Vector2i(0,4),"farm")
	for lane: int in range(5):
		preview.spawn_unit(0,lane,"militia",preview.LAYOUT.spawn_position(0,lane))
		preview.spawn_unit(1,lane,"militia",preview.LAYOUT.spawn_position(1,lane))
		preview.units[lane*2].pos.x = 650+lane*45
		preview.units[lane*2+1].pos.x = 1060-lane*35
	for i: int in range(2): # two more militia on the lane-4 soldier's spot: drawn as a small column
		preview.spawn_unit(0,3,"militia",preview.LAYOUT.spawn_position(0,3))
		preview.units.back().pos.x = preview.units[6].pos.x
	preview.queue_redraw()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview.png")
	if failures > 0:
		printerr("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)
		return
	print("PASS: %d checks (grid, placement, economy, skill, respawn, gates, victory, pause, keyboard deploy, feedback, restart guard, formations, gate fights, breach alarm)" % checks)
	quit()
