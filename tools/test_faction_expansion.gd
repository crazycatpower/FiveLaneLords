extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const DS = preload("res://deck_store.gd")

static func run(t: SceneTree) -> void:
	for faction: String in B.FACTIONS:
		t.check(B.CARDS.keys().filter(func(k: String) -> bool: return B.card_faction(k) == faction).size() == (17 if faction == "" else 10),"faction card count: "+faction)
	for lord: String in B.LORDS:
		t.check(DS.pool(lord).size() == (16 if lord == "mage" else 26),"lord rotating pool: "+lord)
	var p := L.cell_center(Vector2i(3,2))
	var m = t.bare(42)
	m.lord_active = [false,false]
	m.record_events = false
	var grave: Dictionary = m.add_building(0,Vector2i(0,2),"grave")
	var ghoul: Dictionary = m.spawn_unit(0,2,"ghoul",p+Vector2(10,0))
	ghoul.hp = 1
	var giant: Dictionary = m.spawn_unit(1,2,"corpse_giant",p)
	var original: int = giant.serial
	m.cast_spell({"kind":"curse","team":0,"pos":p})
	m.damage(giant,giant.hp,0,"militia")
	m.damage(giant,100,0,"rain")
	m.resolve_deaths()
	var sk: Array = m.units.filter(func(u: Dictionary) -> bool: return u.kind == "skeleton")
	t.check(sk.size() == B.CARDS.corpse_giant.on_death_spawn[1]+1,"cursed giant creates its four allies plus one enemy skeleton exactly once")
	t.check(sk.filter(func(u: Dictionary) -> bool: return u.team == 1).size() == 4 and sk.filter(func(u: Dictionary) -> bool: return u.team == 0).size() == 1,"curse and giant retain their respective owners")
	t.check(sk.all(func(u: Dictionary) -> bool: return u.pos == p and u.lane == 2 and not u.has("cursed_until")),"death spawns remain at original position without inheriting curse")
	t.check(grave.production == B.CARDS.grave.death_advance and ghoul.hp == 1+B.CARDS.ghoul.devour_heal,"giant death feeds economy and ghoul once")
	var serials: Array = sk.map(func(u: Dictionary) -> int: return u.serial)
	t.check(original in serials and serials.size() == m.serials_in_use.keys().filter(func(s: int) -> bool: return s in serials).size(),"spawned skeletons take unique free serials")
	m = t.bare(43)
	var ally: Dictionary = m.spawn_unit(0,2,"militia",p)
	var victim: Dictionary = m.spawn_unit(1,2,"raven",p)
	var far: Dictionary = m.spawn_unit(1,2,"militia",p+Vector2(B.CARDS.curse.radius+1,0))
	m.cast_spell({"kind":"curse","team":0,"pos":p})
	t.check(not ally.has("cursed_until") and not far.has("cursed_until") and victim.cursed_until == B.CARDS.curse.curse_duration,"curse marks enemy troops including flying, only inside radius")
	m.elapsed = B.CARDS.curse.curse_duration
	m.damage(victim,victim.hp,0,"rain")
	m.resolve_deaths()
	t.check(not m.units.any(func(u: Dictionary) -> bool: return u.kind == "skeleton"),"curse expires at exact duration")
	m.cast_spell({"kind":"curse","team":0,"pos":far.pos})
	m.elapsed += 1
	m.cast_spell({"kind":"curse","team":0,"pos":far.pos})
	t.check(far.cursed_until == m.elapsed+B.CARDS.curse.curse_duration,"recasting curse refreshes duration")
	m.damage(far,far.hp,0,"rain")
	m.resolve_deaths()
	t.check(m.units.filter(func(u: Dictionary) -> bool: return u.kind == "skeleton").size() == 1,"recasting does not multiply death conversion")
	m = t.bare(44)
	var catapult: Dictionary = m.add_building(0,Vector2i(3,2),"catapult")
	var near: Dictionary = m.spawn_unit(1,2,"knight",p+Vector2(B.CARDS.catapult.min_range-1,0))
	var mid: Dictionary = m.spawn_unit(1,2,"knight",p+Vector2(150,0))
	far = m.spawn_unit(1,2,"knight",p+Vector2(290,0))
	m.build_lookups()
	t.check(m.catapult_target(catapult) == far,"catapult selects farthest valid troop")
	m.update_buildings(0)
	t.check(m.projectiles.size() == 1 and far.hp == far.max_hp,"catapult damage waits for impact")
	var impact: Vector2 = far.pos
	far.pos += Vector2(200,0)
	var splash: Dictionary = m.spawn_unit(1,2,"knight",impact+Vector2(B.CARDS.catapult.radius,0))
	ally = m.spawn_unit(0,2,"knight",impact)
	m.update_projectiles(B.CARDS.catapult.flight_time)
	t.check(splash.hp == splash.max_hp-B.CARDS.catapult.area_damage and far.hp == far.max_hp and ally.hp == ally.max_hp,"catapult hits enemies at fixed impact point including radius boundary, not moved target or allies")
	t.check(m.stats[0].damage.catapult == B.CARDS.catapult.area_damage,"catapult splash records actual damage")
	m.damage(mid,mid.hp,0,"rain")
	m.damage(splash,splash.hp,0,"rain")
	m.build_lookups()
	t.check(m.catapult_target(catapult).is_empty(),"catapult cannot hit inside minimum range or beyond maximum")
	near.pos = p+Vector2(B.CARDS.catapult.min_range,0)
	t.check(m.catapult_target(catapult) == near,"catapult includes exact minimum range")
	for team: int in range(2):
		m = t.bare(45)
		var forward := 1.0 if team == 0 else -1.0
		var drummer: Dictionary = m.spawn_unit(team,2,"drummer",p)
		var troop: Dictionary = m.spawn_unit(team,2,"militia",p+Vector2(forward*L.CELL_SIZE.x,0))
		var normal: float = B.CARDS.militia.speed
		var faster: float = B.TIERS.speed[B.TIERS.speed.find(normal)-1]
		t.check(m.movement_speed(troop) == faster and m.movement_speed(drummer) == B.CARDS.drummer.speed,"drum buffs ahead ally but not itself on team "+str(team))
		var second: Dictionary = m.spawn_unit(team,2,"drummer",p-Vector2(forward*10,0))
		t.check(m.movement_speed(troop) == faster,"two drums do not stack")
		troop.pos.x = p.x+forward*B.CARDS.drummer.inspire_cells*L.CELL_SIZE.x
		t.check(m.movement_speed(troop) == faster,"drum includes exact two-cell boundary")
		troop.pos.x += forward
		t.check(m.movement_speed(troop) == normal,"drum stops immediately beyond two cells")
		troop.pos = p-Vector2(forward*20,0)
		t.check(m.movement_speed(troop) == normal,"drum never buffs troops behind it")
		troop.pos = p+Vector2(forward*100,0)
		troop.lane = 1
		t.check(m.movement_speed(troop) == normal,"drum does not cross lanes")
		troop.lane = 2
		troop.march = B.TIERS.speed[0]
		t.check(m.movement_speed(troop) == B.TIERS.speed[0],"drum caps at S speed")
		troop.erase("march")
		m.damage(drummer,drummer.hp,1-team,"rain")
		m.damage(second,second.hp,1-team,"rain")
		t.check(m.movement_speed(troop) == normal,"dead drummers give no aura")
	m = t.bare(46)
	var shield: Dictionary = m.spawn_unit(1,2,"shieldguard",p)
	for hit: float in [6.0,10.0,45.0]:
		var before: float = shield.hp
		m.damage(shield,hit,0,"militia")
		t.check(shield.hp == before-maxf(1,hit-B.CARDS.shieldguard.armor),"shield reduces each hit with one-damage floor: "+str(hit))
	var before: float = shield.hp
	m.damage(shield,0,0,"militia")
	t.check(shield.hp == before,"zero damage does not become one damage")
	shield.hp = 2
	var dealt: float = m.stats[0].damage.militia
	m.damage(shield,100,0,"militia")
	t.check(m.stats[0].damage.militia == dealt+2,"armor damage statistics cap at remaining health")
	t.finished.faction_expansion = true
