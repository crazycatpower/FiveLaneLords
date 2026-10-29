extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
# Pure decision: snapshot in, legal play out. No model mutation or random globals.
static func decide(s: Dictionary) -> Dictionary:
	var team: int = s.team
	var forward := 1.0 if team == 0 else -1.0
	var threat := [0.0,0.0,0.0,0.0,0.0]
	var defense := [0.0,0.0,0.0,0.0,0.0]
	var enemy_x := [0.0,0.0,0.0,0.0,0.0]
	var fields := [0,0,0,0,0]
	var farm_total := 0
	var enemy_farms := 0
	for u: Dictionary in s.units:
		if u.hp <= 0: continue
		if u.team == team: defense[u.lane] += u.hp
		elif (u.pos.x < L.GRID_ORIGIN.x+3*L.CELL_SIZE.x if team == 0 else u.pos.x >= L.GRID_ORIGIN.x+6*L.CELL_SIZE.x):
			threat[u.lane] += u.hp
			enemy_x[u.lane] = u.pos.x
	for b: Dictionary in s.buildings:
		if b.hp <= 0: continue
		if b.team == team:
			if b.kind == "farm": farm_total += 1
			if b.kind in ["tower","scarecrow"]: defense[b.cell.y] += b.hp
		elif b.kind == "farm":
			fields[b.cell.y] += 1
			enemy_farms += 1
	var danger := -1
	var largest := 0.0
	for lane: int in range(5):
		if threat[lane]-defense[lane] > largest:
			largest = threat[lane]-defense[lane]
			danger = lane
	var best: Dictionary = {}
	var best_score := -INF
	var farm_goal: int = [3,6,15][s.difficulty]
	var threshold: float = [15.0,25.0,35.0][s.difficulty]
	var wave: bool = s.elapsed < s.wave_until or s.ink >= threshold
	var weakest := 0
	var weakest_score := INF
	for lane: int in range(5):
		var score: float = s.gates[1-team][lane]
		for b: Dictionary in s.buildings:
			if b.team != team and b.cell.y == lane and b.kind != "farm": score += b.hp
		if score < weakest_score:
			weakest_score = score
			weakest = lane
	for c: Dictionary in s.candidates:
		var data: Dictionary = B.CARDS[c.kind]
		var score := -INF
		var lane: int = c.cell.y
		if danger >= 0:
			if lane != danger: continue
			if data.type == "spell" and c.kind in ["rain","fire"]: score = 1000-c.pos.distance_to(Vector2(enemy_x[lane],c.pos.y))
			elif data.type == "unit":
				# Spawn ahead of the incoming attacker, on its path toward our gate.
				if (enemy_x[lane]-c.pos.x)*forward >= 0: score = 900-absf(enemy_x[lane]-c.pos.x)
			elif c.kind in ["tower","scarecrow"]: score = 950-absf(enemy_x[lane]-c.pos.x)
		else:
			if c.kind == "farm" and farm_total < farm_goal:
				var col: int = c.cell.x if team == 0 else 8-c.cell.x
				score = 800-absf(col-1)*20-lane*2
			elif c.kind == "farmer":
				for b: Dictionary in s.buildings:
					if b.team == team and b.kind == "farm" and b.cell.y == lane and (b.pos.x-c.pos.x)*forward > 0:
						score = maxf(score,750-absf(b.pos.x-c.pos.x)*0.1)
			elif enemy_farms >= 4 and c.kind in ["fire","ox","mob"] and fields[lane] == fields.max():
				score = 700
				if c.kind == "fire":
					for b: Dictionary in s.buildings:
						if b.team != team and b.kind == "farm" and b.pos.distance_to(c.pos) <= data.radius: score += 100
			elif s.difficulty == 2 and s.enemy_ink >= 35 and c.kind in ["tower","scarecrow"]:
				var expected := int(s.memory.get("lane",weakest))
				if lane == expected and defense[lane] < 400: score = 780
			elif wave and data.type == "unit": score = 600-(0 if lane == weakest else 100)-data.cost
			elif wave and c.kind in ["rain","fire"]:
				for u: Dictionary in s.units:
					if u.team != team and u.pos.distance_to(c.pos) < data.radius: score = maxf(0,score)+80
			elif c.kind == "mill" and farm_total >= 3: score = 650
			elif c.kind == "harvest":
				var count := 0
				for b: Dictionary in s.buildings:
					if b.team == team and b.kind == "farm" and b.pos.distance_to(c.pos) <= data.radius: count += 1
				if count >= 2: score = 670+count
		if score > best_score:
			best_score = score
			best = c.duplicate()
	if not best.is_empty(): best["wave"] = wave and best_score < 700
	return best
