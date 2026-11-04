extends SceneTree

func _initialize() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.sound_enabled = false
	
	# Verify all 6 adventure attack frames are loaded
	assert(g.adventure_attack_frames.size() == 6, "Must have 6 attack frames")
	for i in range(6):
		assert(g.adventure_attack_frames[i] != null, "Frame %d must not be null" % i)
		assert(g.adventure_attack_frames[i].get_size() == Vector2(640, 576), "Frame %d size must be 640x576" % i)
	
	# Verify actor_rect
	var rect: Rect2 = g.actor_rect("lord_adventure")
	print("lord_adventure actor_rect: ", rect)
	assert(rect.size.x > 100 and rect.size.y > 90, "lord_adventure rect must be sized appropriately")
	
	# Test attack animation frames across progress
	var Anim = preload("res://attack_animation.gd")
	assert(Anim.style("lord_adventure") == "cleave", "lord_adventure style must be cleave")
	
	var test_frames = []
	for p in [0.05, 0.20, 0.45, 0.70, 0.90, 0.99]:
		var s = Anim.sample("cleave", p)
		test_frames.append(s.frame)
	print("Sampled cleave frames across progress: ", test_frames)
	assert(test_frames == [1, 2, 3, 4, 5, 0], "Cleave animation must sequence frames 1 -> 2 -> 3 -> 4 -> 5 -> 0")
	
	# Test live model attack trigger
	g.adventure.start(g, 1)
	var m = g.model
	m.lords[0].pos = Vector2(309, 394)
	
	# Spawn enemy right in front of the lord
	var foe = m.spawn_unit(1, 2, "militia", Vector2(350, 394))
	m.build_lookups()
	g.attack_animation.observe(m)
	
	# Step model so lord attacks foe
	m.step(0.02)
	assert(m.lords[0].cd > 0.0, "Lord should have attacked foe and put cd on cooldown")
	g.attack_animation.observe(m)
	
	var lord_id = Anim.key(m.lords[0])
	assert(g.attack_animation.clips.has(lord_id), "Lord should have an active attack clip")
	var clip = g.attack_animation.clips[lord_id]
	print("Active clip: ", clip)
	assert(clip.style == "cleave", "Active clip style must be cleave")
	
	# Check pose
	var pose = g.attack_animation.pose(m.lords[0], m.elapsed)
	print("Pose at elapsed: ", pose)
	assert(pose.has("frame"), "Pose must have frame")
	assert(pose.frame >= 1 and pose.frame <= 5, "Pose frame must be an active swing frame")
	
	# Test stage 1-1 lord arrival combat
	g.adventure.start(g, 0)
	var m0 = g.model
	# Advance opening past arrival
	g.adventure.opening.active = false
	g.adventure.opening.arrived = true
	m0.lord_active[0] = true
	m0.lords[0].hp = m0.lords[0].max_hp
	m0.lords[0].pos = Vector2(309, 394)
	var bnd = m0.spawn_unit(1, 2, "bandit", Vector2(340, 394))
	bnd.stealthed = false # broke stealth after burning farm
	m0.build_lookups()
	g.attack_animation.observe(m0)
	m0.step(0.02)
	g.attack_animation.observe(m0)
	var pose0 = g.attack_animation.pose(m0.lords[0], m0.elapsed)
	assert(pose0.has("frame") and pose0.frame >= 1, "Lord in 1-1 must play cleave frame animation")
	print("Stage 1-1 lord combat cleave frame: ", pose0.frame)
	
	print("Adventure cleave attack animation: ALL PASS!")
	quit()
