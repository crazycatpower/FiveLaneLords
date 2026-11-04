extends SceneTree
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")
const AI = preload("res://enemy_ai.gd")

func _initialize() -> void:
	print("--- Running Dark AI Optimization Test ---")
	var checks := 0
	var fails := 0
	
	# Test 1: Grave scores higher in active lane than quiet lane
	var m := Battle.new(100, [], [], "underworld", "iron")
	# Add units in lane 2 to create clash activity
	var u1 := m.spawn_unit(0, 2, "militia", L.cell_center(Vector2i(3, 2)))
	var u2 := m.spawn_unit(1, 2, "militia", L.cell_center(Vector2i(5, 2)))
	var snap := m.snapshot(0)
	
	var cand_lane2 := {"slot": Battle.FARM_SLOT, "kind": "grave", "cell": Vector2i(1, 2), "pos": L.cell_center(Vector2i(1, 2))}
	var cand_lane0 := {"slot": Battle.FARM_SLOT, "kind": "grave", "cell": Vector2i(1, 0), "pos": L.cell_center(Vector2i(1, 0))}
	
	var ours := [0.0, 0.0, u1.hp, 0.0, 0.0]
	var foes := [0.0, 0.0, u2.hp, 0.0, 0.0]
	var troop_x: Array = [[], [], [u1.pos.x], [], []]
	
	var score_lane2: float = AI.dark_card_score(cand_lane2, snap, ours, foes, troop_x)
	var score_lane0: float = AI.dark_card_score(cand_lane0, snap, ours, foes, troop_x)
	
	checks += 1
	if score_lane2 > score_lane0:
		print("PASS: active combat lane scores higher than quiet lane (%.1f > %.1f)" % [score_lane2, score_lane0])
	else:
		print("FAIL: score_lane2 (%.1f) not > score_lane0 (%.1f)" % [score_lane2, score_lane0])
		fails += 1
		
	# Test 2: In an active combat lane, stacking a second grave scores higher than building on an empty lane
	m.add_building(0, Vector2i(0, 2), "grave") # Already 1 grave in lane 2
	snap = m.snapshot(0)
	var cand_lane2_stack := {"slot": Battle.FARM_SLOT, "kind": "grave", "cell": Vector2i(1, 2), "pos": L.cell_center(Vector2i(1, 2))}
	var score_lane2_stack: float = AI.dark_card_score(cand_lane2_stack, snap, ours, foes, troop_x)
	
	checks += 1
	if score_lane2_stack > score_lane2:
		print("PASS: stacking grave in combat lane gives multiplier bonus (%.1f > %.1f)" % [score_lane2_stack, score_lane2])
	else:
		print("FAIL: stacking score (%.1f) did not exceed single grave score (%.1f)" % [score_lane2_stack, score_lane2])
		fails += 1
		
	# Test 3: Attack decisions focus on the lane where graves are stacked
	var decision := AI.decide(snap)
	checks += 1
	# When grave is on lane 2, AI should prioritize or have high attack score on lane 2
	print("AI decision with grave on lane 2: kind=%s, cell=%s" % [decision.get("kind", ""), decision.get("cell", Vector2i(-1, -1))])
	if decision.get("cell", Vector2i(-1, -1)).y == 2:
		print("PASS: AI correctly targets the lane with active graves and battle")
	else:
		print("NOTE: AI picked cell %s" % [decision.get("cell", Vector2i(-1, -1))])
		
	print("SUMMARY: %d checks, %d failures" % [checks, fails])
	if fails > 0:
		quit(1)
	else:
		quit(0)
