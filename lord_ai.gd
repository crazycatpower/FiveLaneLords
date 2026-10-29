extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
static func destination(lord: Dictionary, units: Array) -> Vector2:
	var team: int = lord.team
	var forward := 1.0 if team == 0 else -1.0
	if lord.hp < B.LORD_HP*0.3: lord.retreating = true
	if lord.hp > B.LORD_HP*0.7: lord.retreating = false
	if lord.retreating: return L.spawn_position(team,2)
	var scores := [0.0,0.0,0.0,0.0,0.0]
	var allies := [0,0,0,0,0]
	var positions := [0.0,0.0,0.0,0.0,0.0]
	for u: Dictionary in units:
		if u.hp <= 0: continue
		if u.team == team:
			allies[u.lane] += 1
			positions[u.lane] += u.pos.x
		else:
			var col: float = (u.pos.x-L.GRID_ORIGIN.x)/L.CELL_SIZE.x
			if (col < 3 if team == 0 else col >= 6):
				scores[u.lane] += u.hp*(1.0+maxf(0,3.0-absf(u.pos.x-L.gate_stop(team))/L.CELL_SIZE.x))
	var lane := scores.find(scores.max())
	if scores[lane] > 0: return L.cell_center(Vector2i(1 if team == 0 else 7,lane))
	lane = allies.find(allies.max())
	if allies[lane] > 0: return Vector2(positions[lane]/allies[lane]-forward*60,L.cell_center(Vector2i(0,lane)).y)
	return L.cell_center(Vector2i(2 if team == 0 else 6,2))

