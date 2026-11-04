extends RefCounted
const START_INK := 25.0 # producer 2026-10-29 (was 10)
const MAX_INK := 50.0
const BASE_INTERVAL := 2.0 # +1 ink every 2 s = 0.5 ink per second
const FARM_INTERVAL := 20.0
const FARM_START := 3.0
const FARM_DROP := 4.0 # a farm gives +4 every 20 s (every 10 s while cultivated)
const FARMER_HEAL := 100.0 # each cultivation also repairs the farm by this much
const START_FARMS := [Vector2i(0,1),Vector2i(0,3)] # both sides begin with these two farms (lanes II and IV, back column; mirrored for blue)
const CULTIVATE_TIME := 1.5
const BOOST_TIME := 15.0
const PLACE_JITTER := 16.0 # units are drawn up to this many px above/below their lane line (looks only)
const MELEE_RANGE := 47.0
const GATE_HP := 400.0
# After a gate falls, every attacker must stop at the gate and clear the rubble this long before
# walking in, which gives the lord time to come back and defend.
const RUBBLE_TIME := 3.0
# No crowns, castle HP or time limit: the first enemy soldier to walk through a broken gate wins.
# Ink speeds up over time so matches still end.
const RAMP_1 := 180.0 # ink x1.5 from 3:00
const RAMP_2 := 300.0 # ink x2 from 5:00
# Gates never shoot back (producer decision 2026-10-29): defence is the lord, troops, buildings and spells.
const ARROW_TIME := 0.35
const SPELL_DELAY := 0.4
const LORD_RANGE := 100.0
# Lords stay behind the farms (producer 2026-10-29): they only move within this many px of the
# grid's back edge (the back farm column is centred 59 px in), so raids on farms are not free to stop.
const LORD_ZONE_DEPTH := 40.0
const LORD_INTERVAL := 0.6
const LORD_REGEN_DELAY := 6.0
const LORD_REGEN := 3.0 # producer: regeneration cut hard (was 25/s after 3 s)
const LORD_RETREAT_BELOW := 0.25 # retreat to the castle under this share of HP...
const LORD_RETURN_ABOVE := 0.45 # ...and come back above this one (unless a gate is being stormed)
const LORD_RESPAWN := 12.0
const AI_TICK := 0.5
const LORD_HYSTERESIS := 1.5
# Costs run 1..30 (producer decision 2026-10-29). "role" is the card's job, shown on the card face.
# Buildings never expire on their own (producer decision 2026-10-29); they stay until destroyed.
# Speeds differ too: mob 60 (rush) ... knight and ram 22; a legion marches at its slowest member.
# Troop counts vary widely on purpose (1 to 12) so headcount itself sets a card apart.
# Most troop cards are bulk buys (producer 2026-10-29): costlier, but more troops, so each troop is a bit cheaper.
# Unit cards may carry "members" ([kind, count, px behind the front]) to field a mixed legion,
# and "spread": true to deploy "count" troops in each of three adjacent lanes.
# "cooldown": seconds a card must wait after it enters the hand before it can be played (0..30).
const CARDS := {
	"dark_wizard":{"name":"黑暗巫師","role":"高傷·噬魂","faction":"dark","series":"dark","type":"unit","projectile":true,"soul_bargain":true,"cost":18,"cooldown":14.0,"count":1,"hp":210.0,"damage":110.0,"interval":1.9,"range":230.0,"speed":36.0},
	"summon_trap":{"name":"召喚法陣","role":"陷阱·召獸","faction":"magic","series":"magic","type":"building","ai":["defend_building"],"cost":6,"cooldown":12.0,"hp":80.0,"expires":-1.0,"trap":"summon","charges":3,"trigger_radius":26.0,"radius":52.0,"summon_kind":"chimera","summon_count":1},
	"chimera":{"name":"嵌合獸","role":"召喚物·近戰","faction":"magic","series":"magic","type":"unit","summon_only":true,"cost":1,"cooldown":0.0,"count":1,"hp":210.0,"damage":26.0,"interval":1.1,"range":60.0,"speed":65.0},
	"blink_blade":{"name":"閃現劍士","role":"突進·穿陣","type":"unit","faction":"magic","series":"magic","cost":13,"cooldown":8.0,"count":3,"hp":210.0,"damage":42.0,"interval":0.85,"range":47.0,"speed":65.0,"blink_step":0.25},
	"arcane_golem":{"name":"奧術魔像","role":"重裝·共鳴","type":"unit","faction":"magic","series":"magic","cost":17,"cooldown":15.0,"count":1,"hp":1500.0,"damage":42.0,"interval":1.4,"range":47.0,"speed":27.0,"resonance":0.1,"resonance_max":0.3,"explosion_damage":140.0,"radius":100.0,"ai":["hold"]},
	"arcane_archer":{"name":"奧術射手","role":"遠程·貫穿","type":"unit","faction":"magic","series":"magic","cost":7,"cooldown":6.0,"count":4,"hp":80.0,"damage":10.0,"interval":1.1,"range":180.0,"speed":36.0,"projectile":true,"pierce":true,"pierce_range_multiplier":2.0},
	"chronomancer":{"name":"時滯術士","role":"控場·暈眩","type":"unit","faction":"magic","series":"magic","cost":8,"cooldown":8.0,"count":2,"hp":130.0,"damage":20.0,"interval":1.1,"range":140.0,"speed":36.0,"area_damage":20.0,"radius":52.0,"stun_on_hit":0.5,"ai":["no_defend"]},
	"phase_rider":{"name":"相位騎兵","role":"穿陣·破門","type":"unit","faction":"magic","series":"magic","cost":13,"cooldown":10.0,"count":3,"hp":210.0,"damage":42.0,"interval":1.1,"range":47.0,"speed":90.0,"phase":true,"ai":["raid"]},
	"artificer":{"name":"工匠","role":"維修·支援","faction":"magic","type":"unit","ai":["no_defend"],"cost":3,"cooldown":8.0,"count":1,"hp":210.0,"damage":6.0,"interval":1.9,"range":47.0,"speed":50.0,"repair_range":100.0,"repair_amount":50.0,"repair_interval":1.7},
	"crystal":{"name":"水晶","role":"耗能·經濟","faction":"magic","type":"building","cost":7,"cooldown":10.0,"hp":350.0,"expires":-1.0,"period":10.0,"max_period":20.0,"income":2.0,"decay_fraction":0.05},
	"teleport_trap":{"name":"傳送法陣","role":"陷阱·轉移","faction":"magic","type":"building","ai":["defend_building"],"cost":1,"cooldown":12.0,"hp":80.0,"expires":-1.0,"trap":"teleport","trigger_radius":26.0,"radius":100.0,"charges":3,"stun_duration":10.0,"slow_duration":10.0},
	"blast_trap":{"name":"爆炸法陣","role":"陷阱·爆破","faction":"magic","type":"building","ai":["defend_building"],"cost":4,"cooldown":12.0,"hp":80.0,"expires":-1.0,"trap":"blast","charges":3,"trigger_radius":26.0,"radius":100.0,"explosion_damage":140.0},
	"arcane_tower":{"name":"祕法塔","role":"範圍·防守","faction":"magic","type":"building","ai":["guard","defend_building","obstacle"],"cost":20,"cooldown":10.0,"hp":350.0,"expires":-1.0,"range":230.0,"interval":1.9,"radius":75.0,"area_damage":90.0},

	"barricade":{"name":"木拒馬","role":"耐久·阻擋","type":"building","ai":["defend_building","obstacle"],"cost":2,"cooldown":6.0,"hp":1500.0,"expires":-1.0},
	"bandit":{"name":"強盜","role":"潛行·突襲","type":"unit","cost":5,"cooldown":6.0,"count":4,"hp":80.0,"damage":10.0,"interval":0.85,"range":47.0,"speed":65.0,"stealth":true},
	"corpse_giant":{"name":"腐屍巨人","role":"重裝·屍爆","faction":"dark","series":"dark","type":"unit","cost":20,"cooldown":12.0,"count":1,"hp":1500.0,"damage":42.0,"interval":1.1,"range":47.0,"speed":27.0,"on_death_spawn":["skeleton",4]},
	"curse":{"name":"詛咒","role":"死後·為奴","faction":"dark","series":"dark","type":"spell","ai":["defend_spell","wave_spell"],"cost":2,"cooldown":10.0,"radius":100.0},
	"catapult":{"name":"投石車","role":"遠程·拋射","type":"unit","ai":["hold"],"cost":22,"cooldown":12.0,"count":1,"hp":350.0,"damage":90.0,"area_damage":90.0,"interval":1.9,"range":430.0,"min_range":100.0,"radius":75.0,"flight_time":0.8,"speed":20.0},
	"drummer":{"name":"戰鼓手","role":"鼓舞·進軍","type":"unit","ai":["no_defend"],"cost":3,"cooldown":8.0,"count":1,"hp":210.0,"damage":6.0,"interval":1.1,"range":140.0,"speed":36.0,"inspire_duration":3.0,"inspire_period":10.0},
	"shieldguard":{"name":"盾衛","role":"盾牆·減傷","type":"unit","cost":9,"cooldown":4.0,"count":3,"hp":210.0,"damage":10.0,"interval":1.1,"range":47.0,"speed":36.0,"armor":10.0},
	"grave":{"name":"墓碑","role":"死亡·經濟","faction":"dark","series":"dark","type":"building","cost":5,"cooldown":30.0,"hp":350.0,"expires":-1.0,"period":60.0,"income":6.0,"death_advance":5.0},
	"skeleton":{"name":"骷髏兵","role":"廉價·纏鬥","faction":"dark","series":"dark","type":"unit","cost":5,"cooldown":2.0,"count":4,"hp":50.0,"damage":10.0,"interval":0.65,"range":47.0,"speed":65.0},
	"ghoul":{"name":"食屍鬼","role":"吞噬·成長","faction":"dark","series":"dark","type":"unit","cost":16,"cooldown":6.0,"count":2,"hp":210.0,"damage":26.0,"interval":0.85,"range":47.0,"speed":65.0,"radius":100.0,"devour_heal":50.0,"max_damage_tier":"A"},
	"necromancer":{"name":"死靈法師","role":"三路·招魂","faction":"dark","series":"dark","type":"unit","projectile":true,"cost":14,"cooldown":12.0,"count":1,"hp":210.0,"damage":10.0,"interval":1.1,"range":230.0,"speed":36.0,"summon_interval":10.0,"summon_per_lane":2},
	"reaper":{"name":"收割者","role":"直劈·三路","faction":"dark","series":"dark","type":"unit","splash":"column","cost":15,"cooldown":10.0,"count":1,"hp":350.0,"damage":110.0,"interval":1.9,"range":100.0,"speed":50.0},
	"raven":{"name":"烏鴉群","role":"飛行·拆田","faction":"dark","series":"dark","type":"unit","hits":"buildings","prefers":"farm","cost":6,"cooldown":6.0,"count":6,"hp":50.0,"damage":6.0,"interval":0.65,"range":47.0,"speed":160.0,"flying":true},
	"plague":{"name":"瘟疫","role":"毒霧·擴散","faction":"dark","series":"dark","type":"spell","ai":["defend_spell"],"cost":4,"cooldown":10.0,"radius":100.0,"tick_damage":35.0,"tick_interval":1.0,"duration":10.0,"spread_duration":3.0,"spread_radius":75.0},
	"bonewall":{"name":"骨牆","role":"阻擋·反擊","faction":"dark","series":"dark","type":"building","ai":["defend_building"],"cost":2,"cooldown":8.0,"hp":3000.0,"expires":-1.0,"explosion_damage":140.0,"radius":100.0},
	"farmer":{"name":"農民","role":"經濟·耕田","faction":"normal","type":"unit","ai":["no_defend"],"cost":7,"cooldown":0.0,"count":3,"hp":80.0,"damage":6.0,"interval":1.1,"range":47.0,"speed":50.0},
	"militia":{"name":"民兵隊","role":"循環·擋路","type":"unit","cost":14,"cooldown":2.0,"count":5,"hp":130.0,"damage":26.0,"interval":0.85,"range":47.0,"speed":50.0},
	"harvest":{"name":"豐收","role":"經濟·爆發","faction":"normal","type":"spell","cost":3,"cooldown":8.0,"radius":100.0},
	"scarecrow":{"name":"稻草人","role":"誘敵·護田","faction":"normal","type":"building","ai":["guard","defend_building","obstacle"],"cost":3,"cooldown":3.0,"hp":900.0,"expires":-1.0},
	"mob":{"name":"乾草叉暴民","role":"三路群攻","faction":"normal","type":"unit","ai":["raid"],"cost":14,"cooldown":6.0,"count":4,"spread":true,"hp":80.0,"damage":10.0,"interval":0.85,"range":47.0,"speed":65.0},
	"hunter":{"name":"獵戶","role":"遠程輸出","type":"unit","projectile":true,"cost":7,"cooldown":4.0,"count":3,"hp":80.0,"damage":16.0,"interval":1.4,"range":300.0,"speed":36.0},
	"spearbow":{"name":"槍弓混編","role":"遠近軍團","type":"unit","cost":13,"cooldown":6.0,"members":[["militia",4,0.0],["hunter",2,45.0]],"art":["militia","hunter"]},
	"farm":{"name":"農田","role":"經濟·基礎","faction":"normal","type":"building","cost":6,"cooldown":30.0,"hp":250.0,"expires":-1.0},
	"rain":{"name":"箭雨","role":"清群法術","type":"spell","ai":["defend_spell","wave_spell"],"cost":5,"cooldown":6.0,"radius":100.0,"damage":140.0,"building_damage":90.0,"gate_damage":90.0},
	"tower":{"name":"箭樓","role":"防守","type":"building","ai":["guard","defend_building","obstacle"],"cost":13,"cooldown":8.0,"hp":350.0,"expires":-1.0,"range":300.0,"damage":26.0,"interval":0.65},
	"healer":{"name":"草藥婆","role":"支援·治療","faction":"normal","type":"unit","ai":["no_defend","hold"],"cost":4,"cooldown":8.0,"count":1,"hp":210.0,"damage":6.0,"interval":1.1,"range":140.0,"speed":36.0},
	"ox":{"name":"耕牛","role":"衝鋒·拆建","faction":"normal","type":"unit","ai":["raid"],"cost":11,"cooldown":10.0,"count":2,"hp":350.0,"damage":26.0,"interval":1.9,"range":47.0,"speed":120.0},
	"fire":{"name":"火罐","role":"燒田法術","type":"spell","ai":["defend_spell","wave_spell","raid"],"cost":9,"cooldown":15.0,"radius":100.0,"damage":370.0,"building_damage":600.0,"gate_damage":140.0},
	"knight":{"name":"騎士","role":"主坦","faction":"normal","type":"unit","cost":26,"cooldown":15.0,"count":2,"hp":900.0,"damage":70.0,"interval":1.9,"range":47.0,"speed":27.0},
	"guard":{"name":"聖堂護衛","role":"重裝軍團","faction":"normal","type":"unit","cost":27,"cooldown":18.0,"members":[["knight",2,0.0],["healer",2,50.0]],"art":["knight","healer"]},
	"mill":{"name":"磨坊","role":"大型經濟","faction":"normal","type":"building","ai":["obstacle"],"cost":16,"cooldown":20.0,"hp":900.0,"expires":-1.0},
	"ram":{"name":"攻城槌","role":"終結·破門","type":"unit","hits":"buildings","ai":["hold"],"cost":20,"cooldown":30.0,"members":[["ram",1,0.0],["militia",4,-40.0]],"art":["ram","militia"],"count":1,"hp":1500.0,"damage":360.0,"interval":2.4,"range":47.0,"speed":20.0}
}

# Behaviour fields a card may carry (read by battle.gd; a new card only needs the fields):
#   "projectile": true            attacks fire an arrow (flight time ARROW_TIME) instead of hitting at once
#   "hits": "buildings"           ignores troops and lords; only attacks buildings and gates
#   "prefers": "farm"             walks to and attacks enemy farms in its lane first
#   "target_rule": "lowest_serial" attacks the lowest serial in reach instead of the nearest
#   "splash": "column"            each hit also strikes every enemy troop in the target's column,
#                                 in this lane and the two next to it (a vertical slash)
#   "flying": true                melee troops and buildings cannot hit it
# AI tags in "ai" (read by enemy_ai.gd):
#   defend_spell   cast on attackers near our gate      wave_spell   cast on enemy clusters while attacking
#   raid           sent at the lane with most enemy farms  guard      one per farm lane, early
#   defend_building placed in front of attackers        obstacle     counts as an enemy wall when choosing a lane
#   no_defend      never sent to stop an attack          hold         only played with gold to spare (or at 45+)
# Each lord's permanent card in the F slot (and its two starting buildings): farmland, except the
# underworld lord, whose tombstones replace farms (producer 2026-10-30). Home cards never go in the
# chosen eight.
static func home_card(lord: String) -> String:
	return LORDS.get(lord,{}).get("home_card","farm")

static func is_home_card(kind: String, lord: String = "") -> bool:
	return kind in ["farm","grave","crystal"]

# Factions (producer 2026-10-30): a card with "faction" can only be taken by lords of that faction;
# a card without one is neutral (中立) and fits every deck. Lords carry their faction too.
const FACTIONS := {"normal":"經典","dark":"黑暗","magic":"魔法","":"中立"} # internal key "normal" = 經典; "magic" = the mage lord's own cards (producer 2026-11-03)

static func card_faction(kind: String) -> String:
	return CARDS[kind].get("faction","")

static func lord_faction(lord: String) -> String:
	return LORDS.get(lord,{}).get("faction","normal")

static func card_allowed(kind: String, lord: String) -> bool:
	var faction := card_faction(kind)
	return faction.is_empty() or faction == lord_faction(lord)

static func has_tag(kind: String, tag: String) -> bool:
	return tag in CARDS[kind].get("ai",[])

const CARD_TYPES := ["unit","building","spell"]
# Area effects use the "area_damage" tiers (a spell's "damage" too); troops use "damage".
const AREA_DAMAGE_KEYS := ["damage","building_damage","gate_damage","tick_damage","explosion_damage"]
const BEHAVIOUR_VALUES := {"hits":["buildings"],"prefers":["farm"],"target_rule":["lowest_serial"],"splash":["column"]}
const AI_TAGS := ["defend_spell","wave_spell","raid","guard","defend_building","obstacle","no_defend","hold"]
const NEEDS := {"unit":["count","hp","damage","interval","range","speed"],"building":["hp","expires"],"spell":["radius"]}
const LORD_NEEDS := ["name","role","hp","damage","speed","skill","skill_desc"]

# Everything wrong with the card and lord tables ([] = fine). smoke_test.gd fails on any problem and
# the game prints them at start, so a new card with a typo or a missing field is caught at once.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	for kind: String in CARDS:
		var c: Dictionary = CARDS[kind]
		var before := problems.size()
		for key: String in ["name","role","type","cost","cooldown"]:
			if not c.has(key): problems.append("%s: missing %s" % [kind,key])
		var type: String = c.get("type","")
		if not type in CARD_TYPES:
			problems.append("%s: type must be one of %s" % [kind,str(CARD_TYPES)])
			continue
		if c.get("cost",0) < 1 or c.get("cost",0) > 30: problems.append("%s: cost must be 1-30" % kind)
		if c.get("cooldown",0.0) < 0 or c.get("cooldown",0.0) > 30: problems.append("%s: cooldown must be 0-30 s" % kind)
		if c.has("members"):
			for group: Array in c.members:
				if not CARDS.has(group[0]) or not CARDS[group[0]].has("hp"): problems.append("%s: legion member %s is not a troop card" % [kind,str(group[0])])
		else:
			for key: String in NEEDS[type]:
				if not c.has(key): problems.append("%s: a %s needs %s" % [kind,type,key])
		for stat: String in TIERS:
			if c.has(stat) and (type == "unit" or c.has("range")):
				if stat == "damage" and c.has("area_damage"):
					if tier("area_damage",c[stat]).is_empty(): problems.append("%s: damage %s is not an area damage tier value" % [kind,str(c[stat])])
					continue
				if tier(stat,c[stat]).is_empty(): problems.append("%s: %s %s is not a tier value" % [kind,stat,str(c[stat])])
		for key: String in ["radius","spread_radius","trigger_radius"]:
			if c.has(key) and tier("radius",c[key]).is_empty(): problems.append("%s: %s %s is not a radius tier value" % [kind,key,str(c[key])])
		for key: String in AREA_DAMAGE_KEYS:
			if c.has(key) and (key != "damage" or type == "spell") and tier("area_damage",c[key]).is_empty(): problems.append("%s: %s %s is not an area damage tier value" % [kind,key,str(c[key])])
		for key: String in BEHAVIOUR_VALUES:
			if c.has(key) and not c[key] in BEHAVIOUR_VALUES[key]: problems.append("%s: %s must be one of %s" % [kind,key,str(BEHAVIOUR_VALUES[key])])
		if not c.get("faction","") in FACTIONS: problems.append("%s: faction must be normal, dark, magic or absent (neutral)" % kind)
		for tag in c.get("ai",[]):
			if not tag in AI_TAGS: problems.append("%s: unknown AI tag %s" % [kind,str(tag)])
		for key: String in ["blink_step","resonance","resonance_max","stun_on_hit"]:
			if c.has(key) and (c[key] < 0 or c[key] > (5.0 if key == "stun_on_hit" else 1.0)): problems.append(kind+": invalid "+key)
		for key: String in ["pierce","phase"]:
			if c.has(key) and not c[key] is bool: problems.append(kind+": invalid "+key)
		if c.has("trap") and not c.trap in ["teleport","blast","summon"]: problems.append(kind+": unknown trap")
		if c.get("trap","") == "summon":
			if not CARDS.has(c.get("summon_kind","")) or c.get("summon_count",0) < 1 or c.get("charges",0) < 1: problems.append(kind+": invalid summon trap")
		if c.has("max_period") and c.max_period < c.get("period",0): problems.append(kind+": invalid production period")
		if c.has("decay_fraction") and (c.decay_fraction <= 0 or c.decay_fraction > 1): problems.append(kind+": invalid decay fraction")
		if c.has("repair_amount") and (c.repair_amount <= 0 or c.get("repair_interval",0) <= 0 or c.get("repair_range",0) <= 0): problems.append(kind+": invalid repair values")
		if c.has("on_death_spawn"):
			var spawn: Array = c.on_death_spawn
			if spawn.size() != 2 or not CARDS.has(spawn[0]) or CARDS[spawn[0]].type != "unit" or spawn[1] <= 0: problems.append("%s: invalid on_death_spawn" % kind)
		if c.get("armor",0.0) < 0: problems.append("%s: armor must be nonnegative" % kind)
		if c.has("min_range") and (c.min_range < 0 or c.min_range >= c.get("range",0)): problems.append("%s: invalid minimum range" % kind)
		# The description reads the fields above, so only build it once they are all present.
		if problems.size() == before and card_description(kind).is_empty(): problems.append("%s: no description" % kind)
	for pair: Array in [["HEAL_RADIUS",HEAL_RADIUS]]:
		if tier("radius",pair[1]).is_empty(): problems.append("%s %s is not a radius tier value" % pair)
	for kind: String in LORDS:
		for key: String in LORD_NEEDS:
			if not LORDS[kind].has(key): problems.append("lord %s: missing %s" % [kind,key])
		for stat: String in ["hp","damage","speed"]:
			if LORDS[kind].has(stat) and tier(stat,LORDS[kind][stat]).is_empty(): problems.append("lord %s: %s is not a tier value" % [kind,stat])
		var home: String = home_card(kind)
		if not LORDS[kind].get("faction","") in FACTIONS: problems.append("lord %s: invalid faction" % kind)
		if CARDS.has(home) and not card_allowed(home,kind): problems.append("lord %s: home_card %s belongs to another faction" % [kind,home])
		if not CARDS.has(home) or CARDS[home].type != "building": problems.append("lord %s: home_card %s must be a building card" % [kind,home])
	return problems

# Deck = farmland (always, own hand slot) + a chosen lord + 8 rotating cards (producer 2026-10-29).
const PRESET_NAMES := ["向日葵流","穩健農莊","劫掠隊"]
const PRESETS := [
	["farmer","hunter","mill","spearbow","tower","militia","rain","ox"],
	["farmer","militia","hunter","knight","spearbow","tower","rain","healer"],
	["farmer","mob","ox","ram","hunter","fire","scarecrow","militia"]
]
const PRESET_LORDS := ["harvest","iron","lion"]
# Lords are chosen on the deck screen and never enter the hand.
# All lords have the same tier-A health (producer 2026-10-29): they differ only in attack and skill.
# Lord speeds (2026-11-03 ten tiers): lion/adventure C 65, mage/underworld/harvest D 50, iron E 36.
const LORDS := {
	"rune":{"name":"符文領主","role":"法陣型","faction":"magic","home_card":"crystal","hp":900.0,"damage":70.0,"speed":50.0,"skill":"符文前線","skill_cost":15.0,"skill_desc":"在每條開放路線領地最前方的空格，各召喚一個隨機陷阱法陣；不覆蓋建築。"},
	"vampire":{"name":"吸血領主","role":"血契型","faction":"dark","home_card":"grave","hp":900.0,"damage":70.0,"speed":50.0,"skill":"鮮血盟約","skill_cost":30.0,"blood_duration":20.0,"skill_desc":"所有友方部隊攻速、移速升一檔（最高 S），持續 %s 秒；造成實際傷害時等量增加自身目前及最大生命，已獲得生命保留。"},
	"mage":{"name":"法師領主","role":"時空型","faction":"magic","home_card":"crystal","hp":900.0,"damage":70.0,"speed":50.0,"skill":"時空凝滯","skill_cost":15.0,"freeze_duration":10.0,"skill_desc":"空間波動後凍結時間 %s 秒，只有友方軍隊與施法領主可以行動；產金、冷卻、投射物與選單全部暫停。"},
	"adventure":{"name":"邊境領主","role":"主角型","faction":"normal","hp":900.0,"damage":110.0,"speed":65.0,"skill":"破陣斬","skill_cost":10.0,"skill_cells":3,"skill_damage":600.0,"skill_desc":"向前斬出長 %s 格、寬一格的劍氣，對範圍內敵軍、建築與領主造成 %s 傷害。"},
	"underworld":{"name":"冥府領主","role":"亡者型","faction":"dark","home_card":"grave","hp":900.0,"damage":70.0,"speed":50.0,"skill":"亡者大軍","skill_cost":20.0,"summon_count":4,"skill_desc":"我方每座墓碑各召喚 %s 隻骷髏兵；沒有墓碑時無法發動。"},
	"lion":{"name":"紅獅領主","role":"進攻型","faction":"normal","hp":900.0,"damage":70.0,"speed":65.0,"skill":"獅王號令","skill_desc":"每路從己方城門各召喚一名騎士，緩步進軍。"},
	"harvest":{"name":"豐收領主","role":"經濟型","faction":"normal","hp":900.0,"damage":42.0,"speed":50.0,"skill":"豐年祭","skill_desc":"每路在己方領地空格種一塊農田，全部農田回滿血。"},
	"iron":{"name":"鐵壁領主","role":"防守型","faction":"normal","hp":900.0,"damage":70.0,"speed":36.0,"skill":"重築城牆","skill_desc":"五座城門回滿血，已破的城門重建，城門前拆殘垣的敵兵要重新開始。"}
}
# Lord skills (producer 2026-10-29): lords have no passive effects; each has one strong skill the
# player casts with Q (the AI casts its own). It costs a full purse and has a long cooldown.
const SKILL_COST := 50.0
const SKILL_COOLDOWN := 60.0
const SKILL_OPENING_COOLDOWN := 60.0
const LION_KNIGHT_SPEED := 36.0 # 紅獅號令騎士緩步行軍速度
const FEAST_BOOST := 30.0 # 豐年祭: seconds of doubled farm output
static func skill_cost(kind: String) -> float:
	return LORDS[kind].get("skill_cost",SKILL_COST)

# One-line skill text for the deck screen, battle panel and help.
static func skill_text(kind: String) -> String:
	var info: Dictionary = LORDS[kind]
	var desc: String = (info.skill_desc % number(FEAST_BOOST)) if (kind == "harvest" and "%s" in info.skill_desc) else info.skill_desc
	if kind == "underworld": desc = desc % int(info.summon_count)
	if kind == "mage": desc = desc % number(info.freeze_duration)
	if kind == "vampire": desc = desc % number(info.blood_duration)
	if kind == "adventure": desc = desc % [str(info.skill_cells),number(info.skill_damage)]
	return "%s（%d 金幣，冷卻 %d 秒）：%s" % [info.skill,int(skill_cost(kind)),int(SKILL_COOLDOWN),desc]

# Stat tiers SSS..G (producer 2026-11-03: ten tiers). S keeps the old S value and G is the old floor
# (old E: nothing below it means anything); A..F split that span evenly, SS/SSS sit above S. Every troop, tower and lord stat uses exactly one of these values, so the same tier always
# means the same number. Interval is seconds per hit (lower = faster).
# Use tier_index()/tier_value() instead of raw array positions: positions moved when tiers were added.
const TIER_NAMES := ["SSS","SS","S","A","B","C","D","E","F","G"]
const TIERS := {
	"radius":[760.0,470.0,290.0,210.0,150.0,100.0,75.0,52.0,37.0,26.0], # S spans 5 x 5 cells
	"area_damage":[2400.0,1200.0,600.0,370.0,230.0,140.0,90.0,55.0,35.0,20.0], # spells and explosions
	"damage":[720.0,360.0,180.0,110.0,70.0,42.0,26.0,16.0,10.0,6.0],
	"hp":[6000.0,3000.0,1500.0,900.0,560.0,350.0,210.0,130.0,80.0,50.0],
	"range":[620.0,430.0,300.0,230.0,180.0,140.0,100.0,80.0,60.0,47.0],
	"speed":[360.0,240.0,160.0,120.0,90.0,65.0,50.0,36.0,27.0,20.0],
	"interval":[0.18,0.27,0.4,0.5,0.65,0.85,1.1,1.4,1.9,2.4],
}
# What each tier is for, per stat (same order as TIER_NAMES). docs/數值檔次.md lists the cards on each tier.
# SSS and SS are reserved for bosses, walls, siege engines and lord skills; troop cards normally stop at S.
const TIER_NOTES := {
	"hp":[
		"最終 BOSS：關卡魔王專用，整場戰役合力才打得倒",
		"頂級城牆：要一整支軍隊圍攻才拆得掉",
		"優質肉盾：重裝前排與重型器械",
		"主坦・英雄：能單獨扛住一路",
		"精英重兵：比重型單位再硬一截",
		"重型單位：標準建築與重兵",
		"中堅：能挨幾下的二線兵與支援",
		"標準步兵：一對一能互換的基本兵",
		"人海：一張牌給好幾個，各自能挨一兩下",
		"蟲群：單隻不算數，只看總量，範圍法術的獵物"],
	"damage":[
		"魔王必殺：一擊打死所有部隊",
		"處決：一兩下拆掉城門",
		"破城：重型攻城",
		"重擊：主坦與強攻型領主的普攻",
		"精英：比主戰再痛一截",
		"主戰：穩定的主力輸出",
		"普通兵：標準近戰",
		"小隊長：比輕攻擊強一點的雜兵頭目",
		"輕攻擊：單發不痛，靠人數堆傷害",
		"自衛・騷擾：支援角色防身、拆沒人顧的田"],
	"area_damage":[
		"天災：清空全場",
		"毀滅：一發清掉主坦群",
		"大招：燒平建築、領主技能",
		"強力清場：清掉中堅群",
		"重型清群：清掉人海與步兵",
		"標準清群：一發清掉蟲群與人海",
		"拋射：削血不秒殺，也拿來削建築",
		"削弱：連續命中才有用",
		"持續傷害：毒霧每一跳",
		"附帶：控場效果順便造成的傷害"],
	"radius":[
		"全場：幾乎蓋住整個戰場",
		"半場：蓋住大半個戰場",
		"巨型：約 5×5 格",
		"大型：約 3×3 格",
		"中大型：一路加左右各一路",
		"標準法術：一路加左右各半路",
		"小型：落點周圍一小團",
		"單格：只打一格",
		"腳下：只影響自己站的位置",
		"觸發點：陷阱踩到才發動的距離"],
	"range":[
		"全圖：從後排打到對面",
		"超遠程：半個戰場，攻城武器",
		"重砲：最遠的防守遠程",
		"遠程：一般射手",
		"長程支援：站在射手後面",
		"中程支援：鼓舞、治療的距離",
		"長兵器：隔一個身位出手",
		"長槍：比近戰多半個身位",
		"短兵：比近戰略長",
		"近戰：貼身肉搏"],
	"speed":[
		"瞬移級：一眨眼橫越戰場",
		"疾風：超高速突襲",
		"極速：飛行突襲",
		"衝鋒：騎乘與衝撞",
		"輕騎：比輕裝再快一截",
		"敏捷：輕裝快攻",
		"標準：一般行軍",
		"緩慢：遠程與支援",
		"笨重：重裝前排",
		"攻城器：最慢，推著走的器械"],
	"interval":[
		"暴風連擊：一秒五下以上",
		"連擊：一秒三四下",
		"極快：快攻專精",
		"快攻：一秒兩下",
		"快速：小傷害高頻",
		"偏快：輕裝步兵",
		"標準：約一秒一下",
		"稍慢：穩扎穩打",
		"重擊：蓄力一下很痛",
		"攻城：一下拆一大塊"]
}

# Tier letter of a stat value, or "" when the value is off the tier table.
static func tier(stat: String, value: float) -> String:
	for i: int in range(TIER_NAMES.size()):
		if is_equal_approx(TIERS[stat][i],value): return TIER_NAMES[i]
	if stat == "damage" and TIERS.has("area_damage"):
		for i: int in range(TIER_NAMES.size()):
			if is_equal_approx(TIERS["area_damage"][i],value): return TIER_NAMES[i]
	return ""

# Position of a tier letter in TIER_NAMES (lower = stronger), and the value of a stat at that tier.
static func tier_index(tier_name: String) -> int:
	return TIER_NAMES.find(tier_name)

static func tier_value(stat: String, tier_name: String) -> float:
	return TIERS[stat][tier_index(tier_name)]

# Note for a stat value's tier, e.g. tier_note("hp",1500.0) -> "優質肉盾：...".
static func tier_note(stat: String, value: float) -> String:
	var index := tier_index(tier(stat,value))
	return TIER_NOTES[stat][index] if index >= 0 and TIER_NOTES.has(stat) else ""

const MILL_BONUS := 2.0
const HARVEST_TIME := 15.0 # 豐收 doubles farms this long; no instant payout since 2026-10-30
const HEAL_RADIUS := 100.0 # radius tier C
const HEAL_AMOUNT := 15.0
const HEAL_INTERVAL := 1.0
const OX_CHARGE := 150.0
const OX_KNOCKBACK := 30.0
const OX_BUILDING_BONUS := 1.5
const OX_SLOW_SPEED := 36.0
const FIRE_KNOCKBACK := 20.0

# Text shares the data used by combat; optional tables let tests exercise future balance edits.
static func number(value: float) -> String:
	return String.num(value,2)

static func troop_description(kind: String, count: int, cards: Dictionary) -> String:
	var d: Dictionary = cards[kind]
	return "%s ×%d：每名生命 %s、傷害 %s／%s 秒、射程 %s、移速 %s。" % [d.name,count,number(d.hp),number(d.damage),number(d.interval),number(d.range),number(d.speed)]

static func card_description(kind: String, cards: Dictionary = CARDS) -> String:
	var d: Dictionary = cards[kind]
	var lines: Array[String] = ["%s · %s 金幣 · 冷卻 %s 秒 · %s" % [d.name,number(d.cost),number(d.cooldown),d.role]]
	if d.get("summon_only",false): lines[0] = d.name+" · "+d.role
	if d.type == "unit":
		if d.has("members"):
			var march := INF
			for group: Array in d.members:
				lines.append(troop_description(group[0],group[1],cards))
				march = minf(march,cards[group[0]].speed)
			lines.append("軍團以最慢成員速度 %s 一起前進。" % number(march))
		else: lines.append(troop_description(kind,d.count,cards))
		if d.get("spread",false): lines.append("三路各 %d 名，共 %d 名；邊路施放時向內移一條路。" % [d.count,d.count*3])
	elif d.type == "building":
		lines.append("生命 %s；永久存在，同種建築覆蓋可補滿生命。" % number(d.hp))
		if d.has("damage"): lines.append("傷害 %s／%s 秒、射程 %s。" % [number(d.damage),number(d.interval),number(d.range)])
	else:
		lines.append("範圍半徑 %s；落下時間 %s 秒。" % [number(d.radius),number(SPELL_DELAY)])
		if d.has("damage"): lines.append("部隊傷害 %s、建築傷害 %s、城門傷害 %s。" % [number(d.damage),number(d.building_damage),number(d.gate_damage)])
	match kind:
		"summon_trap": lines.append("敵方地面部隊踩入 %s 範圍時，召喚 %d 隻%s；共可觸發 %d 次。同一名敵兵只觸發一次，同時踩入的一群只消耗一次。飛行與相位單位不觸發。" % [number(d.trigger_radius),d.summon_count,cards[d.summon_kind].name,d.charges])
		"chimera": lines.append("由召喚法陣召喚的地面近戰部隊；不能直接加入牌組。")
		"dark_wizard": lines.append("致命傷害時吞噬 3×3 格內最近的友方部隊，以其最大生命續命，可反覆觸發。領主、建築與未登場者除外。")
		"blink_blade": lines.append("每次受傷向前閃現 %s 格，優先攻擊前方；不能越過城門。" % number(d.blink_step))
		"arcane_golem": lines.append("每座友方水晶減傷 %s%%，最多 %s%%；工匠可修補。死亡對半徑 %s 內敵兵造成 %s 傷害。" % [number(d.resonance*100),number(d.resonance_max*100),number(d.radius),number(d.explosion_damage)])
		"arcane_archer": lines.append("光箭飛行 %s 秒，貫穿本路 %s 距離（索敵距離的 %s 倍）；可對空並揭露潛行。" % [number(ARROW_TIME),number(d.range*d.pierce_range_multiplier),number(d.pierce_range_multiplier)])
		"chronomancer": lines.append("落點半徑 %s 造成 %s 傷害，敵兵暈眩 %s 秒；不縮短既有暈眩。" % [number(d.radius),number(d.area_damage),number(d.stun_on_hit)])
		"phase_rider": lines.append("相位中穿過敵兵、無法被鎖定且不觸發陷阱；首次攻擊建築或城門後現形，範圍傷害仍可命中。")
		"artificer": lines.append("無敵人在攻擊距離內時，優先跟隨修補距離 %s 內受損最多的魔像，否則維修友方建築，每 %s 秒恢復 %s 生命；不復活已摧毀建築。" % [number(d.repair_range),number(d.repair_interval),number(d.repair_amount)])
		"crystal": lines.append("每次產出 %s 金幣並損失最大生命的 %s%%，自身耗損最低留 1 生命。產出間隔隨生命降低由 %s 秒延長至 %s 秒；維修可恢復效率，敵人仍能摧毀。" % [number(d.income),number(d.decay_fraction*100),number(d.period),number(d.max_period)])
		"teleport_trap": lines.append("敵方地面部隊踩入 %s 範圍後觸發（可傳送 %s 次），將 %s 範圍內敵方地面部隊送回本路的敵方起點，並使被傳送敵軍暈眩且減速 %s 秒。不阻擋或吸引普攻。" % [number(d.trigger_radius),number(d.get("charges",3)),number(d.radius),number(d.get("stun_duration",10.0))])
		"blast_trap": lines.append("敵方地面部隊踩入 %s 範圍後爆炸（可爆炸 %s 次），對 %s 範圍內敵方地面部隊造成 %s 傷害；同一名敵兵只會觸發同一座法陣一次。不阻擋或吸引普攻。" % [number(d.trigger_radius),number(d.get("charges",3)),number(d.radius),number(d.explosion_damage)])
		"arcane_tower": lines.append("每 %s 秒攻擊射程 %s 內敵軍，對落點半徑 %s 內敵方部隊造成 %s 範圍傷害，可對空。" % [number(d.interval),number(d.range),number(d.radius),number(d.area_damage)])
		"barricade": lines.append("沒有特殊效果。不攻擊、不產金、不反傷；依一般建築規則提供領地。")
		"bandit": lines.append("登場時潛行，無法被敵方直接鎖定；首次攻擊或受到傷害後現身。範圍傷害仍可命中。")
		"corpse_giant": lines.append("死亡時在原地召喚 %d 名%s；自身死亡仍會加速墓碑並觸發吞噬。" % [d.on_death_spawn[1],cards[d.on_death_spawn[0]].name])
		"curse": lines.append("範圍內敵兵受到永久詛咒；死亡時在原地變成我方骷髏兵。")
		"catapult": lines.append("攻擊本路距離 %s～%s 內最遠敵方部隊或建築；每 %s 秒拋射，%s 秒後落地，對半徑 %s 內敵方部隊與建築造成 %s 範圍傷害。落點不追蹤移動。" % [number(d.min_range),number(d.range),number(d.interval),number(d.flight_time),number(d.radius),number(d.area_damage)])
		"drummer": lines.append("登場時與之後每 10 秒擊鼓，全場友軍（不含自身）移速與攻速各升一檔，持續 3 秒，最高 S。多名戰鼓手不疊加時間。")
		"shieldguard": lines.append("每次受到傷害減少 %s，最低仍受 1 傷害。" % number(d.armor))
		"grave": lines.append("每 %s 秒產出 %s 金幣；本路每名敵我部隊死亡，提前 %s 秒，超出的時間不保留。" % [number(d.period),number(d.income),number(d.death_advance)])
		"ghoul": lines.append("半徑 %s 內每名部隊死亡，回復 %s 生命，攻擊升一檔，最高 A 檔 %s。" % [number(d.radius),number(d.devour_heal),number(tier_value("damage",d.max_damage_tier))])
		"necromancer": lines.append("上場時與之後每 %s 秒，在本路與相鄰路同一欄各召喚 %d 名骷髏兵。" % [number(d.summon_interval),d.summon_per_lane])
		"reaper": lines.append("揮鐮直劈：每次攻擊也打中目標那一欄、本路與上下相鄰兩路的所有敵兵。")
		"raven": lines.append("飛越近戰部隊，只攻擊建築與城門，優先本路農田；遠程與領主仍可攻擊它。")
		"plague": lines.append("毒霧持續 %s 秒，每 %s 秒對敵兵造成 %s 傷害；毒死的敵兵產生半徑 %s、持續 %s 秒的小毒霧。" % [number(d.duration),number(d.tick_interval),number(d.tick_damage),number(d.spread_radius),number(d.spread_duration)])
		"bonewall": lines.append("摧毀時對半徑 %s 內敵兵造成 %s 傷害。" % [number(d.radius),number(d.explosion_damage)])
		"farm": lines.append("常駐卡，不輪轉。種下 %s 秒後啟動，每 %s 秒產出 %s 金幣（未加成）。" % [number(FARM_START),number(FARM_INTERVAL),number(FARM_DROP)])
		"farmer": lines.append("順路耕田 %s 秒，農田回復 %s 生命，%s 秒內產出加倍。" % [number(CULTIVATE_TIME),number(FARMER_HEAL),number(BOOST_TIME)])
		"mill": lines.append("同一路農田產出 ×%s；多座磨坊不疊加。" % number(MILL_BONUS))
		"scarecrow": lines.append("將周圍九宮格（本路與相鄰兩路、前後各一欄）內的敵兵吸引至同一路，且進入攻擊範圍內時優先攻擊稻草人，包括烏鴉。")
		"harvest": lines.append("範圍內農田持續 %s 秒產出加倍（不會立刻產出）；不與耕田加倍疊乘。" % number(HARVEST_TIME))
		"fire": lines.append("敵方部隊擊退 %s。" % number(FIRE_KNOCKBACK))
		"ox": lines.append("首擊傷害 %s，擊退 %s；建築與城門傷害 ×%s，衝鋒後移速 %s。" % [number(OX_CHARGE),number(OX_KNOCKBACK),number(OX_BUILDING_BONUS),number(OX_SLOW_SPEED)])
		"healer", "guard": lines.append("草藥婆每 %s 秒為半徑 %s 內友軍部隊回復 %s 生命。" % [number(HEAL_INTERVAL),number(HEAL_RADIUS),number(HEAL_AMOUNT)])
		"ram": lines.append("攻城槌只打建築與城門，民兵在前護送；破門後拆完殘垣再前進。")
		"hunter", "spearbow": lines.append("獵戶箭矢飛行 %s 秒，命中才扣血。" % number(ARROW_TIME))
	return "\n".join(lines)
