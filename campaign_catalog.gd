extends RefCounted
# Authoring data only: no battle, UI, save files or resource loading.
const B = preload("res://balance.gd")
const DeckStore = preload("res://deck_store.gd")
const CHAPTERS := [
	{"name":"第一章　戰亂與重稅","color":Color("6f8a45")},
	{"name":"第二章　亡靈的契約","color":Color("6a5277")},
	{"name":"第三章　領主同盟","color":Color("963f30")},
]
const STARTER_CARDS := ["farmer","hunter","militia"]
const GOAL := "攻入敵方底線獲勝；敵軍攻入我方底線則失敗。"
const STAGES := [
	{
		"id": "first_farm",
		"chapter": 0,
		"name": "第一塊農田",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 0,
		"enemy_lord": "iron",
		"story": "東邊戰亂不斷，領主加徵重稅。逃荒的人與叛逃民兵流落邊境。",
		"goal": GOAL,
		"deck": ["farmer","hunter","farmer","hunter","militia","farmer","hunter","militia"],
		"enemy_deck": ["bandit","bandit","bandit","bandit","bandit","bandit","bandit","bandit"],
		"active_lanes": [2],
		"buildings": [],
		"allow_duplicates": true,
		"map": Vector2(120,630),
		"rewards": [],
		"enemy_lord_active": false,
		"enemy_camp": true,
		"opening": true,
		"dialogue": false,
	},
	{
		"id": "fifth_drum",
		"chapter": 0,
		"name": "東邊的路稅",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "iron",
		"story": "強盜與叛逃民兵佔住農路，打著收稅的旗號搶糧。",
		"goal": GOAL,
		"deck": ["mob","farmer","hunter","militia","mob","farmer","hunter","militia"],
		"enemy_deck": ["bandit","militia","bandit","militia","bandit","militia","bandit","militia"],
		"active_lanes": [1,2,3],
		"buildings": [[7,1,"tower"],[7,2,"tower"],[7,3,"tower"]],
		"allow_duplicates": true,
		"map": Vector2(195,490),
		"rewards": ["mob","barricade"],
		"enemy_lord_active": false,
		"enemy_camp": true,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "old_bridge",
		"chapter": 0,
		"name": "故鄉木橋",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "iron",
		"story": "截下木橋上的走私車隊，追查糧食與兵器的去向。",
		"goal": GOAL,
		"deck": ["ram","mob","farmer","hunter","militia","ram","hunter","militia"],
		"enemy_deck": ["bandit","militia","hunter","bandit","militia","hunter","bandit","militia"],
		"active_lanes": [0,1,2,3,4],
		"buildings": [[7,2,"tower"]],
		"allow_duplicates": true,
		"map": Vector2(285,610),
		"rewards": ["ram"],
		"enemy_lord_active": false,
		"enemy_camp": true,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "swamp_path",
		"chapter": 1,
		"name": "泥沼亡影",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "underworld",
		"story": "沿運貨名冊進入泥沼，第一次看見亡靈搬運人類打造的兵器。",
		"goal": GOAL,
		"deck": ["rain","ram","mob","farmer","hunter","militia","hunter","rain"],
		"enemy_deck": ["bandit","militia","hunter","skeleton","bandit","militia","hunter","skeleton"],
		"active_lanes": [0,1,3,4],
		"buildings": [],
		"allow_duplicates": true,
		"map": Vector2(370,460),
		"rewards": ["rain"],
		"enemy_lord_active": false,
		"enemy_camp": false,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "abandoned_mill",
		"chapter": 1,
		"name": "磨坊密信",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "underworld",
		"story": "亡靈佔據廢棄磨坊，地窖裡藏著人類管事與死靈法師的接頭信。",
		"goal": GOAL,
		"deck": ["mill","healer","rain","ram","mob","farmer","hunter","militia"],
		"enemy_deck": ["bandit","militia","hunter","skeleton","ghoul","skeleton","ghoul","skeleton"],
		"active_lanes": [1,2,3],
		"buildings": [],
		"map": Vector2(460,590),
		"rewards": ["mill","healer"],
		"enemy_lord_active": false,
		"enemy_camp": false,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "patrol_riders",
		"chapter": 1,
		"name": "墓園契約",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "underworld",
		"story": "在墓園找到有雙方印記的契約：人類以糧食、兵器換取亡靈軍隊。",
		"goal": GOAL,
		"deck": "player",
		"enemy_deck": ["bandit","militia","hunter","skeleton","ghoul","necromancer","skeleton","ghoul"],
		"active_lanes": [0,1,2,3,4],
		"buildings": [],
		"map": Vector2(550,440),
		"rewards": ["scarecrow"],
		"enemy_lord_active": false,
		"enemy_camp": false,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "tavern_brawl",
		"chapter": 2,
		"name": "馳援紅獅",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "underworld",
		"story": "將證據交給紅獅領主，協助他擊退亡靈先鋒。",
		"goal": GOAL,
		"deck": "player",
		"enemy_deck": ["bandit","militia","skeleton","ghoul","necromancer","reaper","bonewall","skeleton"],
		"active_lanes": [0,1,2,3,4],
		"buildings": [[7,2,"bonewall"]],
		"support_lord": "lion",
		"map": Vector2(640,580),
		"rewards": ["knight","drummer","fire"],
		"enemy_lord_active": false,
		"enemy_camp": false,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "beacon_gate",
		"chapter": 2,
		"name": "守護豐收",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "underworld",
		"story": "豐收領主的糧倉遭亡靈包圍，保住糧道，讓援軍繼續前進。",
		"goal": GOAL,
		"deck": "player",
		"enemy_deck": ["bandit","militia","skeleton","ghoul","necromancer","reaper","bonewall","raven"],
		"active_lanes": [1,2,3],
		"buildings": [[7,1,"grave"],[7,3,"grave"]],
		"support_lord": "harvest",
		"map": Vector2(730,430),
		"rewards": ["ox","harvest"],
		"enemy_lord_active": false,
		"enemy_camp": false,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "canal_sluice",
		"chapter": 2,
		"name": "鐵壁之圍",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 1,
		"enemy_lord": "underworld",
		"story": "鐵壁領主守住最後一道關口。打退圍城亡靈，打開進軍冥府的路。",
		"goal": GOAL,
		"deck": "player",
		"enemy_deck": ["militia","skeleton","ghoul","necromancer","reaper","bonewall","raven","corpse_giant"],
		"active_lanes": [0,1,2,3,4],
		"buildings": [[7,0,"bonewall"],[7,4,"bonewall"]],
		"support_lord": "iron",
		"map": Vector2(820,570),
		"rewards": ["shieldguard","tower","catapult"],
		"enemy_lord_active": false,
		"enemy_camp": false,
		"opening": false,
		"dialogue": true,
	},
	{
		"id": "warlord_camp",
		"chapter": 2,
		"name": "冥府王座",
		"lord": "adventure",
		"kind": "conquer",
		"ai": 2,
		"enemy_lord": "underworld",
		"story": "三位領主已牽制亡靈大軍。率領集結的部隊，直取亡靈領主的王座。",
		"goal": GOAL,
		"deck": "player",
		"enemy_deck": ["skeleton","ghoul","necromancer","reaper","raven","corpse_giant","plague","curse"],
		"active_lanes": [0,1,2,3,4],
		"buildings": [[7,1,"grave"],[7,2,"bonewall"],[7,3,"grave"]],
		"map": Vector2(915,360),
		"rewards": [],
		"enemy_lord_active": true,
		"enemy_camp": false,
		"opening": false,
		"dialogue": true,
	},
]

# Returns actionable authoring errors without instantiating a game or touching saves.
static func validate(stages: Array = STAGES) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for value in stages:
		if not value is Dictionary:
			errors.append("stage must be a dictionary")
			continue
		var d: Dictionary = value
		var id: String = str(d.get("id",""))
		if id.is_empty() or ids.has(id): errors.append("duplicate or empty stage id: "+id)
		ids[id] = true
		for key: String in ["name","story","goal","kind"]:
			if not d.get(key) is String or d.get(key,"").is_empty(): errors.append(id+": missing text "+key)
		if d.get("kind") != "conquer": errors.append(id+": unsupported victory kind")
		for key: String in ["opening","dialogue","enemy_camp","enemy_lord_active"]:
			if not d.get(key) is bool: errors.append(id+": missing boolean "+key)
		if not d.get("chapter") is int or not d.get("chapter",-1) in range(CHAPTERS.size()): errors.append(id+": invalid chapter")
		if not d.get("ai") is int or not d.get("ai",-1) in range(3): errors.append(id+": invalid AI difficulty")
		if not d.get("map") is Vector2: errors.append(id+": missing map position")
		var lord: String = str(d.get("lord",""))
		var enemy_lord: String = str(d.get("enemy_lord",""))
		if not B.LORDS.has(lord) or not B.LORDS.has(enemy_lord): errors.append(id+": unknown lord")
		if d.has("support_lord") and not B.LORDS.has(d.support_lord): errors.append(id+": unknown support lord")
		var deck = d.get("deck")
		if not (deck is String and deck == "player") and not (deck is Array and DeckStore.valid(deck,lord,d.get("allow_duplicates",false))): errors.append(id+": invalid player deck")
		if not d.get("enemy_deck") is Array or not DeckStore.valid(d.enemy_deck,enemy_lord,true): errors.append(id+": invalid enemy deck")
		var lanes: Array = d.get("active_lanes",[]) if d.get("active_lanes") is Array else []
		var seen: Dictionary = {}
		if lanes.is_empty(): errors.append(id+": no active lanes")
		for lane in lanes:
			if not lane is int or not lane in range(5) or seen.has(lane): errors.append(id+": invalid or duplicate lane")
			seen[lane] = true
		if not d.get("rewards") is Array:
			errors.append(id+": rewards must be an array")
		else:
			seen = {}
			for card in d.rewards:
				if not card is String or not card in DeckStore.pool(lord) or seen.has(card): errors.append(id+": invalid or duplicate reward "+str(card))
				seen[card] = true
		if not d.get("buildings") is Array:
			errors.append(id+": buildings must be an array")
		else:
			seen = {}
			for b in d.buildings:
				if not b is Array or b.size() != 3:
					errors.append(id+": building needs column, lane and card id")
					continue
				if not b[0] is int or not b[0] in range(9) or not b[1] in lanes: errors.append(id+": building outside active grid")
				if not B.CARDS.has(b[2]) or B.CARDS[b[2]].type != "building" or not B.card_allowed(b[2],enemy_lord): errors.append(id+": invalid building card")
				var cell: String = str(b[0])+":"+str(b[1])
				if seen.has(cell): errors.append(id+": overlapping buildings")
				seen[cell] = true
	return errors
