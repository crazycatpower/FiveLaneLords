extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

# Pure decision: snapshot in, legal play out. No model mutation or random globals.
# Lanes are scored separately so the AI defends whichever lane is in danger, spreads farms,
# and spreads its attacks instead of feeding every troop into one lane.
const DEFEND_REACH := 4.5
# With this much ink and no better play, spend the most useful card in hand anyway. Without it a
# hand of buildings and idle spells never left the hand, the deck stopped rotating and the AI sat
# at the 50-ink cap (about 35% of all ink was wasted in tools/sim.gd).
const SPEND_AT := 35.0 # columns from our gate at which an approaching enemy counts as a threat

# 困難 plays with these weights: round 1 of tools/evolve_ai.py, 66.5% against the hand-written AI
# over 200 mirror matches (docs/AI演化報告.md). They must equal tools/evolved_ai.json (tested).
const EVOLVED := {"hoard":0.9521,"skill_after":65.7997,"harvest_max_farms":8.9992,"iron_gate_share":0.6,"iron_hoard":0.8958,"spend_at":33.8974,"wave_at":23.1776,"wave_time":6.0537,"defend_reach":4.5,"farm_goal":6.0,"farm_score":769.8742,"farmer_score":798.5413,"raid_score":700.0,"raid_min_farms":3.0,"guard_score":699.5859,"guard_after":9.7386,"ram_score":707.1471,"ram_reserve":11.3229,"ram_escort":281.8677,"healer_score":664.9564,"wave_score":643.607,"mill_score":636.083,"mill_min_farms":4.0,"harvest_score":647.8686,"harvest_min":2.0,"repair_below":0.6728,"atk_gate":0.4517,"atk_foes":0.8,"atk_recent":184.4357}

# Weights for a snapshot: explicit params win; otherwise 困難 uses EVOLVED and the other levels the
# hand-written defaults (an empty dictionary).
static func weights(s: Dictionary) -> Dictionary:
	var pr: Dictionary = s.get("params",{})
	if pr.is_empty() and s.get("difficulty",1) == 2: return EVOLVED
	return pr

# Lord skill: {"cast": bool, "save": bool}. While saving, the AI only defends and repairs, so its
# purse can reach the full SKILL_COST.
#
# Every tunable weight is read as pr.get(name, default); an empty params dictionary (the normal
# game) gives exactly the hand-written AI. tools/evolve_ai.py searches these weights.
static func skill_plan(k: Dictionary) -> Dictionary:
	if not k.ready: return {"cast":false,"save":false}
	var pr: Dictionary = weights(k)
	var wanted := false
	var hoard: bool = pr.get("hoard",1.0) >= 0.5
	match k.lord:
		"underworld": wanted = k.get("graves",0) >= 2
		"lion": wanted = k.elapsed >= pr.get("skill_after",45.0)
		"harvest": wanted = k.elapsed >= pr.get("skill_after",45.0) and k.farms <= pr.get("harvest_max_farms",7.0)
		"iron":
			wanted = k.broken > 0 or k.gate_share < pr.get("iron_gate_share",0.6)
			hoard = pr.get("iron_hoard",1.0) >= 0.5
	# Hoard only once the purse is fairly full, so the AI keeps attacking while it saves up.
	return {"cast":wanted and k.ink >= B.skill_cost(k.lord),"save":wanted and hoard and k.ink >= pr.get("save_from",30.0)}

static func decide(s: Dictionary) -> Dictionary:
	var pr: Dictionary = weights(s)
	var team: int = s.team
	var forward := 1.0 if team == 0 else -1.0
	var home_x := L.gate_stop(team)
	var ours := [0.0,0.0,0.0,0.0,0.0]
	var foes := [0.0,0.0,0.0,0.0,0.0]
	var urgency := [0.0,0.0,0.0,0.0,0.0]
	var foe_x := [INF,INF,INF,INF,INF]
	var foe_reach := [INF,INF,INF,INF,INF] # distance (px) of the closest enemy to our gate
	var my_farms := [0,0,0,0,0]
	var their_farms := [0,0,0,0,0]
	var their_guard := [0.0,0.0,0.0,0.0,0.0]
	var farm_total := 0
	var own_buildings := 0
	var my_troops := [0.0,0.0,0.0,0.0,0.0] # hp of our troops per lane (buildings excluded)
	var my_guard := [0,0,0,0,0] # our towers and scarecrows per lane
	var my_troop_x: Array = [[],[],[],[],[]] # x of our troops per lane, for the healer
	for u: Dictionary in s.units:
		if u.hp <= 0: continue
		if u.team == team:
			ours[u.lane] += u.hp
			my_troops[u.lane] += u.hp
			my_troop_x[u.lane].append(u.pos.x)
			continue
		foes[u.lane] += u.hp
		var distance := absf(u.pos.x-home_x)
		var closeness := clampf(1.0-distance/(6.0*L.CELL_SIZE.x),0,1)
		urgency[u.lane] += u.hp*(0.3+1.7*closeness)
		if distance < foe_reach[u.lane]:
			foe_reach[u.lane] = distance
			foe_x[u.lane] = u.pos.x
	for b: Dictionary in s.buildings:
		if b.hp <= 0: continue
		if b.team == team:
			own_buildings += 1
			if b.kind == "farm":
				my_farms[b.cell.y] += 1
				farm_total += 1
			if B.has_tag(b.kind,"guard"):
				ours[b.cell.y] += b.hp
				my_guard[b.cell.y] += 1
		elif b.kind == "farm": their_farms[b.cell.y] += 1
		elif B.has_tag(b.kind,"obstacle"): their_guard[b.cell.y] += b.hp
	# Defence: the lane whose approaching enemies most outweigh what we have there.
	var danger := -1
	var largest := 0.0
	for lane: int in range(5):
		if foe_reach[lane] > pr.get("defend_reach",DEFEND_REACH)*L.CELL_SIZE.x: continue
		var need: float = urgency[lane]*(3.0 if s.gates[team][lane] <= 0 else 1.0)-ours[lane]
		if need > largest:
			largest = need
			danger = lane
	# Attack: score every lane instead of always hitting the lowest gate.
	var attack := [0.0,0.0,0.0,0.0,0.0]
	var recent: Array = s.get("recent",[])
	for lane: int in range(5):
		var gate: float = s.gates[1-team][lane]
		attack[lane] = (B.GATE_HP-gate)*pr.get("atk_gate",0.4)+ours[lane]*0.3-foes[lane]*pr.get("atk_foes",0.8)-their_guard[lane]*0.5-recent.count(lane)*pr.get("atk_recent",140.0)+jitter(lane,s.elapsed)
		if gate <= 0 and foes[lane] < 150: attack[lane] += 600 # an open gate with nobody guarding it: walk in
	var target_lane: int = attack.find(attack.max())
	var farm_goal: int = int(pr.get("farm_goal",[3,6,99][s.difficulty]))
	var threshold: float = float(pr.get("wave_at",[15.0,25.0,35.0][s.difficulty]))
	var wave: bool = s.elapsed < s.wave_until or s.ink >= threshold
	var enemy_farm_total: int = their_farms.reduce(func(a: int,b: int) -> int: return a+b,0)
	var best: Dictionary = {}
	var best_score := -INF
	# If nothing in hand can answer the threat (e.g. a ram already at our gate), play normally
	# instead of freezing: plant, cultivate or counter-attack elsewhere.
	for defend: int in ([danger,-1] if danger >= 0 else [-1]):
		for c: Dictionary in s.candidates:
			var data: Dictionary = B.CARDS[c.kind]
			var score := -INF
			var lane: int = c.cell.y
			var col: int = c.cell.x if team == 0 else 8-c.cell.x
			if data.type == "building":
				var here: Dictionary = own_building(s.buildings,team,c.cell)
				if not here.is_empty():
					# Same building on top of ours = repair. Only worth it when it is badly hurt.
					var health: float = here.hp/here.max_hp
					if health < pr.get("repair_below",0.6):
						score = 700.0+(1.0-health)*150.0
						if score > best_score:
							best_score = score
							best = c.duplicate()
					continue
			if s.get("saving",false) and defend < 0: continue # holding gold for the lord's skill
			var dark_score := dark_card_score(c,s,ours,foes,my_troop_x)
			if dark_score > best_score:
				best_score = dark_score
				best = c.duplicate()
			if defend >= 0:
				if lane != defend: continue
				var fx: float = foe_x[lane]
				if data.type == "spell" and B.has_tag(c.kind,"defend_spell"): score = 1000-c.pos.distance_to(Vector2(fx,c.pos.y))
				elif data.type == "unit" and not B.has_tag(c.kind,"no_defend"):
					# Troops never turn round, so spawn between the attacker and our gate.
					if (fx-c.pos.x)*forward >= 0: score = 900-absf(fx-c.pos.x)*0.5-data.cost*3
				elif B.has_tag(c.kind,"defend_building"): score = 950-absf(fx-c.pos.x)
			else:
				if c.kind == "farm" and farm_total < farm_goal:
					# Spread farms over the lanes, back row first, away from lanes under pressure.
					score = pr.get("farm_score",800.0)-my_farms[lane]*45-col*15-urgency[lane]*0.05+jitter(lane,s.elapsed)*0.2
				elif c.kind == "farmer":
					var ahead := 0
					for b: Dictionary in s.buildings:
						if b.team == team and b.kind == "farm" and b.hp > 0 and b.cell.y == lane and (b.pos.x-c.pos.x)*forward > 0 and b.boost_until <= s.elapsed: ahead += 1
					if ahead > 0: score = pr.get("farmer_score",740.0)+ahead*12-col*6
				elif enemy_farm_total >= pr.get("raid_min_farms",4.0) and B.has_tag(c.kind,"raid") and their_farms[lane] == their_farms.max():
					score = pr.get("raid_score",700.0)
					if c.kind == "fire":
						for b: Dictionary in s.buildings:
							if b.team != team and b.kind == "farm" and b.pos.distance_to(c.pos) <= data.radius: score += 100
				elif s.difficulty == 2 and s.enemy_ink >= 35 and B.has_tag(c.kind,"guard"):
					var expected := int(s.memory.get("lane",target_lane))
					if lane == expected and ours[lane] < 400: score = 780
				elif B.has_tag(c.kind,"guard") and my_farms[lane] > 0 and my_guard[lane] == 0 and s.elapsed >= pr.get("guard_after",20.0):
					# Guard farm lanes before raiders arrive: one tower or scarecrow just in front of the farms.
					score = pr.get("guard_score",690.0)-(0.0 if c.kind == "tower" else 10.0)+my_farms[lane]*10-absf(col-2)*8
				elif c.kind == "ram":
					# The finisher marches at 22: send it behind troops already in the lane, and keep
					# 10 gold back so the next attack on us can still be answered.
					if lane == target_lane and s.ink >= data.cost+pr.get("ram_reserve",10.0) and (my_troops[lane] >= pr.get("ram_escort",250.0) or s.gates[1-team][lane] <= B.GATE_HP*0.6): score = pr.get("ram_score",720.0)
				elif c.kind == "healer":
					# A lone herbalist just dies: place her behind our own troops, within healing reach.
					for x: float in my_troop_x[lane]:
						var ahead: float = (x-c.pos.x)*forward
						if ahead >= 0 and ahead <= B.HEAL_RADIUS and my_troops[lane] >= 200: score = maxf(score,pr.get("healer_score",690.0)-ahead*0.5)
				elif wave and data.type == "unit" and c.kind != "farmer":
					# Front-most legal cell of the chosen lane; other lanes only as a weaker fallback.
					score = pr.get("wave_score",600.0)+col*4-data.cost-(0 if lane == target_lane else 60+(attack[target_lane]-attack[lane])*0.05)
				elif wave and B.has_tag(c.kind,"wave_spell"):
					for u: Dictionary in s.units:
						if u.team != team and u.hp > 0 and u.pos.distance_to(c.pos) < data.radius: score = maxf(0,score)+80
				elif c.kind == "mill" and farm_total >= pr.get("mill_min_farms",3.0): score = pr.get("mill_score",650.0)+my_farms[lane]*10
				elif c.kind == "harvest":
					var count := 0
					for b: Dictionary in s.buildings:
						if b.team == team and b.kind == "farm" and b.pos.distance_to(c.pos) <= data.radius: count += 1
					if count >= pr.get("harvest_min",2.0): score = pr.get("harvest_score",670.0)+count
			if defend < 0 and score == -INF and s.ink >= pr.get("spend_at",SPEND_AT):
				score = spend_score(c,s,team,lane,col,target_lane,foes,urgency,my_farms,s.get("owned_cells",15)-own_buildings)
			if score > best_score:
				best_score = score
				best = c.duplicate()
		if not best.is_empty(): break
	if not best.is_empty(): best["wave"] = wave and best_score < 700
	return best

# Deterministic per-lane tie-breaker that changes every 8 seconds (0..80).
static func jitter(lane: int, elapsed: float) -> float:
	var x := sin(lane*12.9898+floorf(elapsed/8.0)*78.233)*43758.5453
	return (x-floorf(x))*80.0

# Fallback value of a card when the AI has ink to burn (see SPEND_AT). All scores stay below the
# deliberate plays (>= 600), so this only decides between otherwise unwanted cards.
static func spend_score(c: Dictionary, s: Dictionary, team: int, lane: int, col: int, target_lane: int, foes: Array, urgency: Array, my_farms: Array, free_cells: int) -> float:
	var data: Dictionary = B.CARDS[c.kind]
	# Keep a few cells open, or every building card in the deck ends up stuck in hand.
	if data.type == "building" and free_cells <= 3: return -INF
	match c.kind:
		"tower": return 520.0+urgency[lane]*0.05+my_farms[lane]*10-absf(col-1)*6
		"scarecrow": return 500.0+urgency[lane]*0.04+my_farms[lane]*10-absf(col-2)*6
		"mill": return 515.0+my_farms[lane]*25-col*4 if my_farms.max() > 0 else -INF
		"farm": return 505.0-my_farms[lane]*20-col*5
		"harvest", "rain", "fire":
			var value := 0.0
			for u: Dictionary in s.units:
				if u.team != team and u.hp > 0 and u.pos.distance_to(c.pos) <= data.radius: value += 60.0
			for b: Dictionary in s.buildings:
				if b.hp <= 0 or b.pos.distance_to(c.pos) > data.radius: continue
				if c.kind == "harvest" and b.team == team and b.kind == "farm": value += 40.0
				if c.kind == "fire" and b.team != team: value += 80.0
			return 490.0+value if value > 0 else 300.0-data.cost
	# Ram and healer have their own rules above; near the gold cap they may still go, or they would
	# sit in hand forever and stop the deck rotating.
	if B.has_tag(c.kind,"hold") and s.ink < 45.0: return -INF
	if data.type == "unit": return 480.0+(30.0 if lane == target_lane else 0.0)+col*3-data.cost*0.5
	# Any other building or spell (a new card without its own rule above): use it rather than let it
	# sit in hand forever, which would stop the deck rotating.
	if data.type == "building": return 495.0+my_farms[lane]*5-col*4
	if data.type == "spell":
		var hits := 0
		for u: Dictionary in s.units:
			if u.team != team and u.hp > 0 and u.pos.distance_to(c.pos) <= data.radius: hits += 1
		return 490.0+hits*60.0 if hits > 0 else 300.0-data.cost
	return -INF

static func own_building(buildings: Array, team: int, cell: Vector2i) -> Dictionary:
	for b: Dictionary in buildings:
		if b.hp > 0 and b.team == team and b.cell == cell: return b
	return {}

static func dark_card_score(c: Dictionary, s: Dictionary, ours: Array, foes: Array, troop_x: Array) -> float:
	var lane: int = c.cell.y
	var forward := 1.0 if s.team == 0 else -1.0
	match c.kind:
		"grave":
			var activity: float = ours[lane]+foes[lane]
			var existing := 0
			for b: Dictionary in s.buildings:
				if b.hp > 0 and b.team == s.team and b.kind == "grave" and b.cell.y == lane: existing += 1
			return 660.0+minf(activity,1500)*0.08-existing*90 if activity > 0 else 510.0-existing*90
		"necromancer", "ghoul":
			var score := -INF
			for x: float in troop_x[lane]:
				var ahead: float = (x-c.pos.x)*forward
				if ahead > 0 and ahead <= B.HEAL_RADIUS: score = maxf(score,710.0-ahead*0.3)
			return score
		"reaper":
			for u: Dictionary in s.units:
				if u.hp > 0 and u.team != s.team and u.lane == lane and B.has_tag(u.kind,"big") and (u.pos.x-c.pos.x)*forward >= 0: return 740.0-absf(u.pos.x-c.pos.x)*0.1
		"raven":
			for b: Dictionary in s.buildings:
				if b.hp > 0 and b.team != s.team and b.kind == "farm" and b.cell.y == lane: return 720.0-absf(b.pos.x-c.pos.x)*0.1
		"plague":
			var count := 0
			for u: Dictionary in s.units:
				if u.hp > 0 and u.team != s.team and u.pos.distance_to(c.pos) <= B.CARDS.plague.radius: count += 1
			if count > 0: return 650.0+count*60
	return -INF
