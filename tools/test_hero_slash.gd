extends SceneTree
const M = preload("res://battle.gd")
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const AI = preload("res://enemy_ai.gd")
func _initialize() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	assert(B.validate().is_empty())
	assert(B.skill_cost("adventure") == 10 and B.tier("area_damage",B.LORDS.adventure.skill_damage) == "S")
	for team in [0,1]:
		var m = M.new(13,[],[],"adventure","adventure")
		m.units.clear()
		m.buildings.clear()
		var origin := L.cell_center(Vector2i(4,2))
		m.lords[team].pos = origin
		m.lords[1-team].pos = origin+Vector2(999,999)
		var direction := 1.0 if team == 0 else -1.0
		var length: float = B.LORDS.adventure.skill_cells*L.CELL_SIZE.x
		var inside: Dictionary = m.spawn_unit(1-team,2,"knight",origin+Vector2(direction*length,0))
		var outside: Dictionary = m.spawn_unit(1-team,2,"knight",origin+Vector2(direction*(length+1),0))
		var behind: Dictionary = m.spawn_unit(1-team,2,"knight",origin-Vector2(direction,0))
		var neighbor: Dictionary = m.spawn_unit(1-team,3,"knight",origin+Vector2(direction*100,L.CELL_SIZE.y))
		var ally: Dictionary = m.spawn_unit(team,2,"knight",origin+Vector2(direction*100,0))
		var wall: Dictionary = m.add_building(1-team,Vector2i(5 if team == 0 else 3,2),"barricade")
		assert(m.skill_cd[team] == B.SKILL_OPENING_COOLDOWN)
		m.skill_cd[team] = 0.0
		m.ink[team] = 4
		assert(AI.skill_plan(m.skill_state(team)).save == false)
		m.ink[team] = 9
		assert(not m.cast_skill(team))
		m.ink[team] = 10
		assert(AI.skill_plan(m.skill_state(team)).cast)
		var count: int = m.units.size()
		assert(m.cast_skill(team) and m.ink[team] == 0)
		assert(inside.hp == inside.max_hp-600 and wall.hp == wall.max_hp-600)
		for actor in [outside,behind,neighbor,ally]: assert(actor.hp == actor.max_hp)
		assert(m.units.size() == count,"Skill no longer summons troops")
		assert(m.skill_cd[team] == B.SKILL_COOLDOWN and not m.cast_skill(team))
		assert(m.events.any(func(e): return e.kind == "hero_slash" and e.length == length and e.team == team))
	print("PASS: 10 gold, S-tier 600 damage, three-cell boundary, both directions, building damage, friendly/behind/adjacent exclusion, no summons, cooldown and AI")
	quit()
