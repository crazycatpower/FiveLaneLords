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
const MELEE_RANGE := 47.0
const GATE_HP := 600.0
const CASTLE_HP := 2500.0
const MATCH_TIME := 240.0
const OVERTIME := 120.0
const GATE_RANGE := 160.0
const GATE_DAMAGE := 30.0
const GATE_INTERVAL := 1.0
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
 "farm":{"name":"農田","type":"building","cost":6,"hp":250.0,"expires":-1.0},
 "farmer":{"name":"農民","type":"unit","cost":2,"count":2,"hp":60.0,"damage":6.0,"interval":1.0,"range":47.0,"speed":42.0},
 "militia":{"name":"民兵隊","type":"unit","cost":3,"count":2,"hp":85.0,"damage":13.0,"interval":0.95,"range":47.0,"speed":39.0},
 "tower":{"name":"箭樓","type":"building","cost":7,"hp":500.0,"expires":40.0,"range":200.0,"damage":18.0,"interval":0.8},
 "rain":{"name":"箭雨","type":"spell","cost":6,"radius":110.0,"damage":200.0,"building_damage":60.0,"gate_damage":60.0}
}
const PRESETS := [
 ["farm","farmer","militia","tower","rain","militia","farmer","tower"]
]
