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
const LORD_INTERVAL := 0.4
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
	"farmer":{"name":"農民","role":"經濟·耕田","type":"unit","cost":3,"cooldown":0.0,"count":3,"hp":50.0,"damage":6.0,"interval":1.2,"range":47.0,"speed":45.0},
	"militia":{"name":"民兵隊","role":"循環·擋路","type":"unit","cost":10,"cooldown":2.0,"count":5,"hp":100.0,"damage":24.0,"interval":0.85,"range":47.0,"speed":45.0},
	"harvest":{"name":"豐收","role":"經濟·爆發","type":"spell","cost":3,"cooldown":8.0,"radius":120.0},
	"scarecrow":{"name":"稻草人","role":"誘敵·護田","type":"building","cost":2,"cooldown":3.0,"hp":400.0,"expires":-1.0},
	"mob":{"name":"乾草叉暴民","role":"三路群攻","type":"unit","cost":11,"cooldown":6.0,"count":4,"spread":true,"hp":50.0,"damage":12.0,"interval":0.85,"range":47.0,"speed":70.0},
	"hunter":{"name":"獵戶","role":"遠程輸出","type":"unit","cost":4,"cooldown":4.0,"count":3,"hp":50.0,"damage":12.0,"interval":1.7,"range":210.0,"speed":30.0},
	"spearbow":{"name":"槍弓混編","role":"遠近軍團","type":"unit","cost":12,"cooldown":6.0,"members":[["militia",4,0.0],["hunter",2,45.0]],"art":["militia","hunter"]},
	"farm":{"name":"農田","role":"經濟·基礎","type":"building","cost":6,"cooldown":30.0,"hp":250.0,"expires":-1.0},
	"rain":{"name":"箭雨","role":"清群法術","type":"spell","cost":6,"cooldown":6.0,"radius":110.0,"damage":200.0,"building_damage":60.0,"gate_damage":60.0},
	"tower":{"name":"箭樓","role":"防守","type":"building","cost":10,"cooldown":8.0,"hp":400.0,"expires":-1.0,"range":300.0,"damage":24.0,"interval":0.6},
	"healer":{"name":"草藥婆","role":"支援·治療","type":"unit","cost":5,"cooldown":8.0,"count":1,"hp":200.0,"damage":6.0,"interval":1.2,"range":145.0,"speed":30.0},
	"ox":{"name":"耕牛","role":"衝鋒·拆建","type":"unit","cost":12,"cooldown":10.0,"count":2,"hp":400.0,"damage":24.0,"interval":1.7,"range":47.0,"speed":105.0},
	"fire":{"name":"火罐","role":"燒田法術","type":"spell","cost":10,"cooldown":15.0,"radius":95.0,"damage":420.0,"building_damage":840.0,"gate_damage":140.0},
	"knight":{"name":"騎士","role":"主坦","type":"unit","cost":22,"cooldown":15.0,"count":2,"hp":750.0,"damage":90.0,"interval":1.7,"range":47.0,"speed":20.0},
	"guard":{"name":"聖堂護衛","role":"重裝軍團","type":"unit","cost":30,"cooldown":18.0,"members":[["knight",2,0.0],["healer",2,50.0]],"art":["knight","healer"]},
	"mill":{"name":"磨坊","role":"大型經濟","type":"building","cost":18,"cooldown":20.0,"hp":900.0,"expires":-1.0},
	"ram":{"name":"攻城槌","role":"終結·破門","type":"unit","cost":24,"cooldown":30.0,"members":[["ram",1,0.0],["militia",4,-40.0]],"art":["ram","militia"],"count":1,"hp":1500.0,"damage":180.0,"interval":2.4,"range":47.0,"speed":20.0}
}

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
# Lord speed tiers C/D/E (producer 2026-10-30): lion 45, harvest 30, iron 20.
const LORDS := {
	"lion":{"name":"紅獅領主","role":"進攻型","hp":750.0,"damage":90.0,"speed":45.0,"skill":"獅王號令","skill_desc":"每路有領地時各召喚一名騎士，從領地前線進攻。"},
	"harvest":{"name":"豐收領主","role":"經濟型","hp":750.0,"damage":45.0,"speed":30.0,"skill":"豐年祭","skill_desc":"每路在己方領地空格種一塊農田，全部農田回滿血並產量加倍 %s 秒。"},
	"iron":{"name":"鐵壁領主","role":"防守型","hp":750.0,"damage":90.0,"speed":20.0,"skill":"重築城牆","skill_desc":"五座城門回滿血，已破的城門重建，城門前拆殘垣的敵兵要重新開始。"}
}
# Lord skills (producer 2026-10-29): lords have no passive effects; each has one strong skill the
# player casts with Q (the AI casts its own). It costs a full purse and has a long cooldown.
const SKILL_COST := 50.0
const SKILL_COOLDOWN := 60.0
const FEAST_BOOST := 30.0 # 豐年祭: seconds of doubled farm output

# One-line skill text for the deck screen, battle panel and help.
static func skill_text(kind: String) -> String:
	var info: Dictionary = LORDS[kind]
	var desc: String = info.skill_desc % number(FEAST_BOOST) if kind == "harvest" else info.skill_desc
	return "%s（%d 金幣，冷卻 %d 秒）：%s" % [info.skill,int(SKILL_COST),int(SKILL_COOLDOWN),desc]

# Stat tiers S..E (producer 2026-10-29; nonlinear since 2026-10-30: damage/health 30x E->S, speed 8x,
# range and attack speed ~6x): every troop, tower and lord stat uses exactly one of these
# values, so the same tier always means the same number. Interval is seconds per hit (lower = faster).
const TIER_NAMES := ["S","A","B","C","D","E"]
const TIERS := {
	"damage":[180.0,90.0,45.0,24.0,12.0,6.0],
	"hp":[1500.0,750.0,400.0,200.0,100.0,50.0],
	"range":[300.0,210.0,145.0,100.0,70.0,47.0],
	"speed":[160.0,105.0,70.0,45.0,30.0,20.0],
	"interval":[0.4,0.6,0.85,1.2,1.7,2.4],
}

# Tier letter of a stat value, or "" when the value is off the tier table.
static func tier(stat: String, value: float) -> String:
	for i: int in range(TIER_NAMES.size()):
		if is_equal_approx(TIERS[stat][i],value): return TIER_NAMES[i]
	return ""

const MILL_BONUS := 2.0
const HARVEST_TIME := 15.0 # 豐收 doubles farms this long; no instant payout since 2026-10-30
const HEAL_RADIUS := 120.0
const HEAL_AMOUNT := 15.0
const HEAL_INTERVAL := 1.0
const OX_CHARGE := 150.0
const OX_KNOCKBACK := 30.0
const OX_BUILDING_BONUS := 1.5
const OX_SLOW_SPEED := 30.0
const FIRE_KNOCKBACK := 20.0
const TAUNT_RADIUS := 150.0

# Text shares the data used by combat; optional tables let tests exercise future balance edits.
static func number(value: float) -> String:
	return String.num(value,2)

static func troop_description(kind: String, count: int, cards: Dictionary) -> String:
	var d: Dictionary = cards[kind]
	return "%s ×%d：每名生命 %s、傷害 %s／%s 秒、射程 %s、移速 %s。" % [d.name,count,number(d.hp),number(d.damage),number(d.interval),number(d.range),number(d.speed)]

static func card_description(kind: String, cards: Dictionary = CARDS) -> String:
	var d: Dictionary = cards[kind]
	var lines: Array[String] = ["%s · %s 金幣 · 冷卻 %s 秒 · %s" % [d.name,number(d.cost),number(d.cooldown),d.role]]
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
		"farm": lines.append("常駐卡，不輪轉。種下 %s 秒後啟動，每 %s 秒產出 %s 金幣（未加成）。" % [number(FARM_START),number(FARM_INTERVAL),number(FARM_DROP)])
		"farmer": lines.append("順路耕田 %s 秒，農田回復 %s 生命，%s 秒內產出加倍。" % [number(CULTIVATE_TIME),number(FARMER_HEAL),number(BOOST_TIME)])
		"mill": lines.append("同一路農田產出 ×%s；多座磨坊不疊加。" % number(MILL_BONUS))
		"scarecrow": lines.append("嘲諷半徑 %s；攻擊範圍內的敵兵優先攻擊它。" % number(TAUNT_RADIUS))
		"harvest": lines.append("範圍內農田持續 %s 秒產出加倍（不會立刻產出）；不與耕田加倍疊乘。" % number(HARVEST_TIME))
		"fire": lines.append("敵方部隊擊退 %s。" % number(FIRE_KNOCKBACK))
		"ox": lines.append("首擊傷害 %s，擊退 %s；建築與城門傷害 ×%s，衝鋒後移速 %s。" % [number(OX_CHARGE),number(OX_KNOCKBACK),number(OX_BUILDING_BONUS),number(OX_SLOW_SPEED)])
		"healer", "guard": lines.append("草藥婆每 %s 秒為半徑 %s 內友軍部隊回復 %s 生命。" % [number(HEAL_INTERVAL),number(HEAL_RADIUS),number(HEAL_AMOUNT)])
		"ram": lines.append("攻城槌只打建築與城門，民兵在前護送；破門後拆完殘垣再前進。")
		"hunter", "spearbow": lines.append("獵戶箭矢飛行 %s 秒，命中才扣血。" % number(ARROW_TIME))
	return "\n".join(lines)
