extends "res://tools/quick_test.gd"
func run() -> void:
	check(B.validate().is_empty(),"card validation: "+str(B.validate()))
	check(load("res://game.gd") != null,"game parses")
	check("manor_retainer" in DS.pool("lion") and not "manor_retainer" in DS.pool("mage"),"classic patrol faction")
	for lord: String in B.LORDS:
		check("axe_thrower" in DS.pool(lord) and "rolling_boulder" in DS.pool(lord),"neutral cards "+lord)
	for side: int in [0,1]:
		var forward := 1.0 if side == 0 else -1.0
		var p := L.cell_center(Vector2i(4,2))
		var m = bare()
		m.ai_enabled = [false,false]
		m.territory.fill(-1)
		for col: int in [3,4,5]: m.territory[2*9+col] = side
		var guard: Dictionary = m.spawn_unit(side,2,"manor_retainer",p)
		m.build_lookups()
		var lo: float = L.GRID_ORIGIN.x+3*L.CELL_SIZE.x+12
		var hi: float = L.GRID_ORIGIN.x+6*L.CELL_SIZE.x-12
		var turned := false
		for i: int in range(600):
			m.update_unit(guard,0.1)
			if guard.face == -forward: turned = true
		check(turned and guard.pos.x >= lo and guard.pos.x <= hi,"patrol turns and stays owned")
		guard.pos = p
		m.territory.fill(-1)
		m.territory[2*9+2] = side
		for i: int in range(150): m.update_unit(guard,0.1)
		check(m.territory_owner(m.cell_at(guard.pos)) == side,"lost territory returns to nearest ownership")
		m.territory.fill(-1)
		var old: Vector2 = guard.pos
		m.update_unit(guard,1.0)
		check(guard.pos == old,"no territory holds position")
		var enemy: Dictionary = m.spawn_unit(1-side,2,"knight",guard.pos-Vector2(20*forward,0))
		m.build_lookups()
		guard.cd = 0
		m.update_unit(guard,0.1)
		check(enemy.hp == enemy.max_hp-B.CARDS.manor_retainer.damage,"patrol intercepts enemy behind")
		m = bare()
		var axe: Dictionary = m.spawn_unit(side,2,"axe_thrower",p)
		var shield: Dictionary = m.spawn_unit(1-side,2,"shieldguard",p+Vector2(50*forward,0))
		m.attack(axe,shield)
		check(shield.hp == shield.max_hp and m.projectiles.size() == 1,"axe has actual flight")
		m.update_projectiles(B.ARROW_TIME)
		check(shield.hp == shield.max_hp-B.CARDS.axe_thrower.damage,"axe bypasses armor")
		shield.hp = shield.max_hp
		m.damage(shield,50,side,"militia")
		check(shield.hp == shield.max_hp-40,"other attacks retain armor reduction")
		m = bare()
		m.ai_enabled = [false,false]
		var ally: Dictionary = m.spawn_unit(side,2,"knight",p+Vector2(80*forward,0))
		enemy = m.spawn_unit(1-side,2,"knight",p+Vector2(140*forward,0))
		var offlane: Dictionary = m.spawn_unit(1-side,1,"knight",p+Vector2(100*forward,-L.CELL_SIZE.y))
		var building: Dictionary = m.add_building(side,Vector2i(5 if side == 0 else 3,2),"farm")
		m.lords[side].pos = p+Vector2(170*forward,0)
		m.lords[1-side].pos = p+Vector2(200*forward,0)
		m.cast_spell({"kind":"rolling_boulder","pos":p,"team":side})
		check(is_equal_approx(m.projectiles[0].pos.x,preload("res://frontier_cards.gd").start_x(side)),"rock always starts just past our lord zone")
		m.update_projectiles(3.0)
		var amount: float = B.CARDS.rolling_boulder.damage
		check(ally.hp == ally.max_hp-amount and enemy.hp == enemy.max_hp-amount,"swept boulder hits friend and enemy")
		check(building.hp == building.max_hp-amount,"boulder damages friendly buildings")
		check(m.lords[side].hp == m.lords[side].max_hp-amount and m.lords[1-side].hp == m.lords[1-side].max_hp-amount,"boulder damages both lords")
		check(offlane.hp == offlane.max_hp,"boulder does not hit other lane")
		m.update_projectiles(0.01)
		check(enemy.hp == enemy.max_hp-amount,"no repeat hit")
		m.update_projectiles(10.0)
		check(m.projectiles.is_empty() and m.gates[1-side][2] == B.GATE_HP-B.CARDS.rolling_boulder.gate_damage,"gate impact then shatter")
		check(not m.ended,"spell cannot win by invasion")
		m.cast_spell({"kind":"rolling_boulder","pos":p,"team":side})
		m.time_stop_left = 1
		m.time_stop_team = side
		old = m.projectiles[0].pos
		m.step(0.2)
		check(m.projectiles[0].pos == old,"time freeze stops boulder")
		m = bare()
		m.ai_enabled = [false,false]
		m.decks[side][0] = "rolling_boulder"
		m.hand_cd[side][0] = 0
		m.ink[side] = 50
		var start := L.cell_center(Vector2i(0 if side == 0 else 8,2))
		check(not m.can_play(side,0,p),"boulder cannot be placed mid-lane")
		check(not m.can_play(side,0,L.cell_center(Vector2i(8 if side == 0 else 0,2))),"boulder cannot start at the enemy end")
		check(m.can_play(side,0,start),"boulder starts at the first cell of the lane")
		check(m.play(side,0,start),"boulder uses normal card play")
		check(m.ink[side] == 50-B.CARDS.rolling_boulder.cost,"normal cost paid")
		m.update_spells(B.SPELL_DELAY+0.01)
		check(m.projectiles.size() == 1,"normal delayed spell launches rock")
		m = bare()
		m.decks[side][0] = "rolling_boulder"
		m.ink[side] = 50
		var victim: Dictionary = m.spawn_unit(1-side,2,"knight",p+Vector2(150*forward,0))
		var state: Dictionary = m.snapshot(side)
		state.candidates = [{"slot":0,"kind":"rolling_boulder","pos":L.cell_center(Vector2i(0 if side == 0 else 8,2)),"cell":Vector2i(0 if side == 0 else 8,2)}]
		check(not m.AI.decide(state).is_empty(),"AI uses rock on enemy lane")
		m.spawn_unit(side,2,"knight",p+Vector2(100*forward,0))
		state = m.snapshot(side)
		state.candidates = [{"slot":0,"kind":"rolling_boulder","pos":L.cell_center(Vector2i(0 if side == 0 else 8,2)),"cell":Vector2i(0 if side == 0 else 8,2)}]
		check(m.AI.decide(state).is_empty(),"AI avoids greater friendly damage")
		m.units = m.units.filter(func(u: Dictionary) -> bool: return u.team != side)
		var zone: Vector2 = preload("res://lord.gd").zone(side)
		m.lords[side].pos = Vector2(zone.y if side == 0 else zone.x,L.cell_center(Vector2i(0,2)).y) # deepest spot our lord can reach
		m.lords[side].hp = m.lords[side].max_hp
		state = m.snapshot(side)
		state.candidates = [{"slot":0,"kind":"rolling_boulder","pos":L.cell_center(Vector2i(0 if side == 0 else 8,2)),"cell":Vector2i(0 if side == 0 else 8,2)}]
		check(not m.AI.decide(state).is_empty(),"our lord at the gate does not count as friendly damage")
	print("Frontier cards: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
