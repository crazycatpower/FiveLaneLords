extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

static func crystal_period(b: Dictionary) -> float:
	var d: Dictionary = B.CARDS.crystal
	var vitality := clampf((b.hp-1.0)/maxf(1.0,b.max_hp-1.0),0.0,1.0)
	return lerpf(d.max_period,d.period,vitality)

static func update_building(m, b: Dictionary, dt: float) -> bool:
	if b.kind == "crystal":
		var d: Dictionary = B.CARDS.crystal
		b.production += dt
		while b.production >= crystal_period(b):
			b.production -= crystal_period(b)
			m.gain_ink(b.team,d.income)
			b.hp = maxf(1.0,b.hp-b.max_hp*d.decay_fraction)
			m.event("ink",b.pos,b.team)
		return true
	if b.kind == "arcane_tower":
		var d: Dictionary = B.CARDS.arcane_tower
		b.cd -= dt
		var target: Dictionary = m.nearest(b.pos,b.team,d.range,m.foe_units[b.team],-1,true)
		if not target.is_empty() and b.cd <= 0:
			var impact: Vector2 = target.pos
			for u: Dictionary in m.foe_units[b.team]:
				if u.hp > 0 and u.pos.distance_to(impact) <= d.radius: m.damage(u,d.area_damage,b.team,b.kind)
			b.cd = d.interval
			m.event("arcane_impact",impact,b.team,{"from":b.pos,"radius":d.radius})
		return true
	return false

static func repair(m, u: Dictionary) -> bool:
	if u.kind != "artificer": return false
	var d: Dictionary = B.CARDS.artificer
	var target: Dictionary = {}
	var distance: float = d.repair_range+1.0
	for b: Dictionary in m.buildings:
		if b.team != u.team or b.hp <= 0 or b.hp >= b.max_hp or B.CARDS[b.kind].has("trap"): continue
		var reach: float = b.pos.distance_to(u.pos)
		if reach <= d.repair_range and reach < distance:
			target = b
			distance = reach
	if target.is_empty(): return false
	if u.cd <= 0:
		target.hp = minf(target.max_hp,target.hp+d.repair_amount)
		u.cd = d.repair_interval
		m.link(u.pos,target.pos,u.team,"repair")
		m.event("repair",target.pos,u.team)
	return true

static func update_traps(m) -> void:
	var moved := false
	for trap: Dictionary in m.buildings:
		var d: Dictionary = B.CARDS[trap.kind]
		if trap.hp <= 0 or not d.has("trap"): continue
		var affected: Array[Dictionary] = []
		var triggered := false
		for u: Dictionary in m.units:
			if u.team == trap.team or u.hp <= 0 or u.spawn_delay > 0 or B.CARDS[u.kind].get("flying",false): continue
			var distance: float = u.pos.distance_to(trap.pos)
			if distance <= d.trigger_radius: triggered = true
			if distance <= d.radius: affected.append(u)
		if not triggered: continue
		if d.trap == "teleport":
			# One destination for the entire group, different from EVERY affected source lane.
			var lanes: Array = m.active_lanes.duplicate()
			for u: Dictionary in affected: lanes.erase(u.lane)
			if lanes.is_empty(): continue
			var lane: int = lanes[m.rng.randi_range(0,lanes.size()-1)]
			for u: Dictionary in affected:
				var old: Vector2 = u.pos
				u.lane = lane
				u.pos = L.cell_center(Vector2i(0 if u.team == 0 else L.GRID_COLUMNS-1,lane))
				u.work_id = -1
				u.work_left = 0.0
				m.event("teleport",old,trap.team,{"to":u.pos})
			moved = true
		else:
			for u: Dictionary in affected: m.damage(u,d.explosion_damage,trap.team,trap.kind)
			m.event("trap_blast",trap.pos,trap.team,{"radius":d.radius})
		# Consumption is not a kill and must not award corpse/kill effects.
		trap.hp = 0
		m.refresh_territory()
	if moved: m.build_lookups()
