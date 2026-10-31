extends RefCounted
const Anim = preload("res://attack_animation.gd")
const B = preload("res://balance.gd")

static func run(t: SceneTree) -> void:
	var animation := Anim.new()
	var m = t.bare(175)
	m.lord_active = [false,false]
	for kind: String in B.CARDS:
		var data: Dictionary = B.CARDS[kind]
		if data.type != "unit" or not data.has("damage"): continue
		var u: Dictionary = m.spawn_unit(0,2,kind,Vector2(650,390))
		var foe: Dictionary = m.spawn_unit(1,2,"knight",Vector2(680,390))
		animation.observe(m)
		m.attack(u,foe)
		var state: String = JSON.stringify(u)
		animation.observe(m)
		t.check(not animation.pose(u,m.elapsed).is_empty(),"attack animation triggers for "+kind)
		t.check(JSON.stringify(u) == state,"animation never modifies combat actor: "+kind)
		var first: Dictionary = animation.pose(u,m.elapsed)
		animation.observe(m)
		t.check(animation.pose(u,m.elapsed) == first,"unchanged cooldown does not restart clip: "+kind)
		t.check(animation.pose(u,m.elapsed+1).strength == 0,"attack returns to rest: "+kind)
	for lord: Dictionary in m.lords:
		animation.observe(m)
		lord.cd = B.LORD_INTERVAL
		animation.observe(m)
		t.check(not animation.pose(lord,m.elapsed).is_empty(),"lord attack animates on each team")
	var tower: Dictionary = m.add_building(0,Vector2i(3,2),"tower")
	animation.observe(m)
	m.build_lookups()
	m.update_buildings(0)
	animation.observe(m)
	t.check(not animation.pose(tower,m.elapsed).is_empty(),"tower fires with recoil")
	m.elapsed += 2
	animation.observe(m)
	t.check(animation.clips.is_empty(),"expired clips are removed in simulation time")
	animation.clear()
	t.check(animation.previous.is_empty() and animation.clips.is_empty(),"new battle resets all animation state")
	t.finished.attack_animation = true
