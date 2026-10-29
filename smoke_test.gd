extends SceneTree
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
var checks := 0
var failures := 0
var finished := {}
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
	test_lords()
	test_match()
	test_ai()
	test_cards()
	test_decks()
	test_screens()
	test_feel()
	test_overlap()
	check(finished.has("overlap"),"overlap test ran to the end")
	check(finished.has("feel"),"feel test ran to the end")
	check(finished.has("screens"),"screen test ran to the end (a script error would stop it silently)")
	await preview()
	check(finished.has("preview"),"preview ran to the end")
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
	game.deck_path = "user://test-ui-deck.json"
	game.player_deck = B.PRESETS[0].duplicate()
	if DisplayServer.get_name() != "headless":
		for screen: String in ["title","deck"]:
			if screen == "deck": game.show_deck()
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://%s-preview.png" % screen)
	game.start_battle()
	DirAccess.remove_absolute("user://test-ui-deck.json")
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
	finished["preview"] = true

func test_lords() -> void:
	var m := Battle.new(9)
	var lord: Dictionary = m.lords[0]
	lord.hp = 200
	lord.last_hit = m.elapsed
	tick(m,0.6)
	check(lord.retreating and lord.target == L.spawn_position(0,2),"low health retreats")
	lord.hp = 500
	tick(m,0.6)
	check(lord.retreating,"retreat hysteresis persists below seventy percent")
	lord.hp = 700
	tick(m,0.6)
	check(not lord.retreating,"healthy lord resumes")
	m = Battle.new(8)
	m.spawn_unit(1,0,"militia",L.cell_center(Vector2i(1,0)))
	var reached := false
	for frame: int in range(174):
		m.step(1.0/60.0)
		reached = reached or absf(m.lords[0].pos.y-L.cell_center(Vector2i(0,0)).y) < 58
	check(reached,"lord reaches threatened lane within three seconds, even if threat is killed")
	m.lords[0].pos.x = 2000
	m.lords[1].pos.x = 0
	tick(m,0.1)
	check(m.lords[0].pos.x < L.GRID_ORIGIN.x+6*L.CELL_SIZE.x and m.lords[1].pos.x > L.GRID_ORIGIN.x+3*L.CELL_SIZE.x,"lords never enter opposing original territory")
	m.damage(m.lords[0],9999,1,"militia")
	tick(m,12.1)
	check(m.lords[0].hp == B.LORD_HP,"lord revives after twelve seconds")

func test_match() -> void:
	var m := Battle.new(1)
	m.elapsed = 179
	check(m.multiplier() == 1.0,"normal ink speed before three minutes")
	m.elapsed = 180
	check(m.multiplier() == 1.5,"ink x1.5 from three minutes")
	m.elapsed = 300
	check(m.multiplier() == 2.0,"ink x2 from five minutes")
	m.elapsed = 900
	m.step(0.01)
	check(not m.ended,"no time limit")
	# Gate standing: attackers stop and batter it; nobody wins.
	m = Battle.new(1)
	m.lords.clear()
	m.gates[0][0] = 1
	var raider := m.spawn_unit(1,0,"knight",Vector2(L.gate_stop(0)+1,L.cell_center(Vector2i(0,0)).y))
	tick(m,0.1)
	check(m.gates[0][0] == 0 and not m.ended,"breaking a gate alone does not end the game")
	check(m.events.any(func(e: Dictionary) -> bool: return e.kind == "breach" and e.team == 1 and e.lane == 0),"breach is announced with its lane")
	# Gate broken: the attacker clears the rubble for RUBBLE_TIME, then walks on; reaching our home line loses.
	tick(m,B.RUBBLE_TIME-0.3)
	check(not m.ended and is_equal_approx(raider.pos.x,L.gate_stop(0)) and raider.climb > 0,"attackers stop to clear the rubble first")
	for i: int in range(600):
		m.step(1.0/60.0)
		if m.ended: break
	check(m.ended and m.winner == 1 and raider.pos.x <= L.gate_icon_x(0)+0.01,"an enemy walking through a broken gate wins")
	m = Battle.new(1)
	m.lords.clear()
	m.gates[1][4] = 0
	m.spawn_unit(0,4,"ram",Vector2(L.gate_stop(1)-5,L.cell_center(Vector2i(0,4)).y))
	for i: int in range(600):
		m.step(1.0/60.0)
		if m.ended: break
	check(m.ended and m.winner == 0,"our ram walking in wins too")
	m = Battle.new(1)
	m.hit_gate(1,2,600)
	offer(m,"militia")
	check(m.can_play(0,0,L.cell_center(Vector2i(5,2))),"breach expands unit deployment to column six")
	check(not m.can_play(0,0,L.cell_center(Vector2i(5,1))),"other lanes remain closed")
	offer(m,"farm")
	check(not m.can_play(0,0,L.cell_center(Vector2i(5,2))),"buildings remain in original deployment zone")
	m.hit_gate(0,3,600)
	offer(m,"militia",1)
	check(m.can_play(1,0,L.cell_center(Vector2i(3,3))),"blue breach mirrors deployment")
	m = Battle.new(1)
	m.lords.clear()
	var u := m.spawn_unit(1,0,"militia",Vector2(L.gate_stop(0)+100,L.cell_center(Vector2i(0,0)).y))
	m.step(0.01)
	check(u.hp == u.max_hp,"gates never shoot back")

func test_ai() -> void:
	var m := Battle.new(3)
	m.ink[1] = 0
	check(m.AI.decide(m.snapshot(1)).is_empty(),"AI cannot afford a card with zero ink")
	offer(m,"farm",1)
	var c: Dictionary = m.AI.decide(m.snapshot(1))
	check(c.kind == "farm","AI invests in economy")
	m.add_building(1,Vector2i(7,1),"farm")
	m.decks[1] = ["farmer","militia","rain","tower","farm","militia","rain","tower"]
	m.ink[1] = 10
	c = m.AI.decide(m.snapshot(1))
	check(c.kind == "farmer" and c.cell == Vector2i(8,1),"AI farmers start behind fields")
	m.buildings.clear()
	m.decks[1] = ["militia","militia","militia","militia","farm","farmer","tower","rain"]
	m.ink[1] = 24
	check(m.AI.decide(m.snapshot(1)).is_empty(),"normal AI waits for 25 ink attack threshold")
	m.ink[1] = 25
	c = m.AI.decide(m.snapshot(1))
	check(c.kind == "militia" and c.wave,"AI starts wave at threshold")
	m.spawn_unit(0,0,"militia",L.cell_center(Vector2i(7,0)))
	c = m.AI.decide(m.snapshot(1))
	check(c.cell.y == 0 and c.pos.x >= L.cell_center(Vector2i(7,0)).x,"AI intercepts ahead of incoming attacker")
	m = Battle.new(3)
	m.ai_enabled[1] = true
	tick(m,35)
	check(m.stats[1].plays > 0 and m.ink[1] >= 0,"AI acts through shared paid play interface")


func test_cards() -> void:
	check(B.CARDS.size() == 15,"fifteen card pool")
	var m := Battle.new(1)
	m.lords.clear()
	var farm := m.add_building(0,Vector2i(1,0),"farm")
	var other := m.add_building(0,Vector2i(1,1),"farm")
	m.add_building(0,Vector2i(2,0),"mill")
	check(m.farm_speed(farm) == 1.5 and m.farm_speed(other) == 1,"mill boosts only its lane")
	offer(m,"mill")
	check(not m.can_play(0,0,L.cell_center(Vector2i(0,1))),"one mill per side")
	var before: float = m.ink[0]
	m.cast_spell({"kind":"harvest","team":0,"pos":farm.pos})
	check(m.stats[0].drops == 2 and farm.harvest_until == 8,"harvest produces immediately on nearby farms")
	check(m.farm_speed(farm) == 3,"harvest and mill stack multiplicatively")
	m = Battle.new(2)
	m.lords.clear()
	var target := m.add_building(1,Vector2i(7,0),"mill")
	m.cast_spell({"kind":"fire","team":0,"pos":target.pos})
	check(target.hp == 60,"fire does double 320 damage to buildings")
	m = Battle.new(2)
	m.lords.clear()
	var ox := m.spawn_unit(0,0,"ox",Vector2(700,162))
	var knight := m.spawn_unit(1,0,"knight",Vector2(720,162))
	m.attack(ox,knight)
	check(ox.charged and knight.hp == 480 and knight.pos.x == 750,"ox charge and knockback")
	m.attack(ox,knight)
	check(knight.hp == 460,"ox only charges once")
	var healer := m.spawn_unit(0,0,"healer",Vector2(700,162))
	ox.hp = 300
	m.heal(healer,1)
	check(ox.hp == 312,"herbalist heals nearby allies")
	m = Battle.new(2)
	m.lords.clear()
	var hunter := m.spawn_unit(0,0,"hunter",Vector2(700,162))
	knight = m.spawn_unit(1,0,"knight",Vector2(820,162))
	m.attack(hunter,knight)
	check(knight.hp == 600 and m.projectiles.size() == 1,"arrow has real flight delay")
	m.update_projectiles(0.35)
	check(knight.hp == 590 and m.projectiles.is_empty(),"arrow damages on arrival")
	m = Battle.new(2)
	m.lords.clear()
	var ram := m.spawn_unit(0,0,"ram",Vector2(700,162))
	m.spawn_unit(1,0,"knight",Vector2(710,162))
	m.step(0.1)
	check(ram.pos.x > 700,"ram ignores blocking units")
	m = Battle.new(2)
	m.lords.clear()
	var militia := m.spawn_unit(0,0,"militia",Vector2(1135,162))
	knight = m.spawn_unit(1,0,"knight",Vector2(1140,162))
	var scarecrow := m.add_building(1,Vector2i(7,0),"scarecrow")
	m.step(0.01)
	check(scarecrow.hp < 400 and knight.hp == 600,"scarecrow takes priority over nearer troops")
	m = Battle.new(2)
	offer(m,"mob")
	m.play(0,0,L.cell_center(Vector2i(1,1)))
	check(m.units.size() == 5 and m.units.back().spawn_delay > 0,"mob deploys five staggered troops")
	m = Battle.new(2)
	for lane: int in range(4): m.add_building(0,Vector2i(1,lane),"farm")
	m.decks[1] = ["fire","militia","rain","tower","farm","farmer","ox","mob"]
	m.ink[1] = 10
	var c: Dictionary = m.AI.decide(m.snapshot(1))
	check(c.kind == "fire" and c.cell.x == 1,"AI raids four player farms with fire")

func test_decks() -> void:
	var store = preload("res://deck_store.gd")
	for deck: Array in B.PRESETS: check(store.valid(deck),"preset has eight unique cards and farmland")
	check(not store.valid(["farm"]),"short deck rejected")
	var deck: Array = B.PRESETS[0].duplicate()
	deck[0] = "knight"
	check(not store.valid(deck),"deck without farm rejected")
	deck = B.PRESETS[0].duplicate()
	check(store.save_deck(deck,"user://test-deck.json"),"deck saved")
	check(store.load_deck("user://test-deck.json") == deck,"deck roundtrip")
	DirAccess.remove_absolute("user://test-deck.json")

func test_screens() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://test-ui-deck.json" # never touch the player's own deck
	game.set_physics_process(false)
	check(game.screen == "title","game opens on the title screen")
	var labels: Array = game.ui.map(func(b: Button) -> String: return b.text)
	check("開始對戰" in labels and "觀戰模式" in labels and "牌組編成" in labels and "操作說明" in labels,"title offers battle, spectate, deck and help")
	game.player_deck = B.PRESETS[1].duplicate()
	game.show_deck()
	game.toggle_deck_card("farm")
	check(not "farm" in game.player_deck and game.start_button.disabled,"removing farmland disables the start button")
	game.start_battle()
	check(game.screen == "deck","an invalid deck cannot start a battle")
	game.toggle_deck_card("farm")
	check(game.player_deck.size() == 8 and not game.start_button.disabled,"adding it back re-enables start")
	game.toggle_deck_card("mob")
	check(game.player_deck.size() == 8 and not "mob" in game.player_deck,"a full deck refuses a ninth card")
	game.start_battle()
	check(game.screen == "battle" and game.model.ai_enabled == [false,true],"battle starts with the player's deck and an AI opponent")
	var dealt: Array = game.model.decks[0].duplicate()
	dealt.sort()
	var chosen: Array = game.player_deck.duplicate()
	chosen.sort()
	check(dealt == chosen,"the battle deals the chosen eight cards")
	game.spectating = true
	game.start_battle()
	check(game.model.ai_enabled == [true,true],"spectate mode lets AI play both sides")
	game.free()
	DirAccess.remove_absolute("user://test-ui-deck.json")
	finished["screens"] = true

func mouse(game: Node, pos: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = button
	e.pressed = pressed
	game._unhandled_input(e)

func test_feel() -> void:
	var bank = preload("res://sound_bank.gd")
	for cue: String in bank.CUES: check(ResourceLoader.exists("res://assets/audio/"+bank.CUES[cue]+".ogg"),"sound asset for "+cue)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://test-ui-deck.json"
	game.set_physics_process(false)
	game.player_deck = B.PRESETS[1].duplicate()
	game.spectating = false
	game.start_battle()
	var m = game.model
	m.ai_enabled = [false,false]
	m.decks[0] = ["militia","farm","knight","rain","farmer","hunter","scarecrow","tower"]
	m.ink[0] = 50.0
	var field := L.cell_center(Vector2i(1,2))
	# Drag a card from the hand onto the field.
	mouse(game,game.card_rect(0).get_center(),true)
	check(game.selected == 0 and game.dragging,"pressing a card picks it up")
	mouse(game,field,false)
	check(not game.dragging and game.selected == -1 and m.units.size() == 2,"dropping it on the field plays it")
	# Click a card, then click the field.
	m.cooldown[0] = 0
	mouse(game,game.card_rect(0).get_center(),true)
	mouse(game,game.card_rect(0).get_center(),false)
	check(game.selected == 0,"a click selects a card")
	mouse(game,game.card_rect(0).get_center(),true)
	mouse(game,game.card_rect(0).get_center(),false)
	check(game.selected == -1,"clicking the selected card again puts it back")
	# A refused placement says why and marks the spot.
	m.cooldown[0] = 0
	var kind: String = m.decks[0][0]
	game.selected = 0
	var before: int = game.effects.size()
	check(not game.try_play(0,L.cell_center(Vector2i(5,2))),"far cells are refused")
	check("左側三欄" in game.notice and game.effects.size() == before+1 and game.effects.back().kind == "fail","refusal explains why and shows a red cross")
	m.ink[0] = 0
	check("墨水不足" in m.play_error(0,0,field),"short ink is explained")
	check(m.decks[0][0] == kind,"a refused card stays in hand")
	# Pause banner buttons.
	game.toggle_pause()
	var captions: Array = game.overlay_buttons().map(func(item: Array) -> String: return item[1])
	check(captions == ["繼續","重新開始","回到標題"],"pause banner offers continue, restart and title")
	mouse(game,game.overlay_buttons()[2][0].get_center(),true)
	check(game.screen == "title","pause banner returns to the title")
	# Spectate speed: same fixed steps, just more per frame.
	game.player_deck = B.PRESETS[1].duplicate()
	game.spectating = true
	game.start_battle()
	game.set_speed(4)
	game._physics_process(1.0/60.0)
	check(is_equal_approx(game.model.elapsed,4.0/60.0),"spectate x4 runs four steps per frame")
	mouse(game,game.card_rect(0).get_center(),true)
	check(game.selected == -1,"spectators cannot play cards")
	mouse(game,game.SPEED_RECTS[3].get_center(),true)
	check(game.speed == 8,"speed buttons work")
	var k := InputEventKey.new()
	k.keycode = KEY_MINUS
	k.pressed = true
	game._unhandled_input(k)
	check(game.speed == 4,"minus key slows down")
	game.free()
	DirAccess.remove_absolute("user://test-ui-deck.json")
	finished["feel"] = true

func test_overlap() -> void:
	var m := Battle.new(5)
	m.lords.clear()
	var y := L.cell_center(Vector2i(0,2)).y
	var units: Array = []
	for i: int in range(6): units.append(m.spawn_unit(0,2,"militia",Vector2(500,y)))
	var offsets: Array = units.map(func(u: Dictionary) -> float: return u.dy)
	check(offsets.all(func(d: float) -> bool: return absf(d) <= B.PLACE_JITTER) and offsets.max()-offsets.min() > 4,"placed units get a small up/down offset")
	check(units.all(func(u: Dictionary) -> bool: return u.pos == Vector2(500,y)),"the offset never moves the unit itself")
	finished["overlap"] = true
