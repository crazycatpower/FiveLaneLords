extends "res://tools/quick_test.gd"
const AI = preload("res://lord_ai.gd")
func run() -> void:
	check(load("res://game.gd") != null,"game parses")
	for side: int in [0,1]:
		var m = bare()
		var lord: Dictionary = m.lords[side]
		var forward := 1.0 if side == 0 else -1.0
		var home := L.gate_stop(side)
		var y := L.cell_center(Vector2i(0,2)).y
		lord.pos = Vector2(home,y)
		var front: Dictionary = m.spawn_unit(1-side,2,"knight",Vector2(home+forward*80,y))
		var raider: Dictionary = m.spawn_unit(1-side,3,"militia",Vector2(home-forward*30,y+L.CELL_SIZE.y))
		check(AI.select_target(lord,m.units) == raider,"intruder behind lord beats enemy in front")
		lord.hp = 1
		lord.last_hit = m.elapsed
		lord.retreating = true
		lord.changed = m.elapsed
		lord.think = 100
		m.Lord.step(m,lord,0.1)
		check(lord.target.y == raider.pos.y and lord.pos.y > y,"immediate return to invaded lane even at low health")
		check(not lord.retreating,"no low health retreat")
		lord.pos = Vector2(home,y)
		raider.pos.y = y+30
		check(m.lord_target(lord) == raider,"attack turns toward home intruder instead of front enemy")
		var old_hp: float = raider.hp
		lord.cd = 0
		m.Lord.step(m,lord,0.01)
		check(raider.hp < old_hp,"intruder actually hit")
		m.units.clear()
		lord.pos = Vector2(home,y)
		var near_gate: Dictionary = m.spawn_unit(1-side,2,"knight",Vector2(home,y+10))
		var far_gate: Dictionary = m.spawn_unit(1-side,2,"knight",Vector2(home,y+80))
		far_gate.serial = near_gate.serial+100
		check(AI.select_target(lord,m.units) == near_gate and m.lord_target(lord) == near_gate,"all at gates: nearest wins over higher serial")
		m.units.reverse()
		check(AI.select_target(lord,m.units) == near_gate,"selection independent of array order")
		near_gate.hp = 0
		check(AI.select_target(lord,m.units) == far_gate,"dead target retargeted immediately")
		far_gate.spawn_delay = 1
		check(AI.select_target(lord,m.units).is_empty(),"pending units not pursued")
		far_gate.spawn_delay = 0
		far_gate.stealthed = true
		check(AI.select_target(lord,m.units).is_empty(),"invisible units do not leak position")
		var stay: Vector2 = lord.pos
		m.Lord.step(m,lord,0.01)
		check(lord.pos.y == stay.y,"no visible threat: holds lane")
		m.units.clear()
		lord.pos = Vector2(home,y)
		front = m.spawn_unit(1-side,2,"knight",Vector2(home+forward*80,y))
		raider = m.spawn_unit(1-side,0,"militia",Vector2(home+forward*20,y-L.CELL_SIZE.y*2))
		for i in range(10): m.spawn_unit(1-side,2,"knight",front.pos)
		check(AI.select_target(lord,m.units) == raider,"advanced lone raider beats a large high-health wave")
		check(not m.lord_target(lord).is_empty() and m.lord_target(lord).pos == front.pos,"can still attack in-range enemy while moving to distant raider")
		m.Lord.step(m,lord,0.1)
		check(lord.pos.x >= m.Lord.zone(side).x and lord.pos.x <= m.Lord.zone(side).y,"defensive strip preserved")
	print("LORD PRIORITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
