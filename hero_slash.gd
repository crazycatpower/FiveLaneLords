extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

static func contains(origin: Vector2, target: Vector2, team: int) -> bool:
	var ahead := (target.x-origin.x)*(1.0 if team == 0 else -1.0)
	return ahead >= 0 and ahead <= B.LORDS.adventure.skill_cells*L.CELL_SIZE.x and absf(target.y-origin.y) <= L.CELL_SIZE.y*0.5

static func cast(m, team: int) -> void:
	var lord: Dictionary = m.lords[team]
	for actor: Dictionary in m.units+m.buildings+m.lords:
		if actor.team == team or actor.hp <= 0: continue
		if actor.get("spawn_delay",0.0) > 0: continue
		if contains(lord.pos,actor.pos,team): m.damage(actor,B.LORDS.adventure.skill_damage,team,"hero_slash")
	lord.cd = B.LORD_INTERVAL
	m.event("hero_slash",lord.pos,team,{"length":B.LORDS.adventure.skill_cells*L.CELL_SIZE.x,"width":L.CELL_SIZE.y})
