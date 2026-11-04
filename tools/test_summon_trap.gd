extends "res://tools/quick_test.gd"
const Arcane = preload("res://arcane_mechanics.gd")
func run() -> void:
	check(B.validate().is_empty(),"balance: "+str(B.validate()))
	check(load("res://game.gd") != null,"game parses")
	check("summon_trap" in DS.pool("rune"),"rune can select trap")
	check(not "chimera" in DS.pool("rune"),"summon excluded from deck pool")
	for side: int in [0,1]:
		var m = bare(42,[],[],"rune","rune")
		var trap: Dictionary = m.add_building(side,Vector2i(4,2),"summon_trap")
		Arcane.update_traps(m)
		check(trap.charges == 3,"empty trap stays ready")
		var friend: Dictionary = m.spawn_unit(side,2,"militia",trap.pos)
		friend.spawn_delay = 0
		var enemy: Dictionary = m.spawn_unit(1-side,2,"phase_rider",trap.pos)
		enemy.spawn_delay = 0
		enemy.phased = true
		Arcane.update_traps(m)
		check(trap.charges == 3,"friendly and phased do not trigger")
		enemy.hp = 0
		var bird: Dictionary = m.spawn_unit(1-side,2,"raven",trap.pos)
		bird.spawn_delay = 0
		Arcane.update_traps(m)
		check(trap.charges == 3,"flying cannot trigger")
		bird.hp = 0
		var delayed: Dictionary = m.spawn_unit(1-side,2,"militia",trap.pos)
		delayed.spawn_delay = 1
		Arcane.update_traps(m)
		check(trap.charges == 3,"pending spawn cannot trigger")
		delayed.hp = 0
		for charge: int in range(3):
			for i: int in range(2):
				var attacker: Dictionary = m.spawn_unit(1-side,2,"militia",trap.pos)
				attacker.spawn_delay = 0
			Arcane.update_traps(m)
			var beasts: Array = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "chimera")
			check(beasts.size() == (charge+1)*B.CARDS.summon_trap.summon_count,"beasts per group")
			check(trap.charges == 2-charge,"one charge per group")
			for beast: Dictionary in beasts:
				check(beast.team == side and beast.lane == 2 and beast.card == "summon_trap","summon ownership and attribution")
			Arcane.update_traps(m)
			check(m.units.filter(func(u: Dictionary) -> bool: return u.kind == "chimera").size() == beasts.size(),"same enemies cannot retrigger")
		check(trap.hp == 0,"third activation consumes trap")
		var extra: Dictionary = m.spawn_unit(1-side,2,"militia",trap.pos)
		extra.spawn_delay = 0
		Arcane.update_traps(m)
		check(m.units.filter(func(u: Dictionary) -> bool: return u.kind == "chimera").size() == 3*B.CARDS.summon_trap.summon_count,"spent trap never summons again")
		var beast: Dictionary = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "chimera")[0]
		var hp: float = extra.hp
		m.attack(beast,extra)
		check(extra.hp < hp,"summon can attack normally")
		check(m.movement_speed(beast) > 0,"summon can move normally")
	print("SUMMON TRAP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
