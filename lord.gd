extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const AI = preload("res://lord_ai.gd")
static func create(team: int, lord_kind: String = "lion") -> Dictionary:
	var data: Dictionary = B.LORDS.get(lord_kind,B.LORDS.lion)
	return {"kind":"lord","lord":lord_kind,"team":team,"max_hp":data.hp,"damage":data.damage,"aura":data.aura,"speed":data.speed,"regen":data.regen,"farm_bonus":data.farm_bonus,"pos":L.cell_center(Vector2i(2 if team == 0 else 6,2)),"hp":data.hp,"respawn":0.0,"cd":0.0,"last_hit":-10.0,"think":0.0,"target":L.spawn_position(team,2),"changed":-10.0,"retreating":false,"flash":0.0}
static func step(m: RefCounted, lord: Dictionary, dt: float) -> void:
	if lord.hp <= 0:
		lord.respawn -= dt
		if lord.respawn <= 0:
			lord.hp = lord.max_hp
			lord.pos = L.spawn_position(lord.team,2)
			lord.retreating = false
		return
	lord.flash = maxf(0,lord.flash-dt)
	if m.elapsed-lord.last_hit >= B.LORD_REGEN_DELAY: lord.hp = minf(lord.max_hp,lord.hp+B.LORD_REGEN*lord.regen*dt)
	lord.think -= dt
	if lord.think <= 0:
		lord.think = B.AI_TICK
		var plan: Dictionary = AI.destination(lord,m.units,m.gates)
		var target: Vector2 = plan.pos
		if plan.urgent or lord.retreating or m.elapsed-lord.changed >= B.LORD_HYSTERESIS:
			if target != lord.target: lord.changed = m.elapsed
			lord.target = target
	# Lords never leave their own territory: the three home deploy columns (producer decision 2026-10-29).
	var min_x: float = L.GRID_ORIGIN.x+10 if lord.team == 0 else L.GRID_ORIGIN.x+6*L.CELL_SIZE.x+1
	var max_x: float = L.GRID_ORIGIN.x+3*L.CELL_SIZE.x-1 if lord.team == 0 else L.GRID_ORIGIN.x+L.GRID_SIZE.x-10
	lord.target.x = clampf(lord.target.x,min_x,max_x)
	lord.pos = lord.pos.move_toward(lord.target,lord.speed*dt)
	lord.pos.x = clampf(lord.pos.x,min_x,max_x)
	lord.cd -= dt
	var foe: Dictionary = m.nearest(lord.pos,lord.team,B.LORD_RANGE,m.units)
	if not foe.is_empty() and lord.cd <= 0:
		m.damage(foe,lord.damage,lord.team,"lord")
		lord.cd = B.LORD_INTERVAL
