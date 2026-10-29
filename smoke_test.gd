extends SceneTree
const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const DS = preload("res://deck_store.gd")
const L = preload("res://layout.gd")
var checks := 0
var failures := 0
var finished := {}
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	call_deferred("run")
# A battle with the two starting farms removed, so each mechanic can be tested on its own.
func bare(seed_value: int = 1, deck_a: Array = [], deck_b: Array = [], lord_a: String = "", lord_b: String = "") -> Battle:
	var m := Battle.new(seed_value,deck_a,deck_b,lord_a,lord_b)
	m.buildings.clear()
	return m
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
	m.hand_cd[team] = [0.0,0.0,0.0,0.0]
func run() -> void:
	test_descriptions()
	check(finished.has("descriptions"),"description test completed")
	test_core()
	test_lords()
	test_match()
	test_ai()
	test_cards()
	test_decks()
	test_screens()
	test_feel()
	test_overlap()
	test_opening_hand()
	test_tutorial()
	test_card_cooldowns()
	test_repair()
	test_start_farms()
	check(finished.has("start_farms"),"start farm test ran to the end")
	test_fast_rules()
	check(finished.has("fast_rules"),"fast rule test ran to the end")
	test_ai_cards()
	test_lord_skills()
	check(finished.has("lord_skills"),"lord skill test ran to the end")
	check(finished.has("ai_cards"),"AI card-use test ran to the end")
	check(finished.has("repair"),"repair test ran to the end")
	check(finished.has("card_cd"),"card cooldown test ran to the end")
	check(finished.has("tutorial"),"tutorial test ran to the end")
	check(finished.has("opening"),"opening hand test ran to the end")
	check(finished.has("overlap"),"overlap test ran to the end")
	check(finished.has("feel"),"feel test ran to the end")
	check(finished.has("screens"),"screen test ran to the end (a script error would stop it silently)")
	await test_help_layout()
	check(finished.has("help_layout"),"help layout test completed")
	await preview()
	check(finished.has("preview"),"preview ran to the end")
	print("%s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
# can_play() is a fast copy of play_error() for the AI; they must agree everywhere, and the
# per-step lookup lists must not change any farm's speed.
func test_fast_rules() -> void:
	var mismatches := 0
	var speed_mismatches := 0
	for seed_value: int in range(1,4):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var m := Battle.new(seed_value,DS.random_deck(rng),DS.random_deck(rng),"harvest","iron")
		m.ai_enabled = [true,true]
		m.add_building(0,Vector2i(2,1),"mill")
		for sample: int in range(12):
			for i: int in range(600): m.step(1.0/60.0)
			m.build_lookups()
			for b: Dictionary in m.buildings:
				if b.kind == "farm" and b.hp > 0 and not is_equal_approx(m.farm_speed(b),m.farm_speed_with(b,m.lane_mill[b.team][b.cell.y])): speed_mismatches += 1
			for team: int in range(2):
				for slot: int in [-1,0,1,2,3,4,5]:
					for row: int in range(-1,6):
						for col: int in range(-1,10):
							var pos := L.cell_center(Vector2i(col,row))
							if m.can_play(team,slot,pos) != m.play_error(team,slot,pos).is_empty(): mismatches += 1
	check(mismatches == 0,"fast can_play agrees with play_error on every slot and cell (%d mismatches)" % mismatches)
	check(speed_mismatches == 0,"farm speed from the per-step mill lookup matches the full scan")
	finished["fast_rules"] = true

# Blue AI with one card that matters in hand; the rest score nothing at low gold.
func ai_hand(kind: String, gold: float) -> Battle:
	var m := bare(5)
	m.decks[1] = [kind,"harvest","harvest","harvest","harvest","harvest","harvest","harvest"]
	m.hand_cd[1] = [0.0,0.0,0.0,0.0]
	m.farm_cd[1] = 999.0
	m.ink[1] = gold
	m.elapsed = 25.0
	return m

func test_ai_cards() -> void:
	var m := ai_hand("tower",20)
	check(m.AI.decide(m.snapshot(1)).is_empty(),"no farms to guard: the AI keeps its tower")
	m.add_building(1,Vector2i(8,1),"farm")
	var c: Dictionary = m.AI.decide(m.snapshot(1))
	check(c.get("kind","") == "tower" and c.cell.y == 1,"the AI guards a farm lane with a tower before raiders come")
	m.add_building(1,c.cell,"tower")
	check(m.AI.decide(m.snapshot(1)).is_empty(),"one guard per farm lane is enough")
	m = ai_hand("ram",B.CARDS.ram.cost+5)
	for lane: int in range(5):
		for i: int in range(3): m.spawn_unit(1,lane,"militia",L.cell_center(Vector2i(5,lane)))
	check(m.AI.decide(m.snapshot(1)).get("kind","") != "ram","the AI keeps 10 gold back instead of sending the ram")
	m.ink[1] = B.CARDS.ram.cost+10
	check(m.AI.decide(m.snapshot(1)).get("kind","") == "ram","with gold to spare and troops ahead, the ram goes")
	m = ai_hand("ram",B.CARDS.ram.cost+10)
	check(m.AI.decide(m.snapshot(1)).get("kind","") != "ram","no troops in the lane: the ram waits")
	m = ai_hand("healer",20)
	check(m.AI.decide(m.snapshot(1)).is_empty(),"the AI does not send a herbalist out alone")
	for i: int in range(3): m.spawn_unit(1,2,"militia",L.cell_center(Vector2i(6,2)))
	c = m.AI.decide(m.snapshot(1))
	check(c.get("kind","") == "healer" and c.cell.y == 2 and (c.pos.x-L.cell_center(Vector2i(6,2)).x) <= B.HEAL_RADIUS,"the herbalist goes right behind our troops")
	m = ai_hand("healer",46)
	check(m.AI.decide(m.snapshot(1)).get("kind","") == "healer","near the gold cap a stuck herbalist is spent anyway")
	finished["ai_cards"] = true

func test_lord_skills() -> void:
	var m := bare(4,[],[],"lion","iron")
	m.ink[0] = B.SKILL_COST-1
	check(not m.skill_error(0).is_empty() and not m.cast_skill(0),"a skill needs the full price")
	m.ink[0] = B.SKILL_COST
	check(m.cast_skill(0) and m.ink[0] == 0 and is_equal_approx(m.skill_cd[0],B.SKILL_COOLDOWN),"casting spends the gold and starts the cooldown")
	var knights: Array = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "knight" and u.team == 0)
	var lanes: Array = knights.map(func(u: Dictionary) -> int: return u.lane)
	lanes.sort()
	check(knights.size() == 5 and lanes == [0,1,2,3,4],"獅王號令 sends one knight down every lane")
	m.ink[0] = B.SKILL_COST
	check(not m.cast_skill(0) and "冷卻" in m.skill_error(0),"the skill cannot be cast again during its cooldown")
	tick(m,B.SKILL_COOLDOWN+0.1)
	m.ink[0] = B.SKILL_COST
	m.lords[0].hp = 0
	check(not m.cast_skill(0),"a fallen lord cannot cast")
	# 鐵壁: every gate back, rubble progress lost.
	m = bare(4,[],[],"lion","iron")
	m.gates[1] = [0.0,100.0,B.GATE_HP,0.0,50.0]
	var raider := m.spawn_unit(0,0,"militia",Vector2(L.gate_stop(1),L.cell_center(Vector2i(0,0)).y))
	raider.climb = 2.0
	m.ink[1] = B.SKILL_COST
	check(m.cast_skill(1) and m.gates[1].all(func(g: float) -> bool: return g == B.GATE_HP) and raider.climb == 0.0,"重築城牆 restores every gate and resets the rubble")
	# 豐收: a farm in every lane with room, every farm healed and doubled.
	m = bare(4,[],[],"harvest","iron")
	var old := m.add_building(0,Vector2i(0,2),"farm")
	old.hp = 10
	m.ink[0] = B.SKILL_COST
	m.cast_skill(0)
	var farms: Array = m.buildings.filter(func(b: Dictionary) -> bool: return b.team == 0 and b.kind == "farm")
	var farm_lanes := {}
	for b: Dictionary in farms: farm_lanes[b.cell.y] = true
	check(farm_lanes.size() == 5 and farms.size() == 6,"豐年祭 plants one new farm in every lane that has room")
	check(old.hp == old.max_hp and farms.all(func(b: Dictionary) -> bool: return is_equal_approx(m.farm_speed(b),2.0)),"豐年祭 heals every farm and doubles its output")
	# The AI saves up, then casts.
	m = bare(4,[],[],"lion","lion")
	m.ai_enabled = [false,true]
	m.elapsed = 60.0
	m.ink[1] = B.SKILL_COST
	tick(m,1.0)
	check(m.stats[1].get("skills",0) == 1,"the AI casts its lord's skill when it can")
	m = bare(4,[],[],"lion","iron")
	check(not m.AI.skill_plan(m.skill_state(1)).save,"鐵壁 AI does not hoard gold while its gates are fine")
	m.gates[1][2] = 0.0
	check(m.AI.skill_plan(m.skill_state(1)).save,"鐵壁 AI saves for the wall once a gate falls")
	finished["lord_skills"] = true

func test_core() -> void:
	var m := bare(42)
	check(m.ink == [10.0,10.0],"opening ink")
	check(m.decks[0].size() == 8,"eight cards")
	tick(m,2)
	check(m.ink == [11.0,11.0],"base income two seconds")
	var farm := m.add_building(0,Vector2i(1,0),"farm")
	tick(m,B.FARM_START+B.FARM_INTERVAL-0.1)
	check(m.stats[0].drops == 0,"farm waits three plus twenty seconds")
	tick(m,0.1)
	check(m.stats[0].drops == 1 and B.FARM_DROP == 4 and B.FARM_INTERVAL == 20,"farm produces four ink after twenty-three seconds")
	m.ink[0] = 49.0
	m.gain_ink(0,2)
	check(m.ink[0] == 50 and m.stats[0].wasted == 1,"overflow counted")
	m = bare(42)
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
	m = bare(1)
	for row: int in range(5):
		for col: int in range(3):
			offer(m,"farm")
			check(m.play(0,0,L.cell_center(Vector2i(col,row))),"farm count has no arbitrary cap")
	check(m.count_buildings(0) == 15,"all fifteen spaces can be farms")
	offer(m,"militia")
	check(m.play(0,0,L.cell_center(Vector2i(0,0))),"units share a building cell")
	m.decks[0][0] = "knight"
	m.hand_cd[0][0] = 0
	check(m.play(0,0,L.cell_center(Vector2i(0,0))),"no global cooldown between plays")
	offer(m,"farm")
	m.buildings[0].hp = 40
	check(m.play(0,0,L.cell_center(Vector2i(0,0))) and m.buildings[0].hp == m.buildings[0].max_hp and m.count_buildings(0) == 15,"the same building on our own one restores it")
	offer(m,"tower")
	check(not m.play(0,0,L.cell_center(Vector2i(0,0))) and "同一種" in m.play_error(0,0,L.cell_center(Vector2i(0,0))),"a different building cannot cover it")
	check(not m.play(0,0,L.cell_center(Vector2i(4,0))),"building territory")
	offer(m,"rain")
	check(m.play(0,0,L.cell_center(Vector2i(8,0))),"spell can target enemy territory")
	m.decks[0] = ["farm","farmer","militia","tower","rain","farmer","militia","tower"]
	m.hand_cd[0] = [0.0,0.0,0.0,0.0] # tests swap hands directly; skip the arrival cooldown
	m.buildings.clear()
	offer(m,"farm")
	m.play(0,0,L.cell_center(Vector2i(0,0)))
	for n: int in range(3):
		check(not "farm" in m.decks[0].slice(0,4),"played card absent before fourth subsequent play")
		m.ink[0] = 50
		m.hand_cd[0] = [0.0,0.0,0.0,0.0]
		m.play(0,0,L.cell_center(Vector2i(1,n)))
	check(not "farm" in m.decks[0].slice(0,4),"still queued after three plays")
	m.ink[0] = 50
	m.hand_cd[0] = [0.0,0.0,0.0,0.0]
	m.play(0,0,L.cell_center(Vector2i(2,4)))
	check("farm" in m.decks[0].slice(0,4),"returns after four subsequent plays")
	for side: int in range(2):
		m = bare(1)
		var attacker := m.spawn_unit(1-side,0,"militia",Vector2(L.gate_stop(side),L.cell_center(Vector2i(0,0)).y))
		var defender := m.spawn_unit(side,0,"militia",L.spawn_position(side,0))
		tick(m,0.2)
		check(attacker.hp < 85 and defender.hp < 85,"gate fights on both sides")
	m = bare(1)
	var u := m.spawn_unit(0,0,"militia",Vector2(800,162))
	m.spawn_unit(1,0,"militia",Vector2(700,162))
	tick(m,0.2)
	check(u.pos.x > 800,"does not pursue enemies behind")
	m.paused = true
	var t: float = m.elapsed
	tick(m,1)
	check(m.elapsed == t,"pause freezes simulation")
	var a := bare(77)
	var b := bare(77)
	check(a.decks == b.decks,"seeded shuffle reproducible")
	for row: int in range(5):
		for col: int in range(9): check(m.cell_at(L.cell_center(Vector2i(col,row))) == Vector2i(col,row),"grid roundtrip")
func preview() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://test-ui-deck.json"
	game.player_deck = B.PRESETS[0].duplicate()
	if DisplayServer.get_name() != "headless":
		for screen: String in ["title","deck","help"]:
			if screen == "deck": game.show_deck()
			if screen == "help": game.show_help()
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
	var m := bare(9)
	var lord: Dictionary = m.lords[0]
	lord.hp = 200
	lord.last_hit = m.elapsed
	tick(m,0.6)
	check(lord.retreating and is_equal_approx(lord.target.y,L.spawn_position(0,2).y) and lord.target.x <= m.Lord.zone(0).y,"low health retreats to the middle of the back strip")
	lord.hp = B.LORDS.lion.hp*0.35
	tick(m,0.6)
	check(lord.retreating,"retreat persists until the lord is back above the return threshold")
	lord.hp = B.LORDS.lion.hp*0.5
	tick(m,0.6)
	check(not lord.retreating,"recovered lord resumes")
	lord.hp = 100
	lord.last_hit = m.elapsed
	tick(m,B.LORD_REGEN_DELAY+1.0)
	check(lord.hp > 100 and lord.hp <= 100+B.LORD_REGEN*1.1,"slow regeneration starts after the delay")
	m = bare(8)
	m.spawn_unit(1,0,"militia",L.cell_center(Vector2i(1,0)))
	var reached := false
	for frame: int in range(174):
		m.step(1.0/60.0)
		reached = reached or absf(m.lords[0].pos.y-L.cell_center(Vector2i(0,0)).y) < 58
	check(reached,"lord reaches threatened lane within three seconds, even if threat is killed")
	# Repro of "the lord does not really defend": a knight battering our lane-4 gate must get hit.
	var d := bare(8)
	d.lords[1].pos = Vector2(5000,0) # keep the blue lord out of it
	var raider := d.spawn_unit(1,3,"knight",Vector2(L.gate_stop(0),L.cell_center(Vector2i(0,3)).y))
	tick(d,5.0)
	check(raider.hp < B.CARDS.knight.hp,"lord walks up to a gate raider and hits it")
	# A raider clearing rubble is urgent: the lord switches lanes at once, even when hurt.
	d = bare(8)
	d.lords[1].pos = Vector2(5000,0)
	d.lords[0].hp = B.LORDS.lion.hp*0.2
	d.lords[0].last_hit = d.elapsed
	d.gates[0][4] = 0
	var climber := d.spawn_unit(1,4,"militia",Vector2(L.gate_stop(0),L.cell_center(Vector2i(0,4)).y))
	climber.climb = 0.1
	tick(d,0.6)
	check(not d.lords[0].retreating and d.lords[0].target.y > L.cell_center(Vector2i(0,3)).y,"rubble raider beats retreat and lane-change delay")
	m.lords[0].pos.x = 2000
	m.lords[1].pos.x = 0
	tick(m,0.1)
	check(m.lords[0].pos.x < L.GRID_ORIGIN.x+3*L.CELL_SIZE.x and m.lords[1].pos.x > L.GRID_ORIGIN.x+6*L.CELL_SIZE.x,"lords never leave their own territory")
	check(m.lords[0].pos.x < L.cell_center(Vector2i(0,0)).x and m.lords[1].pos.x > L.cell_center(Vector2i(8,0)).x,"lords stay behind the back farm column")
	check(B.LORDS.values().all(func(l: Dictionary) -> bool: return not l.has("aura") and not l.has("farm_bonus") and not l.has("regen")),"lords have no passive effects")
	m.damage(m.lords[0],9999,1,"militia")
	tick(m,12.1)
	check(m.lords[0].hp == B.LORDS.lion.hp,"lord revives after twelve seconds")

func test_match() -> void:
	var m := bare(1)
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
	m = bare(1)
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
	m = bare(1)
	m.lords.clear()
	m.gates[1][4] = 0
	m.spawn_unit(0,4,"ram",Vector2(L.gate_stop(1)-5,L.cell_center(Vector2i(0,4)).y))
	for i: int in range(600):
		m.step(1.0/60.0)
		if m.ended: break
	check(m.ended and m.winner == 0,"our ram walking in wins too")
	m = bare(1)
	m.hit_gate(1,2,600)
	offer(m,"militia")
	check(m.can_play(0,0,L.cell_center(Vector2i(5,2))),"breach expands unit deployment to column six")
	check(not m.can_play(0,0,L.cell_center(Vector2i(5,1))),"other lanes remain closed")
	offer(m,"farm")
	check(not m.can_play(0,0,L.cell_center(Vector2i(5,2))),"buildings remain in original deployment zone")
	m.hit_gate(0,3,600)
	offer(m,"militia",1)
	check(m.can_play(1,0,L.cell_center(Vector2i(3,3))),"blue breach mirrors deployment")
	m = bare(1)
	m.lords.clear()
	var u := m.spawn_unit(1,0,"militia",Vector2(L.gate_stop(0)+100,L.cell_center(Vector2i(0,0)).y))
	m.step(0.01)
	check(u.hp == u.max_hp,"gates never shoot back")

func test_ai() -> void:
	var m := bare(3)
	m.ink[1] = 0
	check(m.AI.decide(m.snapshot(1)).is_empty(),"AI cannot afford a card with zero ink")
	offer(m,"farm",1)
	var c: Dictionary = m.AI.decide(m.snapshot(1))
	check(c.kind == "farm","AI invests in economy")
	m.add_building(1,Vector2i(7,1),"farm")
	m.decks[1] = ["farmer","militia","rain","tower","farm","militia","rain","tower"]
	m.farm_cd[1] = 999.0 # this scenario is about farmers, not planting
	m.hand_cd[1] = [0.0,0.0,0.0,0.0] # tests swap hands directly; skip the arrival cooldown
	m.ink[1] = 10
	c = m.AI.decide(m.snapshot(1))
	check(c.kind == "farmer" and c.cell == Vector2i(8,1),"AI farmers start behind fields")
	m.buildings.clear()
	m.decks[1] = ["militia","militia","militia","militia","farm","farmer","tower","rain"]
	m.farm_cd[1] = 999.0
	m.hand_cd[1] = [0.0,0.0,0.0,0.0] # tests swap hands directly; skip the arrival cooldown
	m.ink[1] = 24
	check(m.AI.decide(m.snapshot(1)).is_empty(),"normal AI waits for 25 ink attack threshold")
	m.ink[1] = 25
	c = m.AI.decide(m.snapshot(1))
	check(c.kind == "militia" and c.wave,"AI starts wave at threshold")
	m.spawn_unit(0,0,"militia",L.cell_center(Vector2i(7,0)))
	c = m.AI.decide(m.snapshot(1))
	check(c.cell.y == 0 and c.pos.x >= L.cell_center(Vector2i(7,0)).x,"AI intercepts ahead of incoming attacker")
	m = bare(3)
	m.decks[1] = ["farm","farmer","harvest","mill","militia","rain","tower","scarecrow"]
	m.hand_cd[1] = [0.0,0.0,0.0,0.0] # tests swap hands directly; skip the arrival cooldown
	m.ink[1] = 30
	m.spawn_unit(0,1,"ram",Vector2(L.gate_stop(1),L.cell_center(Vector2i(0,1)).y))
	c = m.AI.decide(m.snapshot(1))
	check(c.get("kind","") == "farm","AI keeps playing when nothing in hand can answer a threat")
	m = bare(3)
	m.ai_enabled[1] = true
	tick(m,35)
	check(m.stats[1].plays > 0 and m.ink[1] >= 0,"AI acts through shared paid play interface")


func test_cards() -> void:
	check(B.CARDS.size() == 17,"seventeen card pool")
	var off_tier: Array = []
	for kind: String in B.CARDS:
		var c: Dictionary = B.CARDS[kind]
		for stat: String in B.TIERS:
			if c.has(stat) and (c.type == "unit" or kind == "tower") and B.tier(stat,c[stat]).is_empty(): off_tier.append(kind+"."+stat)
	for kind: String in B.LORDS:
		for stat: String in ["damage","hp","speed"]:
			if B.tier(stat,B.LORDS[kind][stat]).is_empty(): off_tier.append(kind+"."+stat)
	for pair: Array in [["range",B.LORD_RANGE],["interval",B.LORD_INTERVAL],["speed",B.OX_SLOW_SPEED]]:
		if B.tier(pair[0],pair[1]).is_empty(): off_tier.append(str(pair))
	check(off_tier.is_empty(),"every troop, tower and lord stat sits exactly on an S-E tier value: %s" % str(off_tier))
	var costs: Array = B.CARDS.values().map(func(c: Dictionary) -> int: return c.cost)
	check(costs.min() >= 1 and costs.max() == 30,"card costs stay within 1 to 30")
	check(B.CARDS.values().all(func(c: Dictionary) -> bool: return c.has("role") and not c.role.is_empty()),"every card has a role")
	var m := bare(1)
	m.lords.clear()
	var farm := m.add_building(0,Vector2i(1,0),"farm")
	var other := m.add_building(0,Vector2i(1,1),"farm")
	m.add_building(0,Vector2i(2,0),"mill")
	check(m.farm_speed(farm) == B.MILL_BONUS and m.farm_speed(other) == 1,"mill boosts only its lane")
	offer(m,"mill")
	check(m.can_play(0,0,L.cell_center(Vector2i(0,1))),"a second mill can always be built (no dead card)")
	m.add_building(0,Vector2i(0,0),"mill")
	check(m.farm_speed(farm) == B.MILL_BONUS,"two mills in one lane do not stack")
	var before: float = m.ink[0]
	m.cast_spell({"kind":"harvest","team":0,"pos":farm.pos})
	check(m.stats[0].drops == 2 and farm.harvest_until == 8,"harvest produces immediately on nearby farms")
	check(m.farm_speed(farm) == 2*B.MILL_BONUS,"harvest and mill stack multiplicatively")
	m = bare(2)
	m.lords.clear()
	var target := m.add_building(1,Vector2i(7,0),"mill")
	m.cast_spell({"kind":"fire","team":0,"pos":target.pos})
	check(target.hp == maxf(0,B.CARDS.mill.hp-B.CARDS.fire.building_damage) and B.CARDS.fire.building_damage == 2*B.CARDS.fire.damage,"fire does double damage to buildings")
	m = bare(2)
	m.lords.clear()
	var ox := m.spawn_unit(0,0,"ox",Vector2(700,162))
	var knight := m.spawn_unit(1,0,"knight",Vector2(720,162))
	m.attack(ox,knight)
	check(ox.charged and knight.hp == B.CARDS.knight.hp-B.OX_CHARGE and knight.pos.x == 750,"ox charge and knockback")
	m.attack(ox,knight)
	check(knight.hp == B.CARDS.knight.hp-B.OX_CHARGE-B.CARDS.ox.damage,"ox only charges once")
	var healer := m.spawn_unit(0,0,"healer",Vector2(700,162))
	ox.hp = 300
	m.heal(healer,1)
	check(ox.hp == 300+B.HEAL_AMOUNT,"herbalist heals nearby allies")
	m = bare(2)
	m.lords.clear()
	var hunter := m.spawn_unit(0,0,"hunter",Vector2(700,162))
	knight = m.spawn_unit(1,0,"knight",Vector2(820,162))
	m.attack(hunter,knight)
	check(knight.hp == B.CARDS.knight.hp and m.projectiles.size() == 1,"arrow has real flight delay")
	m.update_projectiles(0.35)
	check(knight.hp == B.CARDS.knight.hp-B.CARDS.hunter.damage and m.projectiles.is_empty(),"arrow damages on arrival")
	m = bare(2)
	m.lords.clear()
	var ram := m.spawn_unit(0,0,"ram",Vector2(700,162))
	m.spawn_unit(1,0,"knight",Vector2(710,162))
	m.step(0.1)
	check(ram.pos.x > 700,"ram ignores blocking units")
	m = bare(2)
	m.lords.clear()
	var militia := m.spawn_unit(0,0,"militia",Vector2(1135,162))
	knight = m.spawn_unit(1,0,"knight",Vector2(1140,162))
	var scarecrow := m.add_building(1,Vector2i(7,0),"scarecrow")
	m.step(0.01)
	check(scarecrow.hp < 400 and knight.hp == B.CARDS.knight.hp,"scarecrow takes priority over nearer troops")
	m = bare(2)
	offer(m,"mob")
	m.play(0,0,L.cell_center(Vector2i(1,1)))
	var lanes: Array = m.units.map(func(u: Dictionary) -> int: return u.lane)
	lanes.sort()
	var per: int = B.CARDS.mob.count
	check(m.units.size() == 3*per and lanes.count(0) == per and lanes.count(1) == per and lanes.count(2) == per and m.units.back().spawn_delay > 0,"mob deploys a squad in each of three adjacent lanes")
	m = bare(2)
	offer(m,"mob")
	m.play(0,0,L.cell_center(Vector2i(1,4)))
	lanes = m.units.map(func(u: Dictionary) -> int: return u.lane)
	lanes.sort()
	check(lanes.min() == 2 and lanes.max() == 4 and lanes.size() == 3*per,"at an edge lane the mob shifts inward")
	m = bare(2)
	offer(m,"spearbow")
	m.play(0,0,L.cell_center(Vector2i(2,2)))
	var kinds: Array = m.units.map(func(u: Dictionary) -> String: return u.kind)
	var spear_x: float = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "militia")[0].pos.x
	var bow_x: float = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "hunter")[0].pos.x
	check(kinds.count("militia") == B.CARDS.spearbow.members[0][1] and kinds.count("hunter") == B.CARDS.spearbow.members[1][1] and bow_x < spear_x,"spear-and-bow legion: militia in front, hunters behind")
	check(m.units.all(func(u: Dictionary) -> bool: return u.card == "spearbow"),"legion troops credit their damage to the legion card")
	m = bare(2)
	offer(m,"guard")
	m.play(0,0,L.cell_center(Vector2i(2,3)))
	kinds = m.units.map(func(u: Dictionary) -> String: return u.kind)
	kinds.sort()
	check(kinds.count("knight") == B.CARDS.guard.members[0][1] and kinds.count("healer") == B.CARDS.guard.members[1][1],"cathedral guard fields knights and a herbalist")
	check(m.units.all(func(u: Dictionary) -> bool: return u.get("march",0.0) == minf(B.CARDS.knight.speed,B.CARDS.healer.speed)),"a legion marches at its slowest member's pace")
	var speeds: Array = ["mob","farmer","militia","hunter","healer","knight","ram"].map(func(k: String) -> float: return B.CARDS[k].speed)
	var sorted_speeds := speeds.duplicate()
	sorted_speeds.sort()
	sorted_speeds.reverse()
	check(speeds == sorted_speeds and speeds[0] == B.TIERS.speed[2] and speeds[-1] == B.TIERS.speed[5],"troop speeds are clearly different (mob tier B fastest, ram tier E slowest)")
	m = bare(2)
	for lane: int in range(4): m.add_building(0,Vector2i(1,lane),"farm")
	m.decks[1] = ["fire","militia","rain","tower","farm","farmer","ox","mob"]
	m.farm_cd[1] = 999.0
	m.hand_cd[1] = [0.0,0.0,0.0,0.0] # tests swap hands directly; skip the arrival cooldown
	m.ink[1] = 12
	var c: Dictionary = m.AI.decide(m.snapshot(1))
	check(c.kind == "fire" and c.cell.x == 1,"AI raids four player farms with fire")

func test_decks() -> void:
	var store = preload("res://deck_store.gd")
	for deck: Array in B.PRESETS: check(store.valid(deck) and not "farm" in deck,"preset has eight unique rotating cards (farmland is separate)")
	check(B.PRESET_LORDS.all(func(k: String) -> bool: return B.LORDS.has(k)) and B.LORDS.size() == 3,"three lords to choose from; every preset names one")
	check(not store.valid(["militia"]),"short deck rejected")
	var deck: Array = B.PRESETS[0].duplicate()
	deck[0] = "farm"
	check(not store.valid(deck),"farmland is fixed, not one of the eight")
	deck = B.PRESETS[0].duplicate()
	check(store.save_deck(deck,"user://test-deck.json","iron"),"deck saved")
	var loaded: Dictionary = store.load_full("user://test-deck.json")
	check(loaded.cards == deck and loaded.lord == "iron","deck and lord roundtrip")
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
	var lord_paths: Array[String] = []
	for kind: String in B.LORDS:
		var sprite: Texture2D = game.lord_art(kind)
		check(sprite != null and sprite.resource_path.ends_with("lord-"+kind+".png"),"chosen lord uses its own art: "+kind)
		check(not sprite.resource_path in lord_paths,"each lord has distinct source art")
		lord_paths.append(sprite.resource_path)
		check(game.lord_art(kind,1) == game.blue_art["lord_"+kind],"blue lord uses derived palette of same source")
	game.show_deck()
	game.toggle_deck_card("rain")
	check(not "rain" in game.player_deck and game.start_button.disabled,"a deck with seven cards cannot start")
	game.start_battle()
	check(game.screen == "deck","an invalid deck cannot start a battle")
	game.toggle_deck_card("rain")
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
	var rng := RandomNumberGenerator.new()
	var bad_random := 0
	for i: int in range(200):
		rng.seed = i
		var r: Array = game.random_deck(rng)
		if not DS.valid(r) or r.filter(func(k: String) -> bool: return B.CARDS[k].type == "unit").size() < 3: bad_random += 1
	check(bad_random == 0,"random spectate decks hold eight different cards with at least three troops (200 seeds)")
	game.show_watch()
	check(game.screen == "watch" and DS.valid(game.watch_decks[0]) and DS.valid(game.watch_decks[1]),"spectate setup starts with two valid decks")
	game.set_watch_source(1,2)
	check(game.watch_decks[1] == B.PRESETS[1] and game.watch_lords[1] == B.PRESET_LORDS[1],"a side can switch to a preset deck and its lord")
	var before_card: String = game.watch_decks[0][0]
	game.cycle_watch_card(0,0)
	check(game.watch_decks[0][0] != before_card and DS.valid(game.watch_decks[0]) and game.watch_source[0] == -1,"clicking a card swaps it and keeps the deck valid")
	game.watch_lords[0] = "harvest"
	var red_deck: Array = game.watch_decks[0].duplicate()
	game.spectating = true
	game.start_battle()
	check(game.model.ai_enabled == [true,true],"spectate mode lets AI play both sides")
	var dealt_red: Array = game.model.decks[0].duplicate()
	dealt_red.sort()
	red_deck.sort()
	check(dealt_red == red_deck and game.model.lords[0].lord == "harvest" and game.model.lords[1].lord == B.PRESET_LORDS[1],"spectate battle uses the decks and lords set up for each side")
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
	m.hand_cd[0] = [0.0,0.0,0.0,0.0] # tests swap hands directly; skip the arrival cooldown
	m.ink[0] = 50.0
	var field := L.cell_center(Vector2i(1,2))
	# Drag a card from the hand onto the field.
	mouse(game,game.card_rect(0).get_center(),true)
	check(game.selected == 0 and game.dragging,"pressing a card picks it up")
	mouse(game,field,false)
	check(not game.dragging and game.selected == -1 and m.units.size() == B.CARDS.militia.count,"dropping it on the field plays it")
	# Click a card, then click the field.
	m.hand_cd[0] = [0.0,0.0,0.0,0.0]
	mouse(game,game.card_rect(0).get_center(),true)
	mouse(game,game.card_rect(0).get_center(),false)
	check(game.selected == 0,"a click selects a card")
	mouse(game,game.card_rect(0).get_center(),true)
	mouse(game,game.card_rect(0).get_center(),false)
	check(game.selected == -1,"clicking the selected card again puts it back")
	# A refused placement says why and marks the spot.
	m.hand_cd[0] = [0.0,0.0,0.0,0.0]
	var kind: String = m.decks[0][0]
	game.selected = 0
	var before: int = game.effects.size()
	check(not game.try_play(0,L.cell_center(Vector2i(5,2))),"far cells are refused")
	check("左側三欄" in game.notice and game.effects.size() == before+1 and game.effects.back().kind == "fail","refusal explains why and shows a red cross")
	m.ink[0] = 0
	check("金幣不足" in m.play_error(0,0,field),"short ink is explained")
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
	var m := bare(5)
	m.lords.clear()
	var y := L.cell_center(Vector2i(0,2)).y
	var units: Array = []
	for i: int in range(6): units.append(m.spawn_unit(0,2,"militia",Vector2(500,y)))
	var offsets: Array = units.map(func(u: Dictionary) -> float: return u.dy)
	check(offsets.all(func(d: float) -> bool: return absf(d) <= B.PLACE_JITTER) and offsets.max()-offsets.min() > 4,"placed units get a small up/down offset")
	check(units.all(func(u: Dictionary) -> bool: return u.pos == Vector2(500,y)),"the offset never moves the unit itself")
	finished["overlap"] = true

func test_opening_hand() -> void:
	var m := bare(5,B.PRESETS[1].duplicate(),B.PRESETS[2].duplicate(),"harvest","iron")
	check(m.kind_at(0,m.FARM_SLOT) == "farm" and m.can_play(0,m.FARM_SLOT,L.cell_center(Vector2i(1,1))),"farmland is always playable from its own slot")
	var before: Array = m.decks[0].duplicate()
	m.play(0,m.FARM_SLOT,L.cell_center(Vector2i(1,1)))
	check(m.decks[0] == before and is_equal_approx(m.farm_cd[0],B.CARDS.farm.cooldown) and not m.can_play(0,m.FARM_SLOT,L.cell_center(Vector2i(1,2))),"the farm slot only cools down; it never rotates")
	check(m.decks[0].size() == 8 and not "farm" in m.decks[0],"the rotating deck holds the eight chosen cards")
	check(m.lords[0].lord == "harvest" and m.lords[1].max_hp == B.LORDS.iron.hp,"each side fields its chosen lord")
	var farm: Dictionary = m.buildings[0]
	check(is_equal_approx(m.farm_speed(farm),1.0),"no lord changes farm output by itself")
	tick(m,1.0)
	check(m.farm_cd[0] < B.CARDS.farm.cooldown,"farm slot cooldown counts down")
	var a := bare(31,B.PRESETS[1].duplicate())
	var b := bare(31,B.PRESETS[1].duplicate())
	check(a.decks == b.decks,"the shuffle stays reproducible per seed")
	finished["opening"] = true

func test_tutorial() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://test-ui-deck.json"
	game.set_physics_process(false)
	game.start_tutorial()
	var m = game.model
	check(m.decks[0] == game.Tutorial.DECK or m.decks[0].size() == 8,"tutorial uses its own deck")
	var plan := [["farm",Vector2i(1,2)],["farmer",Vector2i(0,2)],["militia",Vector2i(2,1)],["tower",Vector2i(1,3)],["fire",Vector2i(7,2)],["knight",Vector2i(2,2)]]
	for i: int in range(plan.size()):
		var card: String = plan[i][0]
		var slot: int = m.FARM_SLOT if card == "farm" else m.decks[0].find(card)
		check((slot == m.FARM_SLOT or slot >= 0 and slot < 4) and m.ink[0] >= B.CARDS[card].cost,"tutorial step %d puts %s in hand with enough gold" % [i+1,card])
		m.hand_cd[0] = [0.0,0.0,0.0,0.0]
		check(game.try_play(slot,L.cell_center(plan[i][1])),"tutorial step %d card can be played" % [i+1])
		var frames := 0
		while game.tutorial.stage == i and frames < 60*60:
			game._physics_process(1.0/60.0)
			frames += 1
		check(game.tutorial.stage == i+1,"tutorial step %d completes (%s)" % [i+1,card])
	check(game.tutorial.complete and m.lord_active[1] and m.ai_start < 1e8,"after the tutorial the blue side wakes up")
	var frames := 0
	while not m.ended and frames < 60*30:
		game._physics_process(1.0/60.0)
		frames += 1
	check(m.ended and m.winner == 0,"the tutorial knight walks through the broken gate and wins")
	check(game.result_value(0,"breaches") == m.gates[1].filter(func(hp: float) -> bool: return hp <= 0).size() and game.result_value(0,"breaches") >= 1 and game.result_value(0,"plays") == m.stats[0].plays and game.result_value(0,"planted") == 1,"result screen numbers match the match statistics")
	game.free()
	DirAccess.remove_absolute("user://test-ui-deck.json")
	finished["tutorial"] = true

func test_card_cooldowns() -> void:
	var cds: Array = B.CARDS.values().map(func(c: Dictionary) -> float: return c.cooldown)
	check(cds.min() >= 0 and cds.max() <= 30 and cds.max() == 30,"card cooldowns run 0 to 30 seconds")
	var m := bare(4,["farm","militia","rain","tower","knight","farmer","fire","scarecrow"])
	m.decks[0] = ["farm","militia","rain","tower","knight","farmer","fire","scarecrow"]
	m.hand_cd[0] = [0.0,0.0,0.0,0.0] # tests swap hands directly; skip the arrival cooldown
	m.hand_cd[0] = [B.CARDS.farm.cooldown,B.CARDS.militia.cooldown,B.CARDS.rain.cooldown,B.CARDS.tower.cooldown]
	m.ink[0] = 50
	check(not m.can_play(0,0,L.cell_center(Vector2i(1,1))) and "冷卻" in m.play_error(0,0,L.cell_center(Vector2i(1,1))),"a card waits for its cooldown after entering the hand")
	tick(m,B.CARDS.farm.cooldown+0.05)
	m.ink[0] = 50
	check(m.play(0,0,L.cell_center(Vector2i(1,1))),"it can be played once the cooldown is over")
	check(m.decks[0][3] == "knight" and is_equal_approx(m.hand_cd[0][3],B.CARDS.knight.cooldown),"the newly drawn card starts its own cooldown")
	check(m.hand_cd[0][0] < B.CARDS.militia.cooldown,"cards already in hand keep counting down when the hand shifts")
	var fresh := bare(9)
	check(fresh.hand_cd == [[0.0,0.0,0.0,0.0],[0.0,0.0,0.0,0.0]],"the opening hand has no cooldown")
	var late := bare(4)
	late.elapsed = B.RAMP_2
	late.hand_cd[0] = [10.0,10.0,10.0,10.0]
	late.step(1.0)
	check(is_equal_approx(late.hand_cd[0][0],8.0),"cooldowns run twice as fast once ink is doubled")
	late.elapsed = B.RAMP_1
	late.hand_cd[0] = [10.0,10.0,10.0,10.0]
	late.step(1.0)
	check(is_equal_approx(late.hand_cd[0][0],8.5),"and 1.5x as fast at the first ramp")
	finished["card_cd"] = true

func test_repair() -> void:
	var m := bare(6)
	m.lords.clear()
	var tower := m.add_building(0,Vector2i(2,1),"tower")
	tower.hp = 100
	m.elapsed = 30.0
	offer(m,"tower")
	check(m.play(0,0,tower.pos) and tower.hp == B.CARDS.tower.hp,"re-placing a tower restores its health")
	check(B.CARDS.values().all(func(c: Dictionary) -> bool: return c.type != "building" or c.expires < 0),"no building expires on its own")
	tick(m,120)
	check(tower.hp > 0 and m.buildings.has(tower),"a tower is still standing two minutes later")
	check(m.stats[0].planted == 0 and m.stats[0].repairs == 1,"a repair is not counted as a new building")
	var enemy := m.add_building(1,Vector2i(6,1),"farm")
	offer(m,"farm")
	check(not m.can_play(0,0,enemy.pos),"cannot cover an enemy building")
	m.decks[1] = ["farm","militia","rain","tower","knight","farmer","fire","scarecrow"]
	m.hand_cd[1] = [0.0,0.0,0.0,0.0]
	m.ink[1] = 20
	var hurt := m.add_building(1,Vector2i(8,3),"farm")
	hurt.hp = 40
	var c: Dictionary = m.AI.decide(m.snapshot(1))
	check(c.get("kind","") == "farm" and c.get("cell",Vector2i(-1,-1)) == Vector2i(8,3),"AI repairs a badly damaged farm")
	finished["repair"] = true

func test_start_farms() -> void:
	var m := Battle.new(3)
	var mine: Array = m.buildings.filter(func(b: Dictionary) -> bool: return b.team == 0 and b.kind == "farm").map(func(b: Dictionary) -> Vector2i: return b.cell)
	var theirs: Array = m.buildings.filter(func(b: Dictionary) -> bool: return b.team == 1 and b.kind == "farm").map(func(b: Dictionary) -> Vector2i: return b.cell)
	check(mine == [Vector2i(0,1),Vector2i(0,3)] and theirs == [Vector2i(8,1),Vector2i(8,3)],"both sides start with two farms in lanes II and IV")
	check(m.stats[0].planted == 0,"starting farms are not counted as planted")
	var farm: Dictionary = m.buildings[0]
	farm.hp = 50
	var hoer := m.spawn_unit(0,farm.cell.y,"farmer",farm.pos-Vector2(20,0))
	m.lords.clear()
	for i: int in range(240):
		m.step(1.0/60.0)
		if hoer.work_left <= 0 and farm.boost_until > 0: break
	check(farm.boost_until > 0 and farm.hp == 50+B.FARMER_HEAL,"a farmer cultivating a farm also repairs it")
	finished["start_farms"] = true

func test_descriptions() -> void:
	for kind: String in B.CARDS:
		var d: Dictionary = B.CARDS[kind]
		var text := B.card_description(kind)
		check(text.contains("%s 金幣" % B.number(d.cost)) and text.contains("冷卻 %s 秒" % B.number(d.cooldown)),"description cost and cooldown: "+kind)
		var changed: Dictionary = B.CARDS.duplicate(true)
		changed[kind].cost = 37.25
		changed[kind].cooldown = 12.75
		var updated := B.card_description(kind,changed)
		check(updated.contains("37.25 金幣") and updated.contains("冷卻 12.75 秒"),"description follows changed balance values: "+kind)
		if d.has("members"):
			for group: Array in d.members:
				check(text.contains("%s ×%d" % [B.CARDS[group[0]].name,group[1]]),"legion member count: "+kind)
		elif d.type == "unit":
			check(text.contains("×%d" % d.count) and text.contains("生命 %s" % B.number(d.hp)),"troop stats: "+kind)
		if d.type == "spell" and d.has("damage"):
			var labels := {"damage":"部隊傷害","building_damage":"建築傷害","gate_damage":"城門傷害"}
			for field: String in labels:
				var spell_changed: Dictionary = B.CARDS.duplicate(true)
				spell_changed[kind][field] = 321.75
				check(B.card_description(kind,spell_changed).contains(labels[field]+" 321.75"),"spell balance field is live: "+field)
		if d.type == "unit" and not d.has("members"):
			var labels := {"hp":"生命","damage":"傷害","range":"射程","speed":"移速"}
			for field: String in labels:
				var unit_changed: Dictionary = B.CARDS.duplicate(true)
				unit_changed[kind][field] = 654.25
				check(B.card_description(kind,unit_changed).contains(labels[field]+" 654.25"),"unit balance field is live: "+kind+" "+field)
	check(B.card_description("farm").contains("每 %s 秒產出 %s 金幣" % [B.number(B.FARM_INTERVAL),B.number(B.FARM_DROP)]),"farm interval and output share combat constants")
	check(B.card_description("farmer").contains("回復 %s 生命" % B.number(B.FARMER_HEAL)),"farmer healing from balance")
	check(B.card_description("healer").contains("回復 %s 生命" % B.number(B.HEAL_AMOUNT)),"healing from balance")
	check(B.card_description("ox").contains("首擊傷害 %s" % B.number(B.OX_CHARGE)),"charge from balance")
	check(B.card_description("harvest").contains("持續 %s 秒" % B.number(B.HARVEST_TIME)),"harvest from balance")
	check(B.card_description("mill").contains("×%s" % B.number(B.MILL_BONUS)),"mill from balance")
	var changed: Dictionary = B.CARDS.duplicate(true)
	changed.militia.hp = 777.25
	changed.militia.damage = 88.75
	changed.spearbow.members[0][1] = 9
	var legion := B.card_description("spearbow",changed)
	check(legion.contains("民兵隊 ×9") and legion.contains("生命 777.25") and legion.contains("傷害 88.75"),"mixed cards track member counts and member stat changes")
	finished["descriptions"] = true

func test_help_layout() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.show_help()
	await process_frame
	await process_frame
	for control: Control in game.ui:
		if control is RichTextLabel:
			check(control.get_content_height() <= control.size.y,"help text fits vertically: "+str(control.get_content_height()))
			check(control.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,"help wraps inside bounded column")
			check(L.HELP_PANEL.encloses(Rect2(control.position,control.size)),"help column fits panel")
	var words := "\n".join(game.help_columns())
	for term: String in ["常駐農田","三選一","8 張","金幣","城門不反擊","沒有時間限制","第六欄","各自冷卻"]:
		check(words.contains(term),"help covers current rule: "+term)
	check(not words.contains("墨水") and not words.contains("皇冠"),"help omits obsolete rules")
	game.free()
	finished["help_layout"] = true
