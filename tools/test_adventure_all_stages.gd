extends SceneTree

func _initialize() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.sound_enabled = false
	g.player_lord = "adventure"
	g.player_deck = ["militia","shieldguard","hunter","ram","rain","fire","ox","healer"]
	print("Checking all 9 adventure stages with adventure lord:")
	for stage_idx in range(g.adventure.STAGES.size()):
		g.adventure.start(g, stage_idx)
		var m = g.model
		var lord_kind: String = m.lords[0].lord
		var lord_name: String = g.B.LORDS[lord_kind].name
		print("Stage %d (%s): lord=%s (%s), hp=%d, deck size=%d" % [stage_idx+1, g.adventure.STAGES[stage_idx].name, lord_kind, lord_name, m.lords[0].hp, m.decks[0].size()])
		assert(lord_kind == "adventure", "Stage %d lord should be adventure" % stage_idx)
		assert(m.decks[0].size() == 8, "Stage %d deck size should be 8" % stage_idx)
	
	# Test casting skill with adventure lord
	var m = g.model
	m.ink[0] = 50.0
	m.skill_cd[0] = 0.0
	var units_before = m.units.size()
	var cast_ok = m.cast_skill(0)
	assert(cast_ok, "Adventure skill cast should succeed")
	var new_units = m.units.filter(func(u): return u.get("card", "") == "skill")
	print("Skill cast successful, spawned %d vanguard units" % new_units.size())
	assert(new_units.size() > 0, "Should spawn vanguard units")
	
	print("All stages and adventure lord skill: ALL PASSED!")
	quit()
