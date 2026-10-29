extends RefCounted
const AI = preload("res://enemy_ai.gd")
const Lord = preload("res://lord.gd")
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
var rng := RandomNumberGenerator.new()
var ink: Array = [10.0,10.0]
var base_clock: Array = [0.0,0.0]
var hand_cd: Array = [[0.0,0.0,0.0,0.0],[0.0,0.0,0.0,0.0]] # seconds until each hand slot may be played
var decks: Array = []
var units: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var spells: Array[Dictionary] = []
var lords: Array = []
var gates: Array = []
var alarm: Array = [0.0,0.0,0.0,0.0,0.0]
var building_alarm: Array = [0.0,0.0,0.0,0.0,0.0]
var stats: Array = []
var events: Array[Dictionary] = []
var elapsed := 0.0
var last_dt := 0.0
var ended := false
var winner := -2
var paused := false
var next_id := 0
var ai_enabled: Array = [false,false]
var difficulty := 1
var ai_clock: Array = [0.0,0.0]
var ai_pending: Array = [{},{}]
var ai_delay: Array = [0.0,0.0]
var wave_until: Array = [0.0,0.0]
var memory: Array = [{},{}]
var recent_lanes: Array = [[],[]] # lanes of each side's last troop plays, for the AI to spread its attacks
var ai_start := 0.0
var lord_active: Array = [true,true] # the tutorial keeps the blue lord idle

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
		# The opening hand (first 4) always holds farmland: swap it into a random hand slot if needed.
		var farm := deck.find("farm")
		if farm >= 4:
			var slot := rng.randi_range(0,3)
			deck[farm] = deck[slot]
			deck[slot] = "farm"
		lords.append(Lord.create(team))
		decks.append(deck)
		gates.append([B.GATE_HP,B.GATE_HP,B.GATE_HP,B.GATE_HP,B.GATE_HP])
		stats.append({"produced":0.0,"wasted":0.0,"planted":0,"burned":0,"plays":0,"used":{},"damage":{},"spent":{},"cultivated":0,"drops":0})
	# Both sides start with two farms; they are not counted as planted.
	for team: int in range(2):
		for cell: Vector2i in B.START_FARMS:
			add_building(team,Vector2i(cell.x if team == 0 else 8-cell.x,cell.y),"farm")
		stats[team].planted = 0

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
	return 2.0 if elapsed >= B.RAMP_2 else (1.5 if elapsed >= B.RAMP_1 else 1.0)

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
	var speed := 2.0 if maxf(b.boost_until,b.harvest_until) > elapsed else 1.0
	# One mill per lane counts; a second mill in the same lane does not stack (but any lane may have one,
	# so the card is never stuck in hand).
	for mill: Dictionary in buildings:
		if mill.kind == "mill" and mill.hp > 0 and mill.team == b.team and mill.cell.y == b.cell.y:
			speed *= B.MILL_BONUS
			break
	return speed

func farm_drop(b: Dictionary) -> void:
	gain_ink(b.team,B.FARM_DROP)
	stats[b.team].drops += 1
	event("ink",b.pos,b.team)

func can_play(team: int, slot: int, pos: Vector2) -> bool:
	return slot >= 0 and slot < 4 and play_error(team,slot,pos).is_empty()

# Why a card cannot go here ("" = it can). The player sees this text when a placement is refused.
func play_error(team: int, slot: int, pos: Vector2) -> String:
	if ended: return "戰局已經結束。"
	if paused: return "暫停中。"
	if slot < 0 or slot >= 4: return "先選一張手牌。"
	var kind: String = decks[team][slot]
	var card: Dictionary = B.CARDS[kind]
	if hand_cd[team][slot] > 0.00001: return "%s 剛到手上，還要冷卻 %.1f 秒。" % [card.name,hand_cd[team][slot]]
	if ink[team] < card.cost: return "墨水不足：%s 要 %d，還差 %d。" % [card.name,card.cost,ceili(card.cost-ink[team])]
	var cell := cell_at(pos)
	if cell.x < 0: return "要放在戰場的格子上。"
	if card.type == "spell": return ""
	var col := cell.x if team == 0 else 8-cell.x
	var limit := 6 if card.type == "unit" and gates[1-team][cell.y] <= 0 else 3
	if col >= limit:
		return "建築只能蓋在我方左側三欄。" if card.type == "building" else "部隊只能放在我方左側三欄（打破對方城門的那一路可到第六欄）。"
	if card.type == "building":
		var here := building_at(cell)
		if not here.is_empty() and (here.team != team or here.kind != kind): return "這格已經有別的建築；只有同一種建築可以覆蓋回血。"
	return ""

func play(team: int, slot: int, pos: Vector2) -> bool:
	if not can_play(team,slot,pos): return false
	var kind: String = decks[team][slot]
	var card: Dictionary = B.CARDS[kind]
	ink[team] -= card.cost
	decks[team].remove_at(slot)
	decks[team].append(kind)
	# The hand shifts left; the card drawn into the last slot starts its own cooldown.
	hand_cd[team].remove_at(slot)
	hand_cd[team].append(B.CARDS[decks[team][3]].cooldown)
	stats[team].plays += 1
	stats[team].used[kind] = stats[team].used.get(kind,0)+1
	stats[team].spent[kind] = stats[team].spent.get(kind,0.0)+card.cost
	var cell := cell_at(pos)
	if card.type == "building":
		var here := building_at(cell)
		if here.is_empty(): add_building(team,cell,kind)
		else: refresh_building(here)
	elif card.type == "unit": deploy(team,kind,cell)
	else: spells.append({"kind":kind,"team":team,"pos":pos,"delay":B.SPELL_DELAY})
	memory[1-team] = {"card":kind,"lane":cell.y}
	if card.type == "unit":
		recent_lanes[team].append(cell.y)
		if recent_lanes[team].size() > 3: recent_lanes[team].pop_front()
	event("play",pos,team,{"card":kind,"slot":slot})
	return true

func add_building(team: int, cell: Vector2i, kind: String) -> Dictionary:
	next_id += 1
	var data: Dictionary = B.CARDS[kind]
	var b := {"id":next_id,"kind":kind,"team":team,"cell":cell,"pos":L.cell_center(cell),"hp":data.hp,"max_hp":data.hp,"expires":elapsed+data.expires if data.expires > 0 else -1.0,"boost_until":0.0,"harvest_until":0.0,"ready_at":elapsed+B.FARM_START,"production":0.0,"cd":0.0,"flash":0.0}
	buildings.append(b)
	if kind == "farm": stats[team].planted += 1
	return b

# Placing the same building on our own one restores it: full health and a fresh lifetime.
# A farm keeps its production timer and any cultivation boost.
func refresh_building(b: Dictionary) -> void:
	var data: Dictionary = B.CARDS[b.kind]
	b.hp = b.max_hp
	if data.expires > 0: b.expires = elapsed+data.expires
	stats[b.team].repairs = stats[b.team].get("repairs",0)+1
	event("heal",b.pos,b.team)

# Fields a unit card: one troop type, a mixed legion ("members"), or the same squad in three
# adjacent lanes ("spread"; shifted inward at the edge lanes). Troops behind the front stand back.
func deploy(team: int, kind: String, cell: Vector2i) -> void:
	var card: Dictionary = B.CARDS[kind]
	var groups: Array = card.get("members",[[kind,card.get("count",1),0.0]])
	var lanes: Array = [cell.y]
	if card.get("spread",false):
		var middle := clampi(cell.y,1,3)
		lanes = [middle-1,middle,middle+1]
	var forward := 1.0 if team == 0 else -1.0
	var n := 0
	for lane: int in lanes:
		var col := cell.x if team == 0 else 8-cell.x
		col = mini(col,(6 if gates[1-team][lane] <= 0 else 3)-1) # side lanes may not be breached
		var spot := L.cell_center(Vector2i(col if team == 0 else 8-col,lane))
		for group: Array in groups:
			for i: int in range(group[1]):
				var u := spawn_unit(team,lane,group[0],spot-Vector2(forward*group[2],0))
				u.spawn_delay = n*0.12
				u.card = kind
				n += 1

func spawn_unit(team: int, lane: int, kind: String, pos: Vector2) -> Dictionary:
	next_id += 1
	var data: Dictionary = B.CARDS[kind]
	var u := {"id":next_id,"kind":kind,"team":team,"lane":lane,"pos":pos,"hp":data.hp,"max_hp":data.hp,"cd":0.0,"phase":rng.randf()*TAU,"face":1.0 if team == 0 else -1.0,"worked":[],"work_id":-1,"work_left":0.0,"spawn_delay":0.0,"charged":false,"flash":0.0,"heal_cd":0.0,"dy":rng.randf_range(-B.PLACE_JITTER,B.PLACE_JITTER)}
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
	if gates[side][lane] <= 0: return # already open; the attackers just walk in
	var dealt: float = minf(gates[side][lane],amount)
	gates[side][lane] = maxf(0,gates[side][lane]-amount)
	if gates[side][lane] == 0: event("breach",Vector2(L.gate_icon_x(side),L.cell_center(Vector2i(0,lane)).y),1-side,{"lane":lane})
	stats[1-side].damage[kind] = stats[1-side].damage.get(kind,0.0)+dealt
	if side == 0: alarm[lane] = 1.5

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
	var amount: float = data.damage
	if u.kind == "ox":
		if not u.charged:
			amount = B.OX_CHARGE
			u.charged = true
			if not target.has("cell"): target.pos.x += u.face*B.OX_KNOCKBACK
		if target.has("cell"): amount *= B.OX_BUILDING_BONUS
	amount *= attack_bonus(u)
	if u.kind == "hunter": shoot(u,target,amount)
	else: damage(target,amount,u.team,u.get("card",u.kind))
	u.cd = data.interval

func shoot(source: Dictionary, target: Dictionary, amount: float) -> void:
	projectiles.append({"pos":source.pos,"start":source.pos,"target":target,"remaining":B.ARROW_TIME,"amount":amount,"team":source.team,"kind":source.get("card",source.kind)})
	event("arrow",source.pos,source.team)

func update_projectiles(dt: float) -> void:
	for arrow: Dictionary in projectiles:
		arrow.remaining -= dt
		arrow.pos = arrow.start.lerp(arrow.target.pos,clampf(1-arrow.remaining/B.ARROW_TIME,0,1))
		if arrow.remaining <= 0 and arrow.target.hp > 0: damage(arrow.target,arrow.amount,arrow.team,arrow.kind)
	projectiles = projectiles.filter(func(a: Dictionary) -> bool: return a.remaining > 0)

func heal(u: Dictionary, dt: float) -> void:
	if u.kind != "healer": return
	u.heal_cd -= dt
	if u.heal_cd > 0: return
	u.heal_cd = B.HEAL_INTERVAL
	for ally: Dictionary in units:
		if ally.team == u.team and ally.hp > 0 and u.pos.distance_to(ally.pos) <= B.HEAL_RADIUS:
			ally.hp = minf(ally.max_hp,ally.hp+B.HEAL_AMOUNT)
			event("heal",ally.pos,u.team)

func attack_bonus(u: Dictionary) -> float:
	var factor := 1.0
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
					b.hp = minf(b.max_hp,b.hp+B.FARMER_HEAL)
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
	last_dt = dt
	update_ai(dt)
	for team: int in range(2):
		# Card cooldowns speed up together with ink (x1.5 after 3:00, x2 after 5:00).
		for slot: int in range(4): hand_cd[team][slot] = maxf(0,hand_cd[team][slot]-dt*multiplier())
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
				shoot(b,target,B.CARDS.tower.damage)
				b.cd = B.CARDS.tower.interval
	for spell: Dictionary in spells:
		spell.delay -= dt
		if spell.delay <= 0: cast_spell(spell)
	spells = spells.filter(func(s: Dictionary) -> bool: return s.delay > 0)
	update_projectiles(dt)
	for lord: Dictionary in lords:
		if lord_active[lord.team]: Lord.step(self,lord,dt)
	for u: Dictionary in units:
		u.flash = maxf(0,u.flash-dt)
		if u.hp <= 0: continue
		if u.spawn_delay > 0:
			u.spawn_delay -= dt
			continue
		u.cd = maxf(0,u.cd-dt)
		var data: Dictionary = B.CARDS[u.kind]
		heal(u,dt)
		var target: Dictionary = {} if u.kind == "ram" else nearest(u.pos,u.team,data.range,units,u.lane)
		var building := nearest(u.pos,u.team,data.range,buildings,u.lane)
		if not building.is_empty() and (target.is_empty() or u.pos.distance_to(building.pos) < u.pos.distance_to(target.pos)): target = building
		if u.kind != "ram":
			var taunts: Array = buildings.filter(func(b: Dictionary) -> bool: return b.kind == "scarecrow")
			var taunt := nearest(u.pos,u.team,minf(data.range,B.TAUNT_RADIUS),taunts,u.lane)
			if not taunt.is_empty(): target = taunt
			if target.is_empty(): target = nearest(u.pos,u.team,54.0,lords)
		if not target.is_empty():
			if u.cd <= 0: attack(u,target)
		elif cultivate(u,dt): pass
		else:
			# Gate standing: halt and batter it. Gate broken: keep walking; reaching the home line wins.
			var enemy: int = 1-u.team
			var open: bool = gates[enemy][u.lane] <= 0
			var climbed: bool = u.get("climb",0.0) >= B.RUBBLE_TIME
			var stop: float = L.gate_icon_x(enemy) if open and climbed else L.gate_stop(enemy)
			var forward := 1.0 if u.team == 0 else -1.0
			if (stop-u.pos.x)*forward <= 0.001:
				if open and not climbed:
					u.climb = u.get("climb",0.0)+dt
					if enemy == 0: alarm[u.lane] = 1.5
				elif open:
					event("invaded",u.pos,u.team,{"lane":u.lane})
					finish(u.team)
					break
				elif u.cd <= 0:
					var amount: float = data.damage
					if u.kind == "ox":
						amount = (B.OX_CHARGE if not u.charged else data.damage)*B.OX_BUILDING_BONUS
						u.charged = true
					hit_gate(1-u.team,u.lane,amount*attack_bonus(u),u.get("card",u.kind))
					u.cd = data.interval
			else:
				u.pos.x = move_toward(u.pos.x,stop,(B.OX_SLOW_SPEED if u.kind == "ox" and u.charged else data.speed)*dt)
	units = units.filter(func(u: Dictionary) -> bool: return u.hp > 0)
	buildings = buildings.filter(func(b: Dictionary) -> bool: return b.hp > 0)
	update_clock()

func cast_spell(s: Dictionary) -> void:
	var data: Dictionary = B.CARDS[s.kind]
	event("spell",s.pos,s.team,{"card":s.kind,"radius":data.radius})
	if s.kind == "harvest":
		for b: Dictionary in buildings:
			if b.team == s.team and b.hp > 0 and b.kind == "farm" and b.pos.distance_to(s.pos) <= data.radius:
				farm_drop(b)
				b.harvest_until = elapsed+B.HARVEST_TIME
		return
	for u: Dictionary in units:
		if u.team != s.team and u.pos.distance_to(s.pos) <= data.radius:
			damage(u,data.damage,s.team,s.kind)
			if s.kind == "fire": u.pos.x += B.FIRE_KNOCKBACK*(1 if s.team == 0 else -1)
	for b: Dictionary in buildings:
		if b.team != s.team and b.pos.distance_to(s.pos) <= data.radius: damage(b,data.building_damage,s.team,s.kind)
	for lane: int in range(5):
		var gate_pos := Vector2(L.gate_stop(1-s.team),L.cell_center(Vector2i(0,lane)).y)
		if gate_pos.distance_to(s.pos) <= data.radius: hit_gate(1-s.team,lane,data.gate_damage,s.kind)

func update_clock() -> void:
	if ended: return
	for ramp: float in [B.RAMP_1,B.RAMP_2]:
		if elapsed >= ramp and elapsed-last_dt < ramp: event("ramp",Vector2(800,50),0,{"multiplier":multiplier()})

func snapshot(team: int) -> Dictionary:
	var candidates: Array = []
	for slot: int in range(4):
		for row: int in range(5):
			for col: int in range(9):
				var cell := Vector2i(col,row)
				var pos := L.cell_center(cell)
				if can_play(team,slot,pos): candidates.append({"slot":slot,"kind":decks[team][slot],"pos":pos,"cell":cell})
	return {"team":team,"ink":ink[team],"enemy_ink":ink[1-team],"difficulty":difficulty,"elapsed":elapsed,"wave_until":wave_until[team],"memory":memory[team].duplicate(),"recent":recent_lanes[team].duplicate(),"units":units.duplicate(true),"buildings":buildings.duplicate(true),"gates":gates.duplicate(true),"candidates":candidates}

func update_ai(dt: float) -> void:
	if elapsed < ai_start: return
	for team: int in range(2):
		if not ai_enabled[team]: continue
		if not ai_pending[team].is_empty():
			ai_delay[team] -= dt
			if ai_delay[team] <= 0:
				var c: Dictionary = ai_pending[team]
				if c.kind == decks[team][c.slot] and play(team,c.slot,c.pos):
					if c.get("wave",false) and elapsed >= wave_until[team]: wave_until[team] = elapsed+6.0
				ai_pending[team] = {}
			continue
		ai_clock[team] -= dt
		if ai_clock[team] <= 0:
			ai_clock[team] = B.AI_TICK
			ai_pending[team] = AI.decide(snapshot(team))
			ai_delay[team] = [1.2,0.6,0.2][difficulty]
