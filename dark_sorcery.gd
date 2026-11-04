extends RefCounted
const B = preload("res://balance.gd")

# A sacrifice is a real death, but never recursively triggers another life bargain.
static func rescue(m, wizard: Dictionary) -> bool:
	if not B.CARDS.get(wizard.kind,{}).get("soul_bargain",false): return false
	var center: Vector2i = m.cell_at(wizard.pos)
	var victim: Dictionary = {}
	var nearest_distance := INF
	for ally: Dictionary in m.units:
		if ally.id == wizard.id or ally.team != wizard.team or ally.hp <= 0 or ally.spawn_delay > 0: continue
		var cell: Vector2i = m.cell_at(ally.pos)
		if absi(cell.x-center.x) > 1 or absi(cell.y-center.y) > 1: continue
		var distance: float = wizard.pos.distance_squared_to(ally.pos)
		if distance < nearest_distance or (is_equal_approx(distance,nearest_distance) and (victim.is_empty() or ally.id < victim.id)):
			victim = ally
			nearest_distance = distance
	if victim.is_empty(): return false
	var life: float = victim.max_hp
	var origin: Vector2 = victim.pos+Vector2(0,victim.get("dy",0.0)-25)
	m.damage(victim,victim.hp,wizard.team,wizard.kind,{},true)
	wizard.hp = life
	wizard.max_hp = maxf(wizard.max_hp,life)
	m.event("soul_absorb",origin,wizard.team,{"to":wizard.pos+Vector2(0,wizard.get("dy",0.0)-25)})
	return true
