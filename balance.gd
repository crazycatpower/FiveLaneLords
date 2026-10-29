extends RefCounted
const START_INK := 10.0
const MAX_INK := 50.0
const BASE_INTERVAL := 2.0
const FARM_INTERVAL := 10.0
const FARM_START := 3.0
const FARM_DROP := 2.0
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
const LORD_HP := 900.0
const LORD_SPEED := 160.0
const LORD_RANGE := 88.0
const LORD_DAMAGE := 60.0
const LORD_INTERVAL := 0.65
const LORD_REGEN_DELAY := 6.0
const LORD_REGEN := 3.0 # producer: regeneration cut hard (was 25/s after 3 s)
const LORD_RETREAT_BELOW := 0.25 # retreat to the castle under this share of HP...
const LORD_RETURN_ABOVE := 0.45 # ...and come back above this one (unless a gate is being stormed)
const LORD_RESPAWN := 12.0
const AURA_RANGE := 145.0
const AURA_BONUS := 1.35
const AI_TICK := 0.5
const LORD_HYSTERESIS := 1.5
# Costs run 1..30 (producer decision 2026-10-29). "role" is the card's job, shown on the card face.
# Buildings never expire on their own (producer decision 2026-10-29); they stay until destroyed.
# "cooldown": seconds a card must wait after it enters the hand before it can be played (0..30).
const CARDS := {
	"farmer":{"name":"農民","role":"經濟·耕田","type":"unit","cost":1,"cooldown":0.0,"count":2,"hp":50.0,"damage":6.0,"interval":1.0,"range":47.0,"speed":42.0},
	"militia":{"name":"民兵隊","role":"循環·擋路","type":"unit","cost":3,"cooldown":2.0,"count":2,"hp":85.0,"damage":13.0,"interval":0.95,"range":47.0,"speed":39.0},
	"harvest":{"name":"豐收","role":"經濟·爆發","type":"spell","cost":3,"cooldown":8.0,"radius":120.0},
	"scarecrow":{"name":"稻草人","role":"誘敵·護田","type":"building","cost":4,"cooldown":3.0,"hp":400.0,"expires":-1.0},
	"mob":{"name":"乾草叉暴民","role":"群攻","type":"unit","cost":5,"cooldown":5.0,"count":5,"hp":45.0,"damage":9.0,"interval":0.9,"range":47.0,"speed":48.0},
	"hunter":{"name":"獵戶","role":"遠程輸出","type":"unit","cost":5,"cooldown":4.0,"count":2,"hp":55.0,"damage":10.0,"interval":1.2,"range":170.0,"speed":34.0},
	"farm":{"name":"農田","role":"經濟·基礎","type":"building","cost":6,"cooldown":6.0,"hp":250.0,"expires":-1.0},
	"rain":{"name":"箭雨","role":"清群法術","type":"spell","cost":6,"cooldown":6.0,"radius":110.0,"damage":200.0,"building_damage":60.0,"gate_damage":60.0},
	"tower":{"name":"箭樓","role":"防守","type":"building","cost":7,"cooldown":8.0,"hp":500.0,"expires":-1.0,"range":200.0,"damage":18.0,"interval":0.8},
	"healer":{"name":"草藥婆","role":"支援·治療","type":"unit","cost":8,"cooldown":8.0,"count":1,"hp":160.0,"damage":6.0,"interval":1.0,"range":120.0,"speed":32.0},
	"ox":{"name":"耕牛","role":"衝鋒·拆建","type":"unit","cost":9,"cooldown":10.0,"count":1,"hp":520.0,"damage":22.0,"interval":1.2,"range":47.0,"speed":70.0},
	"fire":{"name":"火罐","role":"燒田法術","type":"spell","cost":11,"cooldown":15.0,"radius":95.0,"damage":420.0,"building_damage":840.0,"gate_damage":140.0},
	"knight":{"name":"騎士","role":"主坦","type":"unit","cost":15,"cooldown":15.0,"count":1,"hp":1000.0,"damage":55.0,"interval":1.2,"range":47.0,"speed":32.0},
	"mill":{"name":"磨坊","role":"大型經濟","type":"building","cost":18,"cooldown":20.0,"hp":900.0,"expires":-1.0},
	"ram":{"name":"攻城槌","role":"終結·破門","type":"unit","cost":30,"cooldown":30.0,"count":1,"hp":1600.0,"damage":160.0,"interval":2.0,"range":47.0,"speed":22.0}
}

const PRESET_NAMES := ["向日葵流","穩健農莊","劫掠隊"]
const PRESETS := [
	["farm","farmer","harvest","mill","scarecrow","tower","militia","rain"],
	["farm","farmer","militia","hunter","knight","scarecrow","tower","rain"],
	["farm","farmer","mob","ox","ram","hunter","fire","scarecrow"]
]
const MILL_BONUS := 2.0
const HARVEST_TIME := 8.0
const HEAL_RADIUS := 120.0
const HEAL_AMOUNT := 15.0
const HEAL_INTERVAL := 1.0
const OX_CHARGE := 150.0
const OX_KNOCKBACK := 30.0
const OX_BUILDING_BONUS := 1.5
const OX_SLOW_SPEED := 30.0
const FIRE_KNOCKBACK := 20.0
const TAUNT_RADIUS := 150.0
