extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

static func rune_cells(m, team: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for lane: int in m.active_lanes:
		for offset: int in range(L.GRID_COLUMNS):
			var col := L.GRID_COLUMNS-1-offset if team == 0 else offset
			var cell := Vector2i(col,lane)
			if m.territory_owner(cell) == team and m.building_at(cell).is_empty():
				cells.append(cell)
				break
	return cells

static func cast_runes(m, team: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var traps: Array = B.CARDS.keys().filter(func(k: String) -> bool: return B.CARDS[k].has("trap") and B.card_faction(k) == "magic")
	for cell: Vector2i in rune_cells(m,team):
		var kind: String = traps[m.rng.randi_range(0,traps.size()-1)]
		var trap: Dictionary = m.add_building(team,cell,kind)
		points.append(trap.pos)
		m.event("rune_summon",trap.pos,team)
	return points

static func active(m, u: Dictionary) -> bool:
	return not u.is_empty() and u.has("spawn_delay") and u.hp > 0 and m.vampire_until[u.team] > m.elapsed

static func drain(m, source: Dictionary, amount: float, point: Vector2) -> void:
	if amount <= 0 or not active(m,source): return
	source.max_hp += amount
	source.hp += amount
	m.link(point,source.pos,source.team,"blood")
	m.event("blood_gain",source.pos,source.team)
