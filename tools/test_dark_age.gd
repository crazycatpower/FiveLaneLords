extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")

static func fixture(t: SceneTree) -> Battle:
	var m: Battle = t.bare(81,[],[],"underworld","iron")
	m.lord_active = [false,false]
	return m

static func run(t: SceneTree) -> void:
	var p := L.cell_center(Vector2i(3,2))
	var m := fixture(t)
	var a := m.add_building(0,Vector2i(0,2),"grave")
	var b := m.add_building(1,Vector2i(8,2),"grave")
	var elsewhere := m.add_building(0,Vector2i(0,1),"grave")
	a.production = B.CARDS.grave.period-B.CARDS.grave.death_advance+1
	b.production = a.production
	var income: float = m.stats[0].produced
	var victim := m.spawn_unit(1,2,"militia",p)
	m.record_events = false
	m.damage(victim,victim.hp,0,"rain")
	m.damage(victim,999,0,"rain")
	m.resolve_deaths()
	t.check(m.stats[0].produced == income+B.CARDS.grave.income and m.stats[1].produced == B.CARDS.grave.income,"one death accelerates both teams' same-lane graves exactly once even without visuals")
	t.check(a.production == 0 and b.production == 0 and elsewhere.production == 0,"grave payout discards overshoot; other lanes unaffected")
	a.production = B.CARDS.grave.period-0.1
	m.step(0.1)
	t.check(a.production == 0,"grave also pays on its natural timer")
	m = fixture(t)
	var sk := m.spawn_unit(0,2,"skeleton",p)
	var old_serial: int = sk.serial
	m.damage(sk,sk.hp,1,"rain")
	var replacement := m.spawn_unit(0,4,"militia",L.cell_center(Vector2i(1,4)))
	t.check(replacement.serial == old_serial and sk.hp <= 0,"skeleton releases serial immediately on first death")
	t.tick(m,3.5)
	t.check(sk.hp <= 0 and not sk in m.units and not sk.has("revive_at"),"skeletons stay dead (no revival since 2026-10-30)")
	t.check(m.serials_in_use.has(replacement.serial),"dead cleanup cannot release a serial already reused by another unit")
	m = fixture(t)
	var ghoul := m.spawn_unit(0,2,"ghoul",p)
	ghoul.hp = 1
	for i: int in range(5):
		victim = m.spawn_unit(i%2,2,"farmer",p+Vector2(5,0))
		m.damage(victim,victim.hp,1-i%2,"rain")
	m.resolve_deaths()
	t.check(ghoul.hp == ghoul.max_hp and ghoul.damage == B.tier_value("damage",B.CARDS.ghoul.max_damage_tier),"ghoul consumes either team, heals and caps attack at A")
	var hp: float = ghoul.hp
	victim = m.spawn_unit(1,2,"farmer",p+Vector2(B.CARDS.ghoul.radius+1,0))
	ghoul.hp -= 10
	m.damage(victim,victim.hp,0,"rain")
	m.resolve_deaths()
	t.check(ghoul.hp == hp-10,"ghoul cannot consume outside radius")
	for lane: int in [0,2,4]:
		m = fixture(t)
		var necro := m.spawn_unit(0,lane,"necromancer",L.cell_center(Vector2i(2,lane)))
		necro.march = 0.0
		var per_wave: int = (3 if lane == 2 else 2)*B.CARDS.necromancer.summon_per_lane
		t.tick(m,0.1)
		var children: Array = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "skeleton")
		t.check(children.size() == per_wave and children.all(func(u: Dictionary) -> bool: return absi(u.lane-lane) <= 1 and m.cell_at(u.pos).x == 2),"necromancer summons at once, in the correct lanes and column "+str(lane))
		t.tick(m,B.CARDS.necromancer.summon_interval)
		t.check(m.units.filter(func(u: Dictionary) -> bool: return u.kind == "skeleton").size() == 2*per_wave,"necromancer summons again every interval "+str(lane))
		var count: int = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "skeleton").size()
		m.damage(necro,necro.hp,1,"rain")
		t.tick(m,B.CARDS.necromancer.summon_interval+0.02)
		t.check(m.units.filter(func(u: Dictionary) -> bool: return u.kind == "skeleton").size() <= count,"dead necromancer stops summoning")
	m = fixture(t)
	var reaper := m.spawn_unit(0,2,"reaper",p)
	var front := m.spawn_unit(1,2,"militia",p+Vector2(60,0))
	var up := m.spawn_unit(1,1,"militia",Vector2(front.pos.x,L.cell_center(Vector2i(0,1)).y))
	var down := m.spawn_unit(1,3,"militia",Vector2(front.pos.x+20,L.cell_center(Vector2i(0,3)).y))
	var two_away := m.spawn_unit(1,4,"militia",Vector2(front.pos.x,L.cell_center(Vector2i(0,4)).y))
	var next_column := m.spawn_unit(1,1,"militia",Vector2(front.pos.x+L.CELL_SIZE.x,L.cell_center(Vector2i(0,1)).y))
	m.build_lookups()
	m.attack(reaper,front)
	t.check(front.hp < front.max_hp and up.hp < up.max_hp and down.hp < down.max_hp,"the reaper's slash hits its target's column in its lane and both neighbours")
	t.check(two_away.hp == two_away.max_hp and next_column.hp == next_column.max_hp,"the slash spares lanes two away and the next column")
	m = fixture(t)
	var bird := m.spawn_unit(1,2,"raven",p+Vector2(10,0))
	var melee := m.spawn_unit(0,2,"militia",p)
	m.step(0.01)
	t.check(bird.hp == bird.max_hp and melee.hp == melee.max_hp and melee.pos.x > p.x,"melee and raven pass each other without attacking")
	t.check(m.nearest(p,0,B.CARDS.hunter.range,[bird]) == bird,"ranged target selection includes flying enemies")
	var hunter := m.spawn_unit(0,2,"hunter",p)
	m.attack(hunter,bird)
	m.update_projectiles(B.ARROW_TIME)
	t.check(bird.hp == bird.max_hp-B.CARDS.hunter.damage,"hunter projectile damages raven")
	m.cast_spell({"kind":"rain","team":0,"pos":bird.pos})
	t.check(bird.hp <= 0,"arrow rain damages flying units")
	m = fixture(t)
	bird = m.spawn_unit(0,2,"raven",p)
	var wall := m.add_building(1,Vector2i(3,2),"bonewall")
	var farm := m.add_building(1,Vector2i(4,2),"farm")
	m.step(0.01)
	t.check(wall.hp == wall.max_hp and bird.pos.x > p.x,"raven bypasses nearby wall for a farm ahead")
	bird.pos = farm.pos
	bird.cd = 0
	m.step(0.01)
	t.check(farm.hp == farm.max_hp-B.CARDS.raven.damage,"raven attacks the preferred farm")
	m = fixture(t)
	victim = m.spawn_unit(1,2,"farmer",p)
	victim.hp = B.CARDS.plague.tick_damage
	m.cast_spell({"kind":"plague","team":0,"pos":p})
	m.update_zones(B.CARDS.plague.tick_interval-0.01)
	t.check(victim.hp > 0,"plague does not damage before first full second")
	m.update_zones(0.01)
	m.resolve_deaths()
	t.check(victim.hp <= 0 and m.zones.size() == 2 and m.zones[1].radius == B.CARDS.plague.spread_radius,"poison kill creates exactly one smaller cloud")
	var ally := m.spawn_unit(0,2,"knight",p)
	var survivor := m.spawn_unit(1,2,"knight",p)
	m.zones.clear()
	m.add_zone(p,0,B.CARDS.plague.radius,B.CARDS.plague.duration)
	m.update_zones(B.CARDS.plague.duration)
	t.check(survivor.hp == survivor.max_hp-B.CARDS.plague.tick_damage*B.CARDS.plague.duration/B.CARDS.plague.tick_interval and ally.hp == ally.max_hp and m.zones.is_empty(),"plague ticks exactly six times, spares allies and expires")
	m = fixture(t)
	wall = m.add_building(0,Vector2i(3,2),"bonewall")
	victim = m.spawn_unit(1,2,"knight",p)
	ally = m.spawn_unit(0,2,"knight",p)
	var far := m.spawn_unit(1,2,"knight",p+Vector2(B.CARDS.bonewall.radius+1,0))
	m.damage(wall,wall.hp,1,"fire")
	m.resolve_deaths()
	t.check(victim.hp == victim.max_hp-B.CARDS.bonewall.explosion_damage and ally.hp == ally.max_hp and far.hp == far.max_hp,"bonewall explosion damages only enemies inside radius")
	t.check(m.stats[0].damage.bonewall == B.CARDS.bonewall.explosion_damage,"bonewall explosion attributes damage correctly")
	m = fixture(t)
	t.check(m.skill_cd[0] == B.SKILL_OPENING_COOLDOWN,"underworld lord starts with opening skill cooldown")
	m.skill_cd[0] = 0.0
	m.ink[0] = B.skill_cost("underworld")
	t.check(m.skill_error(0) == "沒有墓碑" and not m.cast_skill(0),"underworld skill requires a living grave")
	m.add_building(0,Vector2i(1,0),"grave")
	t.check(not m.AI.skill_plan(m.skill_state(0)).cast,"underworld AI waits for two graves")
	m.add_building(0,Vector2i(1,4),"grave")
	t.check(m.AI.skill_plan(m.skill_state(0)).cast and m.cast_skill(0),"underworld AI uses its thirty-gold cost")
	t.check(m.ink[0] == 0 and m.units.size() == 2*B.LORDS.underworld.summon_count and m.skill_cd[0] == B.SKILL_COOLDOWN,"underworld skill spends correct gold and summons four per grave")
	t.check(m.units.all(func(u: Dictionary) -> bool: return u.kind == "skeleton" and u.lane in [0,4]),"underworld summons on each grave's lane")
	for kind: String in B.CARDS:
		var data: Dictionary = B.CARDS[kind]
		if data.get("series","") != "dark": continue
		t.check(not B.card_description(kind).is_empty(),"dark card description generated "+kind)
		for stat: String in ["hp","damage","interval","range","speed","radius"]:
			if data.has(stat): t.check(not B.tier(stat,data[stat]).is_empty(),"dark card stat is tiered "+kind+"."+stat)
	t.check(not B.tier("radius",B.CARDS.plague.spread_radius).is_empty(),"secondary poison radius is tiered")
	var u_ally := m.spawn_unit(0, 2, "militia", L.cell_center(Vector2i(3, 2)))
	var u_foe := m.spawn_unit(1, 2, "militia", L.cell_center(Vector2i(5, 2)))
	var snap := m.snapshot(0)
	var cand_active := {"slot": Battle.FARM_SLOT, "kind": "grave", "cell": Vector2i(1, 2), "pos": L.cell_center(Vector2i(1, 2))}
	var cand_quiet := {"slot": Battle.FARM_SLOT, "kind": "grave", "cell": Vector2i(1, 0), "pos": L.cell_center(Vector2i(1, 0))}
	var ours := [0.0, 0.0, u_ally.hp, 0.0, 0.0]
	var foes := [0.0, 0.0, u_foe.hp, 0.0, 0.0]
	var troop_x: Array = [[], [], [u_ally.pos.x], [], []]
	var s_active: float = m.AI.dark_card_score(cand_active, snap, ours, foes, troop_x)
	var s_quiet: float = m.AI.dark_card_score(cand_quiet, snap, ours, foes, troop_x)
	t.check(s_active > s_quiet, "grave scores higher in active combat lane than quiet lane")
	m.add_building(0, Vector2i(0, 2), "grave")
	snap = m.snapshot(0)
	var s_stacked: float = m.AI.dark_card_score(cand_active, snap, ours, foes, troop_x)
	t.check(s_stacked > s_active, "stacking grave on same active lane grants synergy bonus")
	t.finished.dark_age = true
