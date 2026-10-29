extends RefCounted
const Lord = preload("res://lord.gd")
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
var rng := RandomNumberGenerator.new()
var ink: Array = [10.0,10.0]
var base_clock: Array = [0.0,0.0]
var cooldown: Array = [0.0,0.0]
var decks: Array = []
var units: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var spells: Array[Dictionary] = []
var lords: Array = []
var gates: Array = []
var gate_cd: Array = []
var castle: Array = [B.CASTLE_HP,B.CASTLE_HP]
var crowns: Array = [0,0]
var alarm: Array = [0.0,0.0,0.0,0.0,0.0]
var building_alarm: Array = [0.0,0.0,0.0,0.0,0.0]
var stats: Array = []
var events: Array[Dictionary] = []
var elapsed := 0.0
var overtime := false
var ended := false
var winner := -2
var paused := false
var next_id := 0
var ai_enabled: Array = [false,false]

func _init(seed_value: int = 1, deck_a: Array = [], deck_b: Array = []) -> void:
	rng.seed = seed_value
	for team: int in range(2):
		var deck: Array = (deck_a if team == 0 else deck_b).duplicate()
		if deck.is_empty(): deck = B.PRESETS[0].duplicate()
		for i: int in range(deck.size()-1,0,-1):
			var j := rng.randi_range(0,i)
			var swap = deck[i]
			deck[i] = deck[j]
			deck[j] = swap
		lords.append(Lord.create(team))
		decks.append(deck)
		gates.append([B.GATE_HP,B.GATE_HP,B.GATE_HP,B.GATE_HP,B.GATE_HP])
		gate_cd.append([0.0,0.0,0.0,0.0,0.0])
		stats.append({"produced":0.0,"wasted":0.0,"planted":0,"burned":0,"plays":0,"used":{},"damage":{},"spent":{},"cultivated":0,"drops":0})

func event(kind: String, pos: Vector2, team: int = 0, extra: Dictionary = {}) -> void:
	var e := {"kind":kind,"pos":pos,"team":team,"time":elapsed}
	e.merge(extra)
	events.append(e)

func cell_at(pos: Vector2) -> Vector2i:
	if not Rect2(L.GRID_ORIGIN,L.GRID_SIZE).has_point(pos): return Vector2i(-1,-1)
	return Vector2i((pos-L.GRID_ORIGIN)/L.CELL_SIZE)

func count_buildings(team: int, kind: String = "farm") -> int:
	var n := 0
	for b: Dictionary in buildings:
		if b.hp > 0 and b.team == team and b.kind == kind: n += 1
	return n

func building_at(cell: Vector2i) -> Dictionary:
	for b: Dictionary in buildings:
		if b.hp > 0 and b.cell == cell: return b
	return {}

func multiplier() -> float:
	return 1.0

func production_rate(team: int) -> float:
	var rate := 1.0/B.BASE_INTERVAL
	for b: Dictionary in buildings:
		if b.team == team and b.hp > 0 and b.kind == "farm": rate += B.FARM_DROP/B.FARM_INTERVAL*farm_speed(b)
	return rate*multiplier()

func gain_ink(team: int, amount: float) -> void:
	stats[team].produced += amount
	var waste: float = maxf(0,ink[team]+amount-B.MAX_INK)
	stats[team].wasted += waste
	ink[team] = minf(B.MAX_INK,ink[team]+amount)
	if waste > 0: event("overflow",L.GOLD_TEXT,team)

func farm_speed(b: Dictionary) -> float:
	return 2.0 if b.boost_until > elapsed else 1.0

func farm_drop(b: Dictionary) -> void:
	gain_ink(b.team,B.FARM_DROP)
	stats[b.team].drops += 1
	event("ink",b.pos,b.team)

func can_play(team: int, slot: int, pos: Vector2) -> bool:
	if ended or paused or slot < 0 or slot >= 4 or cooldown[team] > 0.00001: return false
	var card: Dictionary = B.CARDS[decks[team][slot]]
	if ink[team] < card.cost: return false
	var cell := cell_at(pos)
	if cell.x < 0: return false
	if card.type == "spell": return true
	var col := cell.x if team == 0 else 8-cell.x
	var limit := 3
	if col >= limit: return false
	if card.type == "building":
		if not building_at(cell).is_empty(): return false
		if decks[team][slot] == "mill" and count_buildings(team,"mill") > 0: return false
	return true

func play(team: int, slot: int, pos: Vector2) -> bool:
	if not can_play(team,slot,pos): return false
	var kind: String = decks[team][slot]
	var card: Dictionary = B.CARDS[kind]
	ink[team] -= card.cost
	cooldown[team] = B.PLAY_COOLDOWN
	decks[team].remove_at(slot)
	decks[team].append(kind)
	stats[team].plays += 1
	stats[team].used[kind] = stats[team].used.get(kind,0)+1
	stats[team].spent[kind] = stats[team].spent.get(kind,0.0)+card.cost
	var cell := cell_at(pos)
	if card.type == "building": add_building(team,cell,kind)
	elif card.type == "unit":
		for i: int in range(card.count):
			var u := spawn_unit(team,cell.y,kind,L.cell_center(cell))
			u.spawn_delay = i*0.12
	else: spells.append({"kind":kind,"team":team,"pos":pos,"delay":B.SPELL_DELAY})
	event("play",pos,team,{"card":kind})
	return true

func add_building(team: int, cell: Vector2i, kind: String) -> Dictionary:
	next_id += 1
	var data: Dictionary = B.CARDS[kind]
	var b := {"id":next_id,"kind":kind,"team":team,"cell":cell,"pos":L.cell_center(cell),"hp":data.hp,"max_hp":data.hp,"expires":elapsed+data.expires if data.expires > 0 else -1.0,"boost_until":0.0,"harvest_until":0.0,"ready_at":elapsed+B.FARM_START,"production":0.0,"cd":0.0,"flash":0.0}
	buildings.append(b)
	if kind == "farm": stats[team].planted += 1
	return b

func spawn_unit(team: int, lane: int, kind: String, pos: Vector2) -> Dictionary:
	next_id += 1
	var data: Dictionary = B.CARDS[kind]
	var u := {"id":next_id,"kind":kind,"team":team,"lane":lane,"pos":pos,"hp":data.hp,"max_hp":data.hp,"cd":0.0,"phase":rng.randf()*TAU,"face":1.0 if team == 0 else -1.0,"worked":[],"work_id":-1,"work_left":0.0,"spawn_delay":0.0,"charged":false,"buff_until":0.0,"flash":0.0,"heal_cd":0.0}
	units.append(u)
	return u

func damage(target: Dictionary, amount: float, team: int, kind: String) -> void:
	if target.hp <= 0: return
	var dealt := minf(amount,target.hp)
	target.hp -= amount
	if target.kind == "lord":
		target.last_hit = elapsed
		if target.hp <= 0: target.respawn = B.LORD_RESPAWN
	target.flash = 0.08
	stats[team].damage[kind] = stats[team].damage.get(kind,0.0)+dealt
	event("hit",target.pos,target.team)
	if target.has("cell") and target.team == 0: building_alarm[target.cell.y] = 1.5
	if target.hp <= 0:
		event("death",target.pos,target.team,{"card":target.kind})
		if target.kind == "farm" and kind == "fire":
			stats[target.team].burned += 1
			event("burn",target.pos,target.team)

func hit_gate(side: int, lane: int, amount: float, kind: String = "militia") -> void:
	var dealt: float
	if gates[side][lane] > 0:
		dealt = minf(gates[side][lane],amount)
		gates[side][lane] = maxf(0,gates[side][lane]-amount)
		if gates[side][lane] == 0:
			crowns[1-side] += 1
			event("breach",Vector2(L.gate_icon_x(side),L.cell_center(Vector2i(0,lane)).y),1-side)
	else:
		dealt = minf(castle[side],amount)
		castle[side] = maxf(0,castle[side]-amount)
	stats[1-side].damage[kind] = stats[1-side].damage.get(kind,0.0)+dealt
	if side == 0: alarm[lane] = 1.5
	if castle[side] <= 0:
		crowns[1-side] = 5
		finish(1-side)

func finish(side: int) -> void:
	ended = true
	winner = side
	event("finish",Vector2(800,450),side)

func nearest(pos: Vector2, team: int, radius: float, candidates: Array, lane: int = -1) -> Dictionary:
	var found: Dictionary = {}
	for other: Dictionary in candidates:
		if other.team == team or other.hp <= 0: continue
		if lane >= 0 and other.get("lane",other.get("cell",Vector2i(-1,-1)).y) != lane: continue
		var d := pos.distance_to(other.pos)
		if d <= radius:
			radius = d
			found = other
	return found

func attack(u: Dictionary, target: Dictionary) -> void:
	var data: Dictionary = B.CARDS[u.kind]
	damage(target,data.damage*attack_bonus(u),u.team,u.kind)
	u.cd = data.interval

func attack_bonus(u: Dictionary) -> float:
	var factor := B.COMMAND_BONUS if u.buff_until > elapsed else 1.0
	for lord: Dictionary in lords:
		if lord.team == u.team and lord.hp > 0 and lord.pos.distance_to(u.pos) <= B.AURA_RANGE: factor *= B.AURA_BONUS
	return factor

func cultivate(u: Dictionary, dt: float) -> bool:
	if u.kind != "farmer": return false
	if u.work_left > 0:
		u.work_left -= dt
		if u.work_left <= 0:
			for b: Dictionary in buildings:
				if b.id == u.work_id and b.hp > 0:
					b.boost_until = elapsed+B.BOOST_TIME
					stats[u.team].cultivated += 1
					event("cultivate",b.pos,u.team)
		return true
	for b: Dictionary in buildings:
		if b.hp <= 0 or b.team != u.team or b.kind != "farm" or b.cell.y != u.lane or b.id in u.worked: continue
		var distance: float = (b.pos.x-u.pos.x)*u.face
		if distance >= -0.01 and distance <= B.CARDS[u.kind].speed*dt+0.01:
			u.pos.x = b.pos.x
			u.worked.append(b.id)
			u.work_id = b.id
			u.work_left = B.CULTIVATE_TIME
			event("hoe",b.pos,u.team)
			return true
	return false

func step(dt: float) -> void:
	if paused or ended: return
	elapsed += dt
	for team: int in range(2):
		cooldown[team] = maxf(0,cooldown[team]-dt)
		base_clock[team] += dt*multiplier()
		while base_clock[team] >= B.BASE_INTERVAL-0.000001:
			base_clock[team] -= B.BASE_INTERVAL
			gain_ink(team,1.0)
	for lane: int in range(5):
		alarm[lane] = maxf(0,alarm[lane]-dt)
		building_alarm[lane] = maxf(0,building_alarm[lane]-dt)
	for b: Dictionary in buildings:
		b.flash = maxf(0,b.flash-dt)
		if b.hp <= 0: continue
		if b.expires > 0 and elapsed >= b.expires:
			b.hp = 0
			event("death",b.pos,b.team,{"card":b.kind})
			continue
		if b.kind == "farm":
			var active_dt: float = clampf(elapsed-b.ready_at,0,dt)
			b.production += active_dt*farm_speed(b)*multiplier()
			while b.production >= B.FARM_INTERVAL-0.000001:
				b.production -= B.FARM_INTERVAL
				farm_drop(b)
		elif b.kind == "tower":
			b.cd -= dt
			var target := nearest(b.pos,b.team,B.CARDS.tower.range,units)
			if not target.is_empty() and b.cd <= 0:
				damage(target,B.CARDS.tower.damage,b.team,"tower")
				b.cd = B.CARDS.tower.interval
	for spell: Dictionary in spells:
		spell.delay -= dt
		if spell.delay <= 0: cast_spell(spell)
	spells = spells.filter(func(s: Dictionary) -> bool: return s.delay > 0)
	for lord: Dictionary in lords: Lord.step(self,lord,dt)
	for u: Dictionary in units:
		u.flash = maxf(0,u.flash-dt)
		if u.hp <= 0: continue
		if u.spawn_delay > 0:
			u.spawn_delay -= dt
			continue
		u.cd = maxf(0,u.cd-dt)
		var data: Dictionary = B.CARDS[u.kind]
		var target := nearest(u.pos,u.team,data.range,units,u.lane)
		var building := nearest(u.pos,u.team,data.range,buildings,u.lane)
		if not building.is_empty() and (target.is_empty() or u.pos.distance_to(building.pos) < u.pos.distance_to(target.pos)): target = building
		if target.is_empty(): target = nearest(u.pos,u.team,54.0,lords)
		if not target.is_empty():
			if u.cd <= 0: attack(u,target)
		elif cultivate(u,dt): pass
		else:
			var stop := L.gate_stop(1-u.team)
			if (stop-u.pos.x)*u.face <= 0.001:
				if u.cd <= 0:
					hit_gate(1-u.team,u.lane,data.damage*attack_bonus(u),u.kind)
					u.cd = data.interval
			else:
				u.pos.x = move_toward(u.pos.x,stop,data.speed*dt*(B.COMMAND_BONUS if u.buff_until > elapsed else 1.0))
	units = units.filter(func(u: Dictionary) -> bool: return u.hp > 0)
	buildings = buildings.filter(func(b: Dictionary) -> bool: return b.hp > 0)

func cast_spell(s: Dictionary) -> void:
	var data: Dictionary = B.CARDS[s.kind]
	event("spell",s.pos,s.team,{"card":s.kind,"radius":data.radius})
	for u: Dictionary in units:
		if u.team != s.team and u.pos.distance_to(s.pos) <= data.radius: damage(u,data.damage,s.team,s.kind)
	for b: Dictionary in buildings:
		if b.team != s.team and b.pos.distance_to(s.pos) <= data.radius: damage(b,data.building_damage,s.team,s.kind)
	for lane: int in range(5):
		var gate_pos := Vector2(L.gate_stop(1-s.team),L.cell_center(Vector2i(0,lane)).y)
		if gate_pos.distance_to(s.pos) <= data.radius: hit_gate(1-s.team,lane,data.gate_damage,s.kind)
