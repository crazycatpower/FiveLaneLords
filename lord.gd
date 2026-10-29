extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const AI = preload("res://lord_ai.gd")
static func create(team: int) -> Dictionary:
	return {"kind":"lord","team":team,"pos":L.cell_center(Vector2i(2 if team == 0 else 6,2)),"hp":B.LORD_HP,"respawn":0.0,"cd":0.0,"spin":0.0,"command":0.0,"last_hit":-10.0,"think":0.0,"target":L.spawn_position(team,2),"changed":-10.0,"retreating":false,"flash":0.0}
static func step(m: RefCounted, lord: Dictionary, dt: float) -> void:
	if lord.hp <= 0:
		lord.respawn -= dt
		if lord.respawn <= 0:
			lord.hp = B.LORD_HP
			lord.pos = L.spawn_position(lord.team,2)
			lord.retreating = false
		return
	lord.flash = maxf(0,lord.flash-dt)
	if m.elapsed-lord.last_hit >= B.LORD_REGEN_DELAY: lord.hp = minf(B.LORD_HP,lord.hp+B.LORD_REGEN*dt)
	lord.think -= dt
	if lord.think <= 0:
		lord.think = B.AI_TICK
		var target := AI.destination(lord,m.units)
		if lord.retreating or m.elapsed-lord.changed >= B.LORD_HYSTERESIS:
			if target != lord.target: lord.changed = m.elapsed
			lord.target = target
	var min_x: float = L.spawn_position(0,0).x if lord.team == 0 else L.GRID_ORIGIN.x+3*L.CELL_SIZE.x+1
	var max_x: float = L.GRID_ORIGIN.x+6*L.CELL_SIZE.x-1 if lord.team == 0 else L.spawn_position(1,0).x
	lord.target.x = clampf(lord.target.x,min_x,max_x)
	lord.pos = lord.pos.move_toward(lord.target,B.LORD_SPEED*dt)
	lord.pos.x = clampf(lord.pos.x,min_x,max_x)
	lord.cd -= dt
	lord.spin = maxf(0,lord.spin-dt)
	lord.command = maxf(0,lord.command-dt)
	var foe: Dictionary = m.nearest(lord.pos,lord.team,B.LORD_RANGE,m.units)
	if not foe.is_empty() and lord.cd <= 0:
		m.damage(foe,B.LORD_DAMAGE,lord.team,"lord")
		lord.cd = B.LORD_INTERVAL
	var nearby: Array = []
	var allies: Array = []
	var ram := false
	for u: Dictionary in m.units:
		if u.hp <= 0: continue
		var distance: float = lord.pos.distance_to(u.pos)
		if u.team != lord.team and distance <= B.SPIN_RANGE:
			nearby.append(u)
			if u.kind == "ram": ram = true
		if u.team == lord.team and distance <= B.COMMAND_RANGE: allies.append(u)
	if lord.spin <= 0 and (nearby.size() >= 3 or ram):
		for u: Dictionary in nearby: m.damage(u,B.SPIN_DAMAGE,lord.team,"lord")
		lord.spin = B.SPIN_COOLDOWN
		m.event("spin",lord.pos,lord.team)
	if lord.command <= 0 and allies.size() >= 4:
		for u: Dictionary in allies: u.buff_until = m.elapsed+B.COMMAND_TIME
		lord.command = B.COMMAND_COOLDOWN
		m.event("command",lord.pos,lord.team)
