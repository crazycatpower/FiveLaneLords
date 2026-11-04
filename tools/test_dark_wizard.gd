extends "res://tools/quick_test.gd"
func run() -> void:
	check(B.validate().is_empty(),"balance validation: "+str(B.validate()))
	check(load("res://game.gd") != null,"game parses")
	check("dark_wizard" in DS.pool("vampire") and not "dark_wizard" in DS.pool("rune"),"dark faction deck")
	for side: int in [0,1]:
		var m = bare()
		var p: Vector2 = L.cell_center(Vector2i(4,2))
		var wizard: Dictionary = m.spawn_unit(side,2,"dark_wizard",p)
		var ally: Dictionary = m.spawn_unit(side,2,"knight",p+Vector2(30,0))
		ally.hp = 1
		var serial: int = wizard.serial
		m.damage(wizard,10,1-side,"rain")
		check(ally.hp == 1,"nonfatal hit never sacrifices")
		m.damage(wizard,10000,1-side,"rain")
		check(wizard.hp == ally.max_hp and wizard.max_hp == ally.max_hp,"fatal overkill survives at donor MAX health")
		check(ally.hp == 0 and ally.serial == 0,"donor dies and releases serial")
		check(wizard.serial == serial,"wizard never enters death cleanup")
		check(m.events.filter(func(e): return e.kind == "soul_absorb").size() == 1,"soul event emitted once")
		check(not m.stats[side].damage.has("dark_wizard"),"sacrificing allies is not combat damage")
		var diagonal: Dictionary = m.spawn_unit(side,3,"skeleton",L.cell_center(Vector2i(5,3)))
		m.damage(wizard,10000,1-side,"rain")
		check(wizard.hp == diagonal.max_hp and diagonal.hp == 0,"diagonal cell included and repeated rescue allowed")
		var outside: Dictionary = m.spawn_unit(side,2,"knight",L.cell_center(Vector2i(6,2)))
		var enemy: Dictionary = m.spawn_unit(1-side,2,"knight",p)
		var pending: Dictionary = m.spawn_unit(side,2,"knight",p)
		pending.spawn_delay = 1
		m.add_building(side,Vector2i(4,2),"farm")
		m.lords[side].pos = p
		m.damage(wizard,10000,1-side,"rain")
		check(wizard.hp <= 0 and outside.hp > 0 and enemy.hp > 0 and pending.hp > 0,"no donor: dies; outside, enemy, delayed, lord, building excluded")
		m = bare()
		wizard = m.spawn_unit(side,2,"dark_wizard",p)
		var other: Dictionary = m.spawn_unit(side,2,"dark_wizard",p+Vector2(5,0))
		ally = m.spawn_unit(side,2,"shieldguard",p+Vector2(25,0))
		m.damage(wizard,10000,1-side,"rain")
		check(wizard.hp == other.max_hp and other.hp == 0 and ally.hp > 0,"nearest wizard sacrificed without recursive rescue")
		m.damage(wizard,10000,1-side,"rain")
		check(ally.hp == 0 and wizard.hp == ally.max_hp,"sacrifice bypasses donor armor")
		m = bare()
		wizard = m.spawn_unit(side,2,"dark_wizard",p)
		enemy = m.spawn_unit(1-side,2,"knight",p+Vector2(100 if side == 0 else -100,0))
		m.attack(wizard,enemy)
		check(m.projectiles.size() == 1,"wizard fires projectile")
		var hp: float = enemy.hp
		m.update_projectiles(B.ARROW_TIME)
		check(enemy.hp == hp-B.CARDS.dark_wizard.damage,"high damage applies on impact")
		# Every playable troop uses the rear edge, including mixed formations and spread cards.
		for kind: String in B.CARDS:
			if B.CARDS[kind].type != "unit" or B.CARDS[kind].get("summon_only",false): continue
			m = bare()
			var col: int = 1 if side == 0 else 7
			m.deploy(side,kind,Vector2i(col,2))
			check(not m.units.is_empty(),"deploy "+kind)
			var center_x: float = L.cell_center(Vector2i(col,2)).x
			for u: Dictionary in m.units:
				check((u.pos.x-center_x)*(1 if side == 0 else -1) <= -(L.CELL_SIZE.x*0.5-12),"rear edge "+kind)
				check(u.pos.x >= L.GRID_ORIGIN.x and u.pos.x <= L.GRID_ORIGIN.x+L.GRID_SIZE.x,"spawn inside battlefield")
		m = bare()
		var col: int = 0 if side == 0 else 8
		m.deploy(side,"spearbow",Vector2i(col,2))
		for u: Dictionary in m.units: check(u.pos.x >= L.GRID_ORIGIN.x and u.pos.x <= L.GRID_ORIGIN.x+L.GRID_SIZE.x,"edge formation stays on field")
	print("DARK WIZARD / DEPLOY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
