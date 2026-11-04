extends "res://tools/quick_test.gd"
const Expansion = preload("res://lord_expansion.gd")
func run() -> void:
	check(B.validate().is_empty(),"balance valid")
	check(load("res://game.gd") != null,"game parses")
	for side: int in [0,1]:
		var m = bare(42,[],[],"rune","rune")
		m.skill_cd[side] = 0
		m.ink[side] = 50
		var cells: Array[Vector2i] = Expansion.rune_cells(m,side)
		check(cells.size() == 5,"one rune per lane")
		for cell: Vector2i in cells: check(cell.x == (2 if side == 0 else 6),"frontmost own territory mirrored")
		var wall: Dictionary = m.add_building(side,cells[0],"barricade")
		check(m.cast_skill(side),"rune cast succeeds")
		check(m.ink[side] == 35 and wall.hp == wall.max_hp,"rune costs 15 and does not overwrite")
		var traps: Array = m.buildings.filter(func(b: Dictionary) -> bool: return B.CARDS[b.kind].has("trap"))
		check(traps.size() == 5,"five valid traps spawned")
		for trap: Dictionary in traps: check(trap.team == side and m.territory_owner(trap.cell) == side,"trap on own land")
		check(m.skill_cd[side] == B.SKILL_COOLDOWN,"skill cooldown applies")
	var m = bare(42,[],[],"rune","vampire")
	m.active_lanes.assign([2])
	check(Expansion.rune_cells(m,0).size() == 1,"single lane stage only summons one trap")
	m.territory.fill(-1)
	m.skill_cd[0] = 0
	m.ink[0] = 50
	check(not m.cast_skill(0) and m.ink[0] == 50,"no territory no charge")
	m = bare(42,[],[],"vampire","lion")
	m.skill_cd[0] = 0
	m.ink[0] = 50
	var p := L.cell_center(Vector2i(3,2))
	var u: Dictionary = m.spawn_unit(0,2,"militia",p)
	var enemy: Dictionary = m.spawn_unit(1,2,"knight",p+Vector2(20,0))
	check(m.cast_skill(0) and m.ink[0] == 20,"blood costs 30")
	check(m.movement_speed(u) == B.tier_value("speed","C") and m.attack_interval(u) == B.tier_value("interval","B"),"blood raises both stats one tier")
	check(m.movement_speed(enemy) == B.CARDS.knight.speed,"enemy unaffected")
	var hp: float = u.hp
	m.attack(u,enemy)
	check(u.hp == hp+B.CARDS.militia.damage and u.max_hp == hp+B.CARDS.militia.damage,"melee gains current and max hp")
	enemy.hp = 3
	hp = u.hp
	m.attack(u,enemy)
	check(u.hp == hp+3,"overkill does not inflate gain")
	var archer: Dictionary = m.spawn_unit(0,2,"hunter",p)
	enemy = m.spawn_unit(1,2,"knight",p+Vector2(70,0))
	hp = archer.hp
	m.attack(archer,enemy)
	check(archer.hp == hp,"ranged gain waits for impact")
	m.update_projectiles(B.ARROW_TIME)
	check(archer.hp == hp+B.CARDS.hunter.damage,"ranged gain belongs to shooter")
	m.attack(archer,enemy)
	archer.hp = 0
	m.update_projectiles(B.ARROW_TIME)
	check(archer.hp == 0,"dead shooters never resurrect")
	var drummer: Dictionary = m.spawn_unit(0,2,"drummer",p)
	check(m.movement_speed(drummer) > B.CARDS.drummer.speed,"vampire affects drummer too")
	m.team_drum_until[0] = m.elapsed+3
	check(m.movement_speed(u) == B.tier_value("speed","C"),"same tier boost does not stack with drums")
	var gate_hp: float = m.gates[1][2]
	hp = u.hp
	m.hit_gate(1,2,10,"militia",u)
	check(u.hp == hp+10 and m.gates[1][2] == gate_hp-10,"gate damage grants growth")
	m.elapsed = 20
	m.team_drum_until[0] = 0
	hp = u.hp
	var max_hp: float = u.max_hp
	m.attack(u,enemy)
	check(u.hp == hp and u.max_hp == max_hp,"growth ends exactly at 20 seconds but accrued hp remains")
	check(m.movement_speed(u) == B.CARDS.militia.speed and m.attack_interval(u) == B.CARDS.militia.interval,"speed reverts at expiry")
	check(B.card_allowed("blink_blade","rune") and not B.card_allowed("blink_blade","vampire"),"faction pools valid")
	check(B.home_card("rune") == "crystal" and B.home_card("vampire") == "grave","home buildings valid")
	print("LORD EXPANSION: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
