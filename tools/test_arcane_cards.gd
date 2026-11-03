extends SceneTree
const M = preload("res://battle.gd")
const B = preload("res://balance.gd")
const A = preload("res://arcane_mechanics.gd")
const L = preload("res://layout.gd")
const CARDS := ["artificer","crystal","teleport_trap","blast_trap","arcane_tower"]
func _initialize() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	call_deferred("run")
func bare():
	var m = M.new(85)
	m.ai_enabled = [false,false]
	m.lord_active = [false,false]
	m.units.clear()
	m.buildings.clear()
	m.refresh_territory()
	return m
func run() -> void:
	assert(B.validate().is_empty(),str(B.validate()))
	for card: String in CARDS:
		var m = bare()
		m.decks[0][0] = card
		m.ink[0] = B.MAX_INK
		assert(m.play(0,0,L.cell_center(Vector2i(0,2))))
		assert(m.ink[0] == B.MAX_INK-B.CARDS[card].cost)
		assert(m.stats[0].used[card] == 1)
	var m = bare()
	m.ink[0] = 0
	var crystal: Dictionary = m.add_building(0,Vector2i(1,2),"crystal")
	assert(A.crystal_period(crystal) == 10)
	m.update_buildings(9)
	assert(m.ink[0] == 0 and crystal.hp == crystal.max_hp)
	m.update_buildings(1)
	assert(m.ink[0] == 2 and crystal.hp == crystal.max_hp*0.9)
	assert(A.crystal_period(crystal) > 10)
	m.update_buildings(10)
	assert(m.ink[0] == 2)
	m.update_buildings(2)
	assert(m.ink[0] == 4)
	crystal.hp = 1
	crystal.production = 0
	assert(A.crystal_period(crystal) == 20)
	var earned: float = m.ink[0]
	m.update_buildings(20)
	assert(crystal.hp == 1 and m.ink[0] == earned+2)
	assert(is_equal_approx(m.production_rate(0),1/B.BASE_INTERVAL+0.1))
	var worker: Dictionary = m.spawn_unit(0,2,"artificer",crystal.pos-Vector2(40,0))
	assert(A.repair(m,worker))
	assert(crystal.hp == 51 and A.crystal_period(crystal) < 20)
	assert(worker.cd == B.CARDS.artificer.repair_interval)
	A.repair(m,worker)
	assert(crystal.hp == 51)
	worker.cd = 0
	crystal.hp = crystal.max_hp-1
	assert(A.repair(m,worker) and crystal.hp == crystal.max_hp)
	m.damage(crystal,crystal.max_hp,1,"militia")
	assert(crystal.hp == 0)
	worker.cd = 0
	assert(not A.repair(m,worker), "Cannot repair dead structures")
	for team: int in [0,1]:
		m = bare()
		m.active_lanes.assign([1,2,3])
		var trap: Dictionary = m.add_building(team,Vector2i(4,2),"teleport_trap")
		var enemy: Dictionary = m.spawn_unit(1-team,2,"militia",trap.pos)
		var nearby: Dictionary = m.spawn_unit(1-team,2,"hunter",trap.pos+Vector2(50,0))
		var far: Dictionary = m.spawn_unit(1-team,2,"hunter",trap.pos+Vector2(200,0))
		var friendly: Dictionary = m.spawn_unit(team,2,"militia",trap.pos)
		var bird: Dictionary = m.spawn_unit(1-team,2,"raven",trap.pos)
		m.build_lookups()
		assert(not trap in m.lane_foe_buildings[1-team][2])
		A.update_traps(m)
		assert(trap.hp == 0)
		assert(enemy.lane == nearby.lane and enemy.lane in [1,3])
		assert(enemy.pos == L.cell_center(Vector2i(0 if 1-team == 0 else 8,enemy.lane)))
		assert(far.lane == 2 and friendly.lane == 2 and bird.lane == 2)
		assert(enemy in m.lane_foes[team][enemy.lane], "Teleport rebuilds lookups")
		var location: Vector2 = enemy.pos
		A.update_traps(m)
		assert(enemy.pos == location)
	m = bare()
	m.active_lanes.assign([2])
	var trap: Dictionary = m.add_building(0,Vector2i(4,2),"teleport_trap")
	m.spawn_unit(1,2,"militia",trap.pos)
	A.update_traps(m)
	assert(trap.hp > 0, "No invalid destination on a one-lane map")
	m = bare()
	trap = m.add_building(0,Vector2i(4,2),"blast_trap")
	var victim: Dictionary = m.spawn_unit(1,2,"knight",trap.pos)
	var second: Dictionary = m.spawn_unit(1,2,"knight",trap.pos+Vector2(80,0))
	var safe: Dictionary = m.spawn_unit(0,2,"knight",trap.pos)
	var bird: Dictionary = m.spawn_unit(1,2,"raven",trap.pos)
	A.update_traps(m)
	assert(trap.hp == 0 and victim.hp == victim.max_hp-B.CARDS.blast_trap.explosion_damage)
	assert(second.hp == second.max_hp-B.CARDS.blast_trap.explosion_damage)
	assert(safe.hp == safe.max_hp and bird.hp == bird.max_hp)
	m = bare()
	var tower: Dictionary = m.add_building(0,Vector2i(3,2),"arcane_tower")
	victim = m.spawn_unit(1,2,"knight",tower.pos+Vector2(100,0))
	second = m.spawn_unit(1,2,"knight",victim.pos+Vector2(35,0))
	safe = m.spawn_unit(0,2,"knight",victim.pos)
	bird = m.spawn_unit(1,2,"raven",victim.pos)
	m.build_lookups()
	m.update_buildings(0.01)
	assert(victim.hp == victim.max_hp-B.CARDS.arcane_tower.area_damage)
	assert(second.hp == second.max_hp-B.CARDS.arcane_tower.area_damage)
	assert(safe.hp == safe.max_hp and bird.hp <= 0)
	var hp: float = victim.hp
	m.update_buildings(0.1)
	assert(victim.hp == hp)
	m.paused = true
	var clock: float = m.elapsed
	m.step(10)
	assert(m.elapsed == clock)
	# Exercise the normal tick: walking troops cross traps instead of attacking them.
	m = bare()
	trap = m.add_building(0,Vector2i(4,2),"blast_trap")
	victim = m.spawn_unit(1,2,"knight",trap.pos+Vector2(60,0))
	for i in range(180): m.step(1.0/60.0)
	assert(not trap in m.buildings, "Normal battle tick consumes and removes a triggered trap")
	assert(victim.hp == victim.max_hp-B.CARDS.blast_trap.explosion_damage)
	assert(victim.pos.x < trap.pos.x+30, "Troops walk through the trap's normal attack range")
	print("PASS: all five cards deploy; crystal timing/decay/repair, trap teams/lanes/AOE/consumption, tower AOE and pause")
	quit()
