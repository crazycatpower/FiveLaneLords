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
	assert(m.ink[0] == 2 and is_equal_approx(crystal.hp, crystal.max_hp*(1.0-B.CARDS.crystal.decay_fraction)))
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
		assert(trap.hp > 0 and trap.charges == 2, "2 charges remaining after 1st trigger")
		assert(enemy.stun_left == 10.0 and enemy.slow_left == 10.0, "10s stun and 10s slow")
		assert(m.movement_speed(enemy) == B.CARDS.militia.speed * 0.5, "speed halved while slowed")
		assert(enemy.lane == 2 and nearby.lane == 2, "teleport keeps the lane")
		assert(enemy.pos == L.cell_center(Vector2i(0 if 1-team == 0 else 8,2)) and nearby.pos == enemy.pos, "sent back to their own start of this lane")
		assert(far.pos == trap.pos+Vector2(200,0) and friendly.pos == trap.pos and bird.pos == trap.pos)
		assert(enemy in m.lane_foes[team][enemy.lane], "Teleport rebuilds lookups")
		var location: Vector2 = enemy.pos
		A.update_traps(m)
		assert(enemy.pos == location)
		var enemy2: Dictionary = m.spawn_unit(1-team,2,"militia",trap.pos)
		A.update_traps(m)
		assert(trap.hp > 0 and trap.charges == 1, "1 charge left after 2nd trigger")
		var enemy3: Dictionary = m.spawn_unit(1-team,2,"militia",trap.pos)
		A.update_traps(m)
		assert(trap.hp == 0, "consumed after 3 triggers")
	m = bare()
	m.active_lanes.assign([2])
	var trap: Dictionary = m.add_building(0,Vector2i(4,2),"teleport_trap")
	m.spawn_unit(1,2,"militia",trap.pos)
	A.update_traps(m)
	assert(trap.charges == 2, "Works on a one-lane map: troops go back down the same lane")
	m = bare()
	trap = m.add_building(0,Vector2i(4,2),"blast_trap")
	var victim: Dictionary = m.spawn_unit(1,2,"knight",trap.pos)
	var second: Dictionary = m.spawn_unit(1,2,"knight",trap.pos+Vector2(80,0))
	var safe: Dictionary = m.spawn_unit(0,2,"knight",trap.pos)
	var bird: Dictionary = m.spawn_unit(1,2,"raven",trap.pos)
	var boom: float = B.CARDS.blast_trap.explosion_damage
	A.update_traps(m)
	assert(trap.hp > 0 and trap.charges == 2 and victim.hp == victim.max_hp-boom, "first blast leaves 2 charges")
	assert(second.hp == second.max_hp-boom)
	assert(safe.hp == safe.max_hp and bird.hp == bird.max_hp)
	A.update_traps(m)
	assert(trap.charges == 2 and victim.hp == victim.max_hp-boom, "the same enemies do not set it off again")
	m.spawn_unit(1,2,"militia",trap.pos)
	A.update_traps(m)
	assert(trap.charges == 1 and victim.hp == victim.max_hp-boom*2, "a new enemy sets off the 2nd blast, which hits everyone in range")
	m.spawn_unit(1,2,"militia",trap.pos)
	A.update_traps(m)
	assert(trap.hp == 0, "spent after 3 blasts")
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
	assert(trap in m.buildings and trap.charges == 2, "Normal battle tick: one passing enemy uses one blast")
	assert(victim.hp == victim.max_hp-B.CARDS.blast_trap.explosion_damage)
	assert(victim.pos.x < trap.pos.x+30, "Troops walk through the trap's normal attack range")
	# AI plays the artificer like the farmer: from the back of a lane with worn crystals, one per lane.
	m = bare()
	m.decks[1] = ["artificer","harvest","harvest","harvest","harvest","harvest","harvest","harvest"]
	m.hand_cd[1] = [0.0,0.0,0.0,0.0]
	m.farm_cd[1] = 999.0
	m.ink[1] = 20
	m.elapsed = 25.0
	assert(m.AI.decide(m.snapshot(1)).get("kind","") != "artificer", "no worn building: the AI keeps its artificer")
	var worn: Dictionary = m.add_building(1,Vector2i(7,3),"crystal")
	worn.hp = worn.max_hp*0.5
	var pick: Dictionary = m.AI.decide(m.snapshot(1))
	assert(pick.get("kind","") == "artificer" and pick.cell.y == 3 and pick.cell.x == 8, "AI sends the artificer from behind the worn crystal: %s" % str(pick))
	m.spawn_unit(1,3,"artificer",L.cell_center(Vector2i(8,3)))
	assert(m.AI.decide(m.snapshot(1)).get("kind","") != "artificer", "one artificer per lane is enough")
	# Mage AI builds new crystals instead of re-casting on worn ones, until it has its farm goal.
	m = M.new(85,[],[],"lion","mage")
	m.ai_enabled = [false,false]
	m.lord_active = [false,false]
	m.units.clear()
	m.buildings.clear()
	m.refresh_territory()
	m.decks[1] = ["harvest","harvest","harvest","harvest","harvest","harvest","harvest","harvest"]
	m.hand_cd[1] = [99.0,99.0,99.0,99.0]
	m.farm_cd[1] = 0.0
	m.ink[1] = 20
	m.elapsed = 25.0
	var old_crystal: Dictionary = m.add_building(1,Vector2i(8,2),"crystal")
	old_crystal.hp = old_crystal.max_hp*0.2
	pick = m.AI.decide(m.snapshot(1))
	assert(pick.get("kind","") == "crystal" and pick.cell != old_crystal.cell, "below the goal the AI plants a new crystal: %s" % str(pick))
	for lane: int in [0,1,3,4,2]:
		if m.buildings.size() < 6: m.add_building(1,Vector2i(8 if lane != 2 else 7,lane),"crystal")
	for b: Dictionary in m.buildings: b.hp = b.max_hp*0.5
	assert(m.AI.decide(m.snapshot(1)).get("kind","") != "crystal", "at the goal, half-worn crystals are left to artificers")
	old_crystal.hp = old_crystal.max_hp*0.2
	pick = m.AI.decide(m.snapshot(1))
	assert(pick.get("kind","") == "crystal" and pick.cell == old_crystal.cell, "at the goal, a nearly spent crystal is re-cast: %s" % str(pick))
	print("PASS: all five cards deploy; crystal timing/decay/repair, same-lane teleport, 3-charge blast trap, AOE/consumption, tower AOE and pause, AI sends artificers to worn crystals and builds new crystals first")
	quit()
