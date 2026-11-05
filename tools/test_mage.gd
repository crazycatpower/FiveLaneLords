extends SceneTree
const M = preload("res://battle.gd")
const B = preload("res://balance.gd")
const D = preload("res://deck_store.gd")
const L = preload("res://layout.gd")
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	assert(B.validate().is_empty(),str(B.validate()))
	assert(B.lord_faction("mage") == "magic" and B.home_card("mage") == "crystal")
	assert(D.pool("mage").size() == 24 and not "crystal" in D.pool("mage"))
	assert(not "crystal" in D.pool("lion"))
	assert(D.valid(D.fit_to_lord(B.PRESETS[0],"mage"),"mage"))
	# Test Mage AI skill decision requires accumulated army
	var test_ai_m = M.new(12,[],[],"mage","lion")
	assert(test_ai_m.skill_cd[0] == B.SKILL_OPENING_COOLDOWN)
	test_ai_m.skill_cd[0] = 0.0
	test_ai_m.units.clear()
	test_ai_m.ink[0] = 20
	assert(not test_ai_m.AI.skill_plan(test_ai_m.skill_state(0)).cast, "mage AI waits for accumulated army")
	for i in range(6): test_ai_m.spawn_unit(0,0,"farmer",L.cell_center(Vector2i(0,0)))
	assert(not test_ai_m.AI.skill_plan(test_ai_m.skill_state(0)).cast, "mage AI does not count economic workers as army")
	test_ai_m.units.clear()
	for i in range(9): test_ai_m.spawn_unit(0,2,"militia",L.cell_center(Vector2i(4,2)))
	assert(not test_ai_m.AI.skill_plan(test_ai_m.skill_state(0)).cast, "mage AI does not cast under 10 troops")
	test_ai_m.spawn_unit(0,1,"militia",L.cell_center(Vector2i(4,1)))
	assert(test_ai_m.AI.skill_plan(test_ai_m.skill_state(0)).cast, "mage AI casts skill when 10+ troops accumulated")

	for team in [0,1]:
		var m = M.new(32,[],[],"mage","mage")
		assert(m.skill_cd[team] == B.SKILL_OPENING_COOLDOWN)
		m.skill_cd[team] = 0.0
		m.units.clear()
		m.ink[team] = B.skill_cost("mage")-1
		assert(not m.cast_skill(team))
		m.ink[team] = B.skill_cost("mage")
		var p := L.cell_center(Vector2i(4,2))
		var ally: Dictionary = m.spawn_unit(team,2,"militia",p)
		var enemy: Dictionary = m.spawn_unit(1-team,2,"knight",p+Vector2(30 if team == 0 else -30,0)) # in front: troops do not hit behind
		var walker: Dictionary = m.spawn_unit(team,0,"militia",L.cell_center(Vector2i(3,0)))
		var walker_start: Vector2 = walker.pos
		var enemy_start: Vector2 = enemy.pos
		var enemy_cd: float = enemy.cd
		var other_lord: Dictionary = m.lords[1-team].duplicate(true)
		m.lords[team].hp -= 100
		m.lords[team].cd = 2
		m.hand_cd[0][0] = 8
		m.projectiles.append({"pos":p,"start":p,"impact":p+Vector2(100,0),"flight":1.0,"remaining":1.0,"amount":80.0,"radius":68.0,"team":team,"kind":"catapult"})
		assert(m.cast_skill(team) and m.ink[team] == 0)
		assert(not m.cast_skill(1-team))
		assert(not m.play(team,0,p))
		var production: Array = m.buildings.map(func(b): return b.production)
		var clock: float = m.elapsed
		for i in range(599): m.step(1.0/60.0)
		assert(m.time_stopped() and m.elapsed == clock)
		assert(m.ink[team] == 0 and m.hand_cd[0][0] == 8 and m.skill_cd[team] == B.SKILL_COOLDOWN)
		assert(m.buildings.map(func(b): return b.production) == production)
		assert(m.projectiles[0].remaining == 1.0 and m.projectiles[0].pos == p)
		assert(enemy.pos == enemy_start and enemy.cd == enemy_cd and enemy.hp < enemy.max_hp)
		assert(walker.pos != walker_start and ally.cd > 0)
		assert(m.lords[1-team] == other_lord and m.lords[team].cd < 2)
		m.step(1.0/60.0)
		assert(not m.time_stopped() and is_equal_approx(m.elapsed,clock))
		m.step(0.1)
		assert(m.elapsed > clock and m.projectiles[0].remaining < 1.0)
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.model = M.new(42,[],[],"mage","lion")
	g.enter_battle("Mage test")
	g.model.skill_cd[0] = 0.0
	g.model.ink[0] = 20
	assert(g.model.cast_skill(0))
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	g._unhandled_input(key)
	g.toggle_pause()
	assert(not g.model.paused)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = g.library.INFO_RECT.get_center()
	g._unhandled_input(click)
	assert(g.screen == "battle")
	var called := [false]
	var btn = g.button(Rect2(0,0,20,20),"test",func(): called[0] = true)
	btn.pressed.emit()
	assert(not called[0])
	g.effects.append({"kind":"ink","pos":Vector2.ZERO,"team":0,"life":1.0,"duration":1.0})
	g._process(1)
	assert(g.effects.back().life == 1.0)
	g.model.finish(0)
	g.model.step(B.LORDS.mage.freeze_duration)
	assert(not g.ui_time_locked(),"Victory during freeze must never leave UI locked")
	btn.pressed.emit()
	assert(called[0])
	g.free()
	print("PASS: mage magic+neutral deck, skill cost, 10-second freeze, both teams, units/caster active, world/projectiles/UI frozen, resume and victory unlock")
	quit()
