extends RefCounted
const START_INK := 10.0
const MAX_INK := 50.0
const BASE_INTERVAL := 2.0
const FARM_INTERVAL := 10.0
const FARM_START := 3.0
const FARM_DROP := 2.0
const CULTIVATE_TIME := 1.5
const BOOST_TIME := 15.0
const PLAY_COOLDOWN := 0.8
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
const LORD_REGEN_DELAY := 3.0
const LORD_REGEN := 25.0
const LORD_RESPAWN := 12.0
const AURA_RANGE := 145.0
const AURA_BONUS := 1.35
const SPIN_RANGE := 155.0
const SPIN_DAMAGE := 180.0
const SPIN_COOLDOWN := 12.0
const COMMAND_RANGE := 200.0
const COMMAND_TIME := 6.0
const COMMAND_BONUS := 1.4
const COMMAND_COOLDOWN := 30.0
const AI_TICK := 0.5
const LORD_HYSTERESIS := 1.5
const CARDS := {
	"mob":{"name":"乾草叉暴民","type":"unit","cost":5,"count":5,"hp":45.0,"damage":9.0,"interval":0.9,"range":47.0,"speed":48.0},
	"hunter":{"name":"獵戶","type":"unit","cost":5,"count":2,"hp":55.0,"damage":10.0,"interval":1.2,"range":170.0,"speed":34.0},
	"healer":{"name":"草藥婆","type":"unit","cost":7,"count":1,"hp":140.0,"damage":6.0,"interval":1.0,"range":120.0,"speed":32.0},
	"ox":{"name":"耕牛","type":"unit","cost":7,"count":1,"hp":420.0,"damage":20.0,"interval":1.2,"range":47.0,"speed":70.0},
	"knight":{"name":"騎士","type":"unit","cost":10,"count":1,"hp":600.0,"damage":40.0,"interval":1.2,"range":47.0,"speed":32.0},
	"ram":{"name":"攻城槌","type":"unit","cost":9,"count":1,"hp":420.0,"damage":60.0,"interval":2.0,"range":47.0,"speed":20.0},
	"mill":{"name":"磨坊","type":"building","cost":10,"hp":700.0,"expires":-1.0},
	"scarecrow":{"name":"稻草人","type":"building","cost":4,"hp":400.0,"expires":25.0},
	"harvest":{"name":"豐收","type":"spell","cost":3,"radius":120.0},
	"fire":{"name":"火罐","type":"spell","cost":8,"radius":90.0,"damage":320.0,"building_damage":640.0,"gate_damage":100.0},
	"farm":{"name":"農田","type":"building","cost":6,"hp":250.0,"expires":-1.0},
	"farmer":{"name":"農民","type":"unit","cost":2,"count":2,"hp":60.0,"damage":6.0,"interval":1.0,"range":47.0,"speed":42.0},
	"militia":{"name":"民兵隊","type":"unit","cost":3,"count":2,"hp":85.0,"damage":13.0,"interval":0.95,"range":47.0,"speed":39.0},
	"tower":{"name":"箭樓","type":"building","cost":7,"hp":500.0,"expires":40.0,"range":200.0,"damage":18.0,"interval":0.8},
	"rain":{"name":"箭雨","type":"spell","cost":6,"radius":110.0,"damage":200.0,"building_damage":60.0,"gate_damage":60.0}
}
const PRESET_NAMES := ["向日葵流","穩健農莊","劫掠隊"]
const PRESETS := [
	["farm","farmer","harvest","mill","scarecrow","tower","militia","rain"],
	["farm","farmer","militia","hunter","knight","scarecrow","tower","rain"],
	["farm","farmer","mob","ox","ram","hunter","fire","scarecrow"]
]
const MILL_BONUS := 1.5
const HARVEST_TIME := 8.0
const HEAL_RADIUS := 120.0
const HEAL_AMOUNT := 12.0
const HEAL_INTERVAL := 1.0
const OX_CHARGE := 120.0
const OX_KNOCKBACK := 30.0
const OX_BUILDING_BONUS := 1.5
const OX_SLOW_SPEED := 30.0
const FIRE_KNOCKBACK := 20.0
const TAUNT_RADIUS := 150.0
