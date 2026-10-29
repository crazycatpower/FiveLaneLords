extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

# Where the lord wants to stand. Returns {"pos": Vector2, "urgent": bool}.
# "urgent" (an enemy clearing the rubble of a broken gate) skips the lane-change delay and
# overrides retreating: losing the game matters more than the lord's health.
static func destination(lord: Dictionary, units: Array, gates: Array) -> Dictionary:
	var team: int = lord.team
	var forward := 1.0 if team == 0 else -1.0
	var home_x := L.gate_stop(team)
	var reach := 3.0*L.CELL_SIZE.x+30 # our territory, measured from the gate stop
	var scores := [0.0,0.0,0.0,0.0,0.0]
	var nearest_x := [INF,INF,INF,INF,INF]
	var nearest_d := [INF,INF,INF,INF,INF]
	var urgent := false
	var allies := [0,0,0,0,0]
	var positions := [0.0,0.0,0.0,0.0,0.0]
	for u: Dictionary in units:
		if u.hp <= 0: continue
		if u.team == team:
			allies[u.lane] += 1
			positions[u.lane] += u.pos.x
			continue
		var d := absf(u.pos.x-home_x)
		if d > reach: continue
		var score: float = u.hp*(1.0+maxf(0,3.0-d/L.CELL_SIZE.x))
		if gates[team][u.lane] <= 0: score *= 3.0
		if u.get("climb",0.0) > 0:
			score *= 10.0
			urgent = true
		scores[u.lane] += score
		if d < nearest_d[u.lane]:
			nearest_d[u.lane] = d
			nearest_x[u.lane] = u.pos.x
	if lord.hp < B.LORD_HP*B.LORD_RETREAT_BELOW: lord.retreating = true
	if lord.hp > B.LORD_HP*B.LORD_RETURN_ABOVE: lord.retreating = false
	if urgent: lord.retreating = false
	if lord.retreating and not urgent: return {"pos":L.spawn_position(team,2),"urgent":false}
	var lane := scores.find(scores.max())
	if scores[lane] > 0:
		# Stand right next to the enemy closest to our gate (attack range is 88 px); the old code
		# went to the middle of column 2, 138 px from raiders at the gate, and never hit them.
		return {"pos":Vector2(nearest_x[lane]+forward*30,L.cell_center(Vector2i(0,lane)).y),"urgent":urgent}
	lane = allies.find(allies.max())
	if allies[lane] > 0: return {"pos":Vector2(positions[lane]/allies[lane]-forward*60,L.cell_center(Vector2i(0,lane)).y),"urgent":false}
	return {"pos":L.cell_center(Vector2i(2 if team == 0 else 6,2)),"urgent":false}
