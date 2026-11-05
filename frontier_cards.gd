extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

# Patrol one contiguous owned stretch. Lost territory is crossed only to return home.
static func patrol(m, u: Dictionary, dt: float) -> void:
	var owned: Array[int] = []
	for col: int in range(L.GRID_COLUMNS):
		if m.territory_owner(Vector2i(col,u.lane)) == u.team: owned.append(col)
	if owned.is_empty(): return
	var col := clampi(floori((u.pos.x-L.GRID_ORIGIN.x)/L.CELL_SIZE.x),0,L.GRID_COLUMNS-1)
	if not col in owned:
		var nearest_col: int = owned[0]
		for candidate: int in owned:
			if absf(L.cell_center(Vector2i(candidate,u.lane)).x-u.pos.x) < absf(L.cell_center(Vector2i(nearest_col,u.lane)).x-u.pos.x): nearest_col = candidate
		var destination: float = L.cell_center(Vector2i(nearest_col,u.lane)).x
		u.face = signf(destination-u.pos.x)
		u.pos.x = move_toward(u.pos.x,destination,m.movement_speed(u)*dt)
		return
	var left := col
	var right := col
	while left-1 in owned: left -= 1
	while right+1 in owned: right += 1
	var lo: float = L.GRID_ORIGIN.x+left*L.CELL_SIZE.x+12
	var hi: float = L.GRID_ORIGIN.x+(right+1)*L.CELL_SIZE.x-12
	var direction: float = u.get("patrol_direction",1.0 if u.team == 0 else -1.0)
	if u.pos.x >= hi: direction = -1
	elif u.pos.x <= lo: direction = 1
	u.patrol_direction = direction
	u.face = direction
	u.pos.x = move_toward(u.pos.x,hi if direction > 0 else lo,m.movement_speed(u)*dt)

# Where the rock starts: just past our lord's patrol zone behind the gate, so it can never
# roll over our own lord, and from there the whole lane to the enemy gate.
static func start_x(team: int) -> float:
	var reach: float = B.LORD_ZONE_DEPTH+B.CARDS.rolling_boulder.radius+1
	return L.GRID_ORIGIN.x+reach if team == 0 else L.GRID_ORIGIN.x+L.GRID_SIZE.x-reach

static func launch(m, s: Dictionary) -> void:
	var lane := clampi(floori((s.pos.y-L.GRID_ORIGIN.y)/L.CELL_SIZE.y),0,L.GRID_ROWS-1)
	var direction := 1.0 if s.team == 0 else -1.0
	var pos := Vector2(start_x(s.team),L.cell_center(Vector2i(0,lane)).y) # always the whole lane
	m.projectiles.append({"rolling":true,"pos":pos,"start":pos,"team":s.team,"kind":s.kind,"lane":lane,"direction":direction,"remaining":100.0,"hit_ids":[],"angle":0.0})

static func roll(m, stone: Dictionary, dt: float) -> void:
	var data: Dictionary = B.CARDS[stone.kind]
	var start: Vector2 = stone.pos
	var stop: float = L.gate_stop(1-stone.team)
	stone.pos.x = move_toward(stone.pos.x,stop,data.roll_speed*dt)
	stone.angle += (stone.pos.x-start.x)/data.radius
	# Swept collision prevents tunnelling at fast-forward / large simulation steps.
	for actor: Dictionary in (m.units+m.buildings+m.lords).duplicate():
		if actor.hp <= 0 or actor.get("spawn_delay",0.0) > 0: continue
		if actor.kind == "lord" and not m.lord_active[actor.team]: continue
		var id: String = "lord:%d" % actor.team if actor.kind == "lord" else "actor:%d" % actor.id
		if id in stone.hit_ids: continue
		var closest := Vector2(clampf(actor.pos.x,minf(start.x,stone.pos.x),maxf(start.x,stone.pos.x)),start.y)
		if actor.pos.distance_to(closest) > data.radius: continue
		stone.hit_ids.append(id)
		m.damage(actor,data.building_damage if actor.has("cell") else data.damage,stone.team,stone.kind)
	if is_equal_approx(stone.pos.x,stop):
		m.hit_gate(1-stone.team,stone.lane,data.gate_damage,stone.kind)
		m.event("stone_impact",stone.pos,stone.team,{"radius":data.radius})
		stone.remaining = 0
