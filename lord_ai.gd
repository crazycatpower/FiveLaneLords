extends RefCounted
const L = preload("res://layout.gd")
const TIE := 0.5

# Signed depth prioritizes intruders beyond the gate, then the nearest equal-depth enemy.
static func select_target(lord: Dictionary, units: Array, radius: float = INF) -> Dictionary:
	var best: Dictionary = {}
	var best_depth := INF
	var best_distance := INF
	var forward := 1.0 if lord.team == 0 else -1.0
	for u: Dictionary in units:
		if u.team == lord.team or u.hp <= 0 or u.get("spawn_delay",0.0) > 0 or u.get("stealthed",false): continue
		var distance: float = lord.pos.distance_to(u.pos)
		if distance > radius: continue
		var depth: float = (u.pos.x-L.gate_stop(lord.team))*forward
		if best.is_empty() or depth < best_depth-TIE or (absf(depth-best_depth) <= TIE and (distance < best_distance-TIE or (absf(distance-best_distance) <= TIE and u.get("serial",0) > best.get("serial",0)))):
			best = u
			best_depth = depth
			best_distance = distance
	return best

static func destination(lord: Dictionary, units: Array, _gates: Array) -> Dictionary:
	var enemy := select_target(lord,units)
	if enemy.is_empty(): return {"pos":lord.pos,"urgent":false}
	return {"pos":enemy.pos,"urgent":true}
