extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const DS = preload("res://deck_store.gd")

static func run(t: SceneTree) -> void:
	for faction: String in B.FACTIONS:
		t.check(B.CARDS.keys().filter(func(k: String) -> bool: return B.card_faction(k) == faction and not B.CARDS[k].get("summon_only",false)).size() == {"":14,"normal":11,"dark":11,"magic":11}[faction],"faction card count: "+faction)
	for lord: String in B.LORDS:
		t.check(DS.pool(lord).size() == 24,"lord rotating pool: "+lord)
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
	t.check(not ally.get("cursed",false) and not far.get("cursed",false) and victim.get("cursed",false),"curse marks enemy troops including flying, only inside radius")
	m.elapsed = 999.0
	m.damage(victim,victim.hp,0,"rain")
	m.resolve_deaths()
	t.check(m.units.any(func(u: Dictionary) -> bool: return u.kind == "skeleton" and u.team == 0),"curse effect is permanent even after long elapsed time")
	m.cast_spell({"kind":"curse","team":0,"pos":far.pos})
	m.elapsed += 1
	m.cast_spell({"kind":"curse","team":0,"pos":far.pos})
	t.check(far.get("cursed",false),"recasting curse maintains cursed status")
	m.damage(far,far.hp,0,"rain")
	m.resolve_deaths()
	t.check(m.units.filter(func(u: Dictionary) -> bool: return u.kind == "skeleton").size() == 2,"recasting does not multiply death conversion")
	m = t.bare(44)
	var catapult: Dictionary = m.spawn_unit(0,2,"catapult",p)
	t.check(catapult.kind == "catapult" and B.CARDS.catapult.type == "unit" and B.CARDS.catapult.speed == 20.0,"catapult is a unit with slowest move speed")
	var near: Dictionary = m.spawn_unit(1,2,"knight",p+Vector2(B.CARDS.catapult.min_range-1,0))
	var mid: Dictionary = m.spawn_unit(1,2,"knight",p+Vector2(150,0))
	far = m.spawn_unit(1,2,"knight",p+Vector2(290,0))
	m.build_lookups()
	t.check(m.catapult_target(catapult) == far,"catapult selects farthest valid troop")
	m.update_unit(catapult,0)
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
	var other_lane: Dictionary = m.spawn_unit(1,1,"knight",p+Vector2(150,0))
	m.damage(near,near.hp,0,"rain")
	m.build_lookups()
	t.check(m.catapult_target(catapult).is_empty(),"catapult only targets its own lane and ignores other lanes")
	var foe_farm: Dictionary = m.add_building(1,Vector2i(5,2),"farm")
	foe_farm.pos = p+Vector2(150,0)
	m.build_lookups()
	t.check(m.catapult_target(catapult) == foe_farm,"catapult can target enemy buildings in its lane")
	for team: int in range(2):
		m = t.bare(45)
		var forward := 1.0 if team == 0 else -1.0
		var drummer: Dictionary = m.spawn_unit(team,2,"drummer",p)
		var troop: Dictionary = m.spawn_unit(team,1,"militia",p+Vector2(forward*L.CELL_SIZE.x,0))
		var normal: float = B.CARDS.militia.speed
		var faster: float = B.TIERS.speed[B.TIERS.speed.find(normal)-1]
		t.check(m.movement_speed(troop) == faster,"drummer on enter boosts allies across all lanes")
		t.check(m.movement_speed(drummer) == B.CARDS.drummer.speed,"drummer does not boost own move speed")
		var normal_interval: float = B.CARDS.militia.interval
		var faster_interval: float = B.TIERS.interval[B.TIERS.interval.find(normal_interval)-1]
		t.check(m.attack_interval(troop) == faster_interval,"drummer boosts attack speed of allies")
		t.check(m.attack_interval(drummer) == B.CARDS.drummer.interval,"drummer does not boost own attack speed")
		t.check(B.CARDS.drummer.range == 140.0,"drummer attack range is 140.0")
		m.elapsed = 3.1
		t.check(m.movement_speed(troop) == normal and m.attack_interval(troop) == normal_interval,"speed and attack buffs expire after 3 seconds")
		drummer.drum_cd = 0.05
		m.step(0.1)
		t.check(m.movement_speed(troop) == faster and m.attack_interval(troop) == faster_interval,"drummer periodic 10s trigger activates 3s speed and attack boost again")
		troop.march = B.tier_value("speed","S")
		t.check(m.movement_speed(troop) == B.tier_value("speed","S"),"drum caps at S speed")
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
