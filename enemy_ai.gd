extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

# Pure decision: snapshot in, legal play out. No model mutation or random globals.
# Lanes are scored separately so the AI defends whichever lane is in danger, spreads farms,
# and spreads its attacks instead of feeding every troop into one lane.
const DEFEND_REACH := 4.5 # columns from our gate at which an approaching enemy counts as a threat

static func decide(s: Dictionary) -> Dictionary:
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
	for u: Dictionary in s.units:
		if u.hp <= 0: continue
		if u.team == team:
			ours[u.lane] += u.hp
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
			if b.kind == "farm":
				my_farms[b.cell.y] += 1
				farm_total += 1
			if b.kind in ["tower","scarecrow"]: ours[b.cell.y] += b.hp
		elif b.kind == "farm": their_farms[b.cell.y] += 1
		elif b.kind in ["tower","scarecrow","mill"]: their_guard[b.cell.y] += b.hp
	# Defence: the lane whose approaching enemies most outweigh what we have there.
	var danger := -1
	var largest := 0.0
	for lane: int in range(5):
		if foe_reach[lane] > DEFEND_REACH*L.CELL_SIZE.x: continue
		var need: float = urgency[lane]*(3.0 if s.gates[team][lane] <= 0 else 1.0)-ours[lane]
		if need > largest:
			largest = need
			danger = lane
	# Attack: score every lane instead of always hitting the lowest gate.
	var attack := [0.0,0.0,0.0,0.0,0.0]
	var recent: Array = s.get("recent",[])
	for lane: int in range(5):
		var gate: float = s.gates[1-team][lane]
		attack[lane] = (B.GATE_HP-gate)*0.4+ours[lane]*0.3-foes[lane]*0.8-their_guard[lane]*0.5-recent.count(lane)*140.0+jitter(lane,s.elapsed)
		if gate <= 0 and foes[lane] < 150: attack[lane] += 600 # an open gate with nobody guarding it: walk in
	var target_lane: int = attack.find(attack.max())
	var farm_goal: int = [3,6,99][s.difficulty]
	var threshold: float = [15.0,25.0,35.0][s.difficulty]
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
			if defend >= 0:
				if lane != defend: continue
				var fx: float = foe_x[lane]
				if data.type == "spell" and c.kind in ["rain","fire"]: score = 1000-c.pos.distance_to(Vector2(fx,c.pos.y))
				elif data.type == "unit" and c.kind != "farmer":
					# Troops never turn round, so spawn between the attacker and our gate.
					if (fx-c.pos.x)*forward >= 0: score = 900-absf(fx-c.pos.x)*0.5-data.cost*3
				elif c.kind in ["tower","scarecrow"]: score = 950-absf(fx-c.pos.x)
			else:
				if c.kind == "farm" and farm_total < farm_goal:
					# Spread farms over the lanes, back row first, away from lanes under pressure.
					score = 800-my_farms[lane]*45-col*15-urgency[lane]*0.05+jitter(lane,s.elapsed)*0.2
				elif c.kind == "farmer":
					var ahead := 0
					for b: Dictionary in s.buildings:
						if b.team == team and b.kind == "farm" and b.hp > 0 and b.cell.y == lane and (b.pos.x-c.pos.x)*forward > 0 and b.boost_until <= s.elapsed: ahead += 1
					if ahead > 0: score = 740+ahead*12-col*6
				elif enemy_farm_total >= 4 and c.kind in ["fire","ox","mob"] and their_farms[lane] == their_farms.max():
					score = 700
					if c.kind == "fire":
						for b: Dictionary in s.buildings:
							if b.team != team and b.kind == "farm" and b.pos.distance_to(c.pos) <= data.radius: score += 100
				elif s.difficulty == 2 and s.enemy_ink >= 35 and c.kind in ["tower","scarecrow"]:
					var expected := int(s.memory.get("lane",target_lane))
					if lane == expected and ours[lane] < 400: score = 780
				elif c.kind == "ram" and lane == target_lane and (s.ink >= 40 or s.gates[1-team][lane] <= B.GATE_HP*0.6):
					score = 720 # the 30-ink finisher: send it once there is a gate worth breaking
				elif wave and data.type == "unit" and c.kind != "farmer":
					# Front-most legal cell of the chosen lane; other lanes only as a weaker fallback.
					score = 600+col*4-data.cost-(0 if lane == target_lane else 60+(attack[target_lane]-attack[lane])*0.05)
				elif wave and c.kind in ["rain","fire"]:
					for u: Dictionary in s.units:
						if u.team != team and u.hp > 0 and u.pos.distance_to(c.pos) < data.radius: score = maxf(0,score)+80
				elif c.kind == "mill" and farm_total >= 3: score = 650+my_farms[lane]*10
				elif c.kind == "harvest":
					var count := 0
					for b: Dictionary in s.buildings:
						if b.team == team and b.kind == "farm" and b.pos.distance_to(c.pos) <= data.radius: count += 1
					if count >= 2: score = 670+count
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
