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

static func repair(m, u: Dictionary, dt: float = 0.0) -> bool:
	if u.kind != "artificer": return false
	var d: Dictionary = B.CARDS.artificer
	var target: Dictionary = {}
	var distance: float = d.repair_range+1.0
	var missing := 0.0
	for ally: Dictionary in m.units:
		if ally.team == u.team and ally.kind == "arcane_golem" and ally.hp > 0 and ally.max_hp-ally.hp > missing and ally.pos.distance_to(u.pos) <= d.repair_range:
			target = ally
			missing = ally.max_hp-ally.hp
	if not target.is_empty():
		u.pos.x = move_toward(u.pos.x,target.pos.x,minf(m.movement_speed(u),m.movement_speed(target))*dt)
	for b: Dictionary in m.buildings if target.is_empty() else []:
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
			if distance <= d.trigger_radius and not u.get("phased",false): triggered = true
			if distance <= d.radius: affected.append(u)
		if not triggered: continue
		if d.trap == "summon":
			var seen: Array = trap.get("summon_triggered",[])
			var fresh := false
			for u: Dictionary in affected:
				if u.get("phased",false) or u.pos.distance_to(trap.pos) > d.trigger_radius: continue
				if not u.id in seen:
					seen.append(u.id)
					fresh = true
			if not fresh: continue
			trap.summon_triggered = seen
			for i: int in range(d.summon_count):
				var child: Dictionary = m.spawn_unit(trap.team,trap.cell.y,d.summon_kind,trap.pos)
				child.card = trap.kind
				child.dy = (i-(d.summon_count-1)*0.5)*12.0
				child.spawn_delay = 0.12*i
				m.event("summoned",child.pos+Vector2(0,child.dy),child.team)
			m.event("rune_summon",trap.pos,trap.team)
			moved = true
		elif d.trap == "teleport":
			# Sends the group back to its own start of this same lane (producer 2026-11-03).
			for u: Dictionary in affected:
				if u.get("phased",false): continue
				var old: Vector2 = u.pos
				u.pos = L.cell_center(Vector2i(0 if u.team == 0 else L.GRID_COLUMNS-1,u.lane))
				u.work_id = -1
				u.work_left = 0.0
				u.stun_left = d.get("stun_duration",10.0)
				u.slow_left = d.get("slow_duration",10.0)
				m.event("teleport",old,trap.team,{"to":u.pos})
			moved = true
		else:
			# Each enemy sets off a given blast trap only once, so a crowd standing on it does not
			# spend all charges in one instant; the blast still hits everyone in range.
			var fresh := false
			for u: Dictionary in affected:
				if not u.get("phased",false) and u.pos.distance_to(trap.pos) <= d.trigger_radius and not u.id in trap.get("blasted",[]): fresh = true
			if not fresh: continue
			var blasted: Array = trap.get("blasted",[])
			for u: Dictionary in affected:
				m.damage(u,d.explosion_damage,trap.team,trap.kind)
				if not u.id in blasted: blasted.append(u.id)
			trap.blasted = blasted
			m.event("trap_blast",trap.pos,trap.team,{"radius":d.radius})
		trap.charges = trap.get("charges",d.get("charges",3))-1
		if trap.charges <= 0:
			trap.hp = 0
			m.refresh_territory()
	if moved: m.build_lookups()

static func resonance(m, u: Dictionary) -> float:
	var d: Dictionary = B.CARDS.get(u.kind,{})
	return minf(d.get("resonance_max",0.0),m.count_buildings(u.team,"crystal")*d.get("resonance",0.0))

static func blink(m, u: Dictionary) -> void:
	var step: float = B.CARDS.get(u.kind,{}).get("blink_step",0.0)
	if step <= 0 or u.hp <= 0: return
	var old: Vector2 = u.pos
	var direction := 1.0 if u.team == 0 else -1.0
	u.pos.x += direction*L.CELL_SIZE.x*step
	u.pos.x = minf(u.pos.x,L.gate_stop(1)) if u.team == 0 else maxf(u.pos.x,L.gate_stop(0))
	m.event("teleport",old,u.team,{"to":u.pos,"afterimage":u.kind})

static func reveal(m, u: Dictionary) -> void:
	if u.get("phased",false): m.event("teleport",u.pos,u.team,{"to":u.pos})
	u.phased = false
	u.stealthed = false

static func area_hit(m, u: Dictionary, point: Vector2) -> void:
	var d: Dictionary = B.CARDS[u.kind]
	for target: Dictionary in m.units+m.buildings+m.lords:
		if target.team == u.team or target.hp <= 0 or target.pos.distance_to(point) > d.radius: continue
		m.damage(target,d.area_damage,u.team,u.kind,u)
		if target.has("spawn_delay") and target.hp > 0: target.stun_left = maxf(target.get("stun_left",0.0),d.stun_on_hit)
	for lane: int in m.active_lanes:
		if Vector2(L.gate_stop(1-u.team),L.cell_center(Vector2i(0,lane)).y).distance_to(point) <= d.radius:
			m.hit_gate(1-u.team,lane,d.area_damage,u.kind,u)
	m.event("arcane_impact",point,u.team,{"from":u.pos,"radius":d.radius,"clock":true})

static func shoot_piercing_arrow(m, u: Dictionary, target: Dictionary = {}) -> void:
	var d: Dictionary = B.CARDS[u.kind]
	var direction := 1.0 if u.team == 0 else -1.0
	if not target.is_empty() and not is_equal_approx(target.pos.x,u.pos.x): direction = signf(target.pos.x-u.pos.x)
	m.projectiles.append({"source":u,"piercing":true,"hit_ids":[],"travelled":0.0,"primary_hit":false,"pos":u.pos+Vector2(0,-30),"start":u.pos+Vector2(0,-30),"origin":u.pos,"end":u.pos+Vector2(direction*d.range*d.pierce_range_multiplier,-30),"direction":direction,"range":d.range*d.pierce_range_multiplier,"lane":u.lane,"target":target,"remaining":B.ARROW_TIME,"amount":d.damage,"team":u.team,"kind":u.kind})

static func advance_piercing_arrow(m, a: Dictionary) -> void:
	var previous: float = a.travelled
	var reached: float = a.range*clampf(1-a.remaining/B.ARROW_TIME,0,1)
	a.pos = a.start.lerp(a.end,clampf(1-a.remaining/B.ARROW_TIME,0,1))
	for target: Dictionary in m.units:
		var distance: float = (target.pos.x-a.origin.x)*a.direction
		if target.team != a.team and target.hp > 0 and target.lane == a.lane and distance >= previous and distance <= reached and not target.id in a.hit_ids:
			a.hit_ids.append(target.id)
			m.damage(target,a.amount,a.team,a.kind,a.get("source",{}))
	if not a.primary_hit:
		var point: Vector2 = a.target.pos if not a.target.is_empty() else Vector2(L.gate_stop(1-a.team),a.origin.y)
		var distance: float = (point.x-a.origin.x)*a.direction
		if distance >= previous and distance <= reached:
			a.primary_hit = true
			if a.target.is_empty(): m.hit_gate(1-a.team,a.lane,a.amount,a.kind)
			elif (a.target.has("cell") or a.target.kind == "lord") and a.target.hp > 0: m.damage(a.target,a.amount,a.team,a.kind,a.get("source",{}))
	a.travelled = reached
