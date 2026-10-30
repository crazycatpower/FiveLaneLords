extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const AI = preload("res://lord_ai.gd")
static func create(team: int, lord_kind: String = "lion") -> Dictionary:
	var data: Dictionary = B.LORDS.get(lord_kind,B.LORDS.lion)
	return {"kind":"lord","lord":lord_kind,"team":team,"max_hp":data.hp,"damage":data.damage,"speed":data.speed,"pos":Vector2(zone(team).y if team == 0 else zone(team).x,L.cell_center(Vector2i(0,2)).y),"hp":data.hp,"respawn":0.0,"cd":0.0,"last_hit":-10.0,"think":0.0,"target":L.spawn_position(team,2),"changed":-10.0,"retreating":false,"flash":0.0}
# x range (min, max) a lord may stand in: a strip between the gate and the back farm column.
static func zone(team: int) -> Vector2:
	if team == 0: return Vector2(L.GRID_ORIGIN.x+10,L.GRID_ORIGIN.x+B.LORD_ZONE_DEPTH)
	var right: float = L.GRID_ORIGIN.x+L.GRID_SIZE.x
	return Vector2(right-B.LORD_ZONE_DEPTH,right-10)

static func step(m: RefCounted, lord: Dictionary, dt: float) -> void:
	if lord.hp <= 0:
		lord.respawn -= dt
		if lord.respawn <= 0:
			lord.hp = lord.max_hp
			lord.pos = L.spawn_position(lord.team,2)
			lord.retreating = false
		return
	lord.flash = maxf(0,lord.flash-dt)
	if m.elapsed-lord.last_hit >= B.LORD_REGEN_DELAY: lord.hp = minf(lord.max_hp,lord.hp+B.LORD_REGEN*dt)
	lord.think -= dt
	if lord.think <= 0:
		lord.think = B.AI_TICK
		var plan: Dictionary = AI.destination(lord,m.units,m.gates)
		var target: Vector2 = plan.pos
		if plan.urgent or lord.retreating or m.elapsed-lord.changed >= B.LORD_HYSTERESIS:
			if target != lord.target: lord.changed = m.elapsed
			lord.target = target
	# Lords stay behind their farms, next to the gate (producer decision 2026-10-29).
	var min_x: float = zone(lord.team).x
	var max_x: float = zone(lord.team).y
	lord.target.x = clampf(lord.target.x,min_x,max_x)
	lord.pos = lord.pos.move_toward(lord.target,lord.speed*dt)
	lord.pos.x = clampf(lord.pos.x,min_x,max_x)
	lord.cd -= dt
	var foe: Dictionary = m.lord_target(lord)
	if not foe.is_empty() and lord.cd <= 0:
		m.damage(foe,lord.damage,lord.team,"lord")
		lord.cd = B.LORD_INTERVAL
