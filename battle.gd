extends RefCounted
const DarkSorcery = preload("res://dark_sorcery.gd")
const LordExpansion = preload("res://lord_expansion.gd")
const Arcane = preload("res://arcane_mechanics.gd")
const AI = preload("res://enemy_ai.gd")
const Lord = preload("res://lord.gd")
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
var rng := RandomNumberGenerator.new()
var ink: Array = [B.START_INK,B.START_INK]
var base_clock: Array = [0.0,0.0]
var hand_cd: Array = [[0.0,0.0,0.0,0.0],[0.0,0.0,0.0,0.0]] # seconds until each hand slot may be played
var decks: Array = []
var units: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var territory := PackedInt32Array() # -1 neutral; first owner keeps a tile while supported
var projectiles: Array[Dictionary] = []
var spells: Array[Dictionary] = []
var death_queue: Array[Dictionary] = [] # gameplay queue, independent of visual event recording
var zones: Array[Dictionary] = []
var lords: Array = []
var gates: Array = []
var alarm: Array = [0.0,0.0,0.0,0.0,0.0]
var building_alarm: Array = [0.0,0.0,0.0,0.0,0.0]
var stats: Array = []
var events: Array[Dictionary] = []
var elapsed := 0.0
var vampire_until: Array[float] = [0.0,0.0]
var time_stop_left := 0.0
var time_stop_team := -1
var time_stop_origin := Vector2.ZERO

func time_stopped() -> bool:
	return time_stop_left > 0.000001

func actor_time(actor: Dictionary) -> float:
	return elapsed+float(actor.get("extra_time",0.0))

func step_time_stop(dt: float) -> void:
	var active_dt := minf(dt,time_stop_left)
	if not ended:
		build_lookups()
		var caster: Dictionary = lords[time_stop_team]
		caster.extra_time = caster.get("extra_time",0.0)+active_dt
		if lord_active[time_stop_team]: Lord.step(self,caster,active_dt)
		for u: Dictionary in units.duplicate():
			if u.team != time_stop_team or u.hp <= 0: continue
			u.extra_time = u.get("extra_time",0.0)+active_dt
			if update_unit(u,active_dt): break
		# Death reactions, buildings and all projectiles wait until normal time resumes.
		remove_dead()
	time_stop_left = maxf(0,time_stop_left-active_dt)
	if not time_stopped():
		time_stop_left = 0.0
		time_stop_team = -1
		if dt > active_dt: step(dt-active_dt)
var last_dt := 0.0
var ended := false
# Challenge objectives can hold attackers at the far gate; normal matches keep both sides enabled.
var invasion_victory: Array[bool] = [true,true]
var active_lanes: Array[int] = [0,1,2,3,4]
var winner := -2
var paused := false
var next_id := 0
var ai_enabled: Array = [false,false]
var difficulty := 1
var ai_clock: Array = [0.0,0.0]
var ai_pending: Array = [{},{}]
var ai_delay: Array = [0.0,0.0]
var wave_until: Array = [0.0,0.0]
var memory: Array = [{},{}]
var recent_lanes: Array = [[],[]] # lanes of each side's last troop plays, for the AI to spread its attacks
var ai_start := 0.0
var lord_active: Array = [true,true] # the tutorial keeps the blue lord idle
var first_breach := -1.0 # seconds into the match when the first gate fell (-1 = never)
var serials_in_use: Dictionary = {} # 序號 currently held by a living unit or building
var record_events := true # batch simulators turn this off; no game logic reads events
# Per-step lookup lists, rebuilt after the AI plays (same order as units/buildings, so every
# "nearest" search sees the candidates in the same order as a scan of the full list would).
var foe_units: Array = [[],[]] # foe_units[team]: units of the other side
var lane_foes: Array = [] # lane_foes[team][lane]: enemy units in that lane
var lane_foe_buildings: Array = []
var lane_foe_taunts: Array = []
var lane_mill: Array = [] # lane_mill[team][lane]: a living mill boosts that lane's farms

# Hand slots 0..3 rotate; FARM_SLOT is the permanent farmland slot (never rotates, own cooldown).
const FARM_SLOT := 4
var farm_cd: Array = [0.0,0.0]
var home_cards: Array = ["farm","farm"] # each side's F-slot card, fixed by its lord at the start
var skill_cd: Array = [B.SKILL_OPENING_COOLDOWN,B.SKILL_OPENING_COOLDOWN] # lord skill cooldown per side
var ai_save: Array = [false,false] # the AI is holding gold for its lord's skill
var ai_params: Array = [{},{}] # per-side AI strategy weights (enemy_ai.gd; {} = the hand-written defaults)
var team_drum_until: Array = [0.0,0.0] # active until timestamp for drummer whole-field speed boost

func _init(seed_value: int = 1, deck_a: Array = [], deck_b: Array = [], lord_a: String = "", lord_b: String = "") -> void:
	territory.resize(L.GRID_COLUMNS*L.GRID_ROWS)
	territory.fill(-1)
	for team: int in range(2):
		for lane: int in range(L.GRID_ROWS):
			claim_around(team,Vector2i(-1 if team == 0 else L.GRID_COLUMNS,lane))
	rng.seed = seed_value
	for team: int in range(2):
		var deck: Array = (deck_a if team == 0 else deck_b).duplicate()
		if deck.is_empty(): deck = B.PRESETS[0].duplicate()
		for i: int in range(deck.size()-1,0,-1):
			var j := rng.randi_range(0,i)
			var swap = deck[i]
			deck[i] = deck[j]
			deck[j] = swap
		var lord_kind: String = lord_a if team == 0 else lord_b
		if lord_kind.is_empty(): lord_kind = "lion" # neutral default when no lord is chosen
		lords.append(Lord.create(team,lord_kind))
		home_cards[team] = B.home_card(lord_kind)
		decks.append(deck)
		gates.append([B.GATE_HP,B.GATE_HP,B.GATE_HP,B.GATE_HP,B.GATE_HP])
		stats.append({"produced":0.0,"wasted":0.0,"planted":0,"burned":0,"plays":0,"used":{},"damage":{},"spent":{},"cultivated":0,"drops":0,"farms_lost_early":0})
	# Both sides start with two of their home buildings (farms, or tombstones for the underworld lord);
	# they are not counted as planted.
	for team: int in range(2):
		for cell: Vector2i in B.START_FARMS:
			add_building(team,Vector2i(cell.x if team == 0 else 8-cell.x,cell.y),home_cards[team])
		stats[team].planted = 0

# A visible tie between a cause and what it affects: a death feeding a tombstone or a ghoul, a
# necromancer raising a skeleton, a herbalist healing, 豐收 doubling a farm. Drawing only.
func link(from: Vector2, to: Vector2, team: int, style: String) -> void:
	event("link",from,team,{"to":to,"style":style})

func event(kind: String, pos: Vector2, team: int = 0, extra: Dictionary = {}) -> void:
	if not record_events: return
	var e := {"kind":kind,"pos":pos,"team":team,"time":elapsed}
	e.merge(extra)
	events.append(e)

func cell_at(pos: Vector2) -> Vector2i:
	if not Rect2(L.GRID_ORIGIN,L.GRID_SIZE).has_point(pos): return Vector2i(-1,-1)
	return Vector2i((pos-L.GRID_ORIGIN)/L.CELL_SIZE)

func territory_owner(cell: Vector2i) -> int:
	if not cell.y in active_lanes: return -1
	if cell.x < 0 or cell.x >= L.GRID_COLUMNS or cell.y < 0 or cell.y >= L.GRID_ROWS: return -1
	return territory[cell.y*L.GRID_COLUMNS+cell.x]

func claim_around(team: int, center: Vector2i) -> void:
	# Include the building's own tile, plus its eight neighbours; never overwrite ownership.
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			var cell := center+Vector2i(dx,dy)
			if cell.x < 0 or cell.x >= L.GRID_COLUMNS or cell.y < 0 or cell.y >= L.GRID_ROWS: continue
			var index := cell.y*L.GRID_COLUMNS+cell.x
			if territory[index] == -1: territory[index] = team

func refresh_territory() -> void:
	# Keep the current owner while any living allied structure supports the tile.
	# Otherwise the oldest surviving claimant takes over, or the tile becomes neutral.
	for row: int in range(L.GRID_ROWS):
		for col: int in range(L.GRID_COLUMNS):
			var support := 0
			var first := -1
			for team: int in range(2):
				if col != (0 if team == 0 else L.GRID_COLUMNS-1): continue
				for lane: int in range(maxi(0,row-1),mini(L.GRID_ROWS,row+2)):
					if gates[team][lane] > 0:
						support |= 1 << team
						if first < 0: first = team
			for b: Dictionary in buildings:
				if b.hp <= 0 or absi(b.cell.x-col) > 1 or absi(b.cell.y-row) > 1: continue
				support |= 1 << int(b.team)
				if first < 0: first = b.team
			var index := row*L.GRID_COLUMNS+col
			var owner := territory[index]
			if owner < 0 or (support & (1 << owner)) == 0: territory[index] = first

func front_column(team: int, lane: int) -> int:
	for distance: int in range(L.GRID_COLUMNS-1,-1,-1):
		var col := distance if team == 0 else L.GRID_COLUMNS-1-distance
		if territory_owner(Vector2i(col,lane)) == team: return col
	return -1

func count_buildings(team: int, kind: String = "farm") -> int:
	var n := 0
	for b: Dictionary in buildings:
		if b.hp > 0 and b.team == team and b.kind == kind: n += 1
	return n

func building_at(cell: Vector2i) -> Dictionary:
	for b: Dictionary in buildings:
		if b.hp > 0 and b.cell == cell: return b
	return {}

func multiplier() -> float:
	return 2.0 if elapsed >= B.RAMP_2 else (1.5 if elapsed >= B.RAMP_1 else 1.0)

func production_rate(team: int) -> float:
	var rate := 1.0/B.BASE_INTERVAL
	for b: Dictionary in buildings:
		if b.team == team and b.hp > 0 and b.kind == "farm": rate += B.FARM_DROP/B.FARM_INTERVAL*farm_speed(b)
	var crystal_rate := 0.0
	for b: Dictionary in buildings:
		if b.team == team and b.hp > 0 and b.kind == "crystal": crystal_rate += B.CARDS.crystal.income/Arcane.crystal_period(b)
	return crystal_rate+rate*multiplier()+count_buildings(team,"grave")*B.CARDS.grave.income/B.CARDS.grave.period

func gain_ink(team: int, amount: float) -> void:
	stats[team].produced += amount
	var waste: float = maxf(0,ink[team]+amount-B.MAX_INK)
	stats[team].wasted += waste
	ink[team] = minf(B.MAX_INK,ink[team]+amount)
	if waste > 0: event("overflow",L.GOLD_TEXT,team)

func farm_speed(b: Dictionary) -> float:
	# One mill per lane counts; a second mill in the same lane does not stack (but any lane may have one,
	# so the card is never stuck in hand).
	var mill := false
	for other: Dictionary in buildings:
		if other.kind == "mill" and other.hp > 0 and other.team == b.team and other.cell.y == b.cell.y:
			mill = true
			break
	return farm_speed_with(b,mill)

func farm_speed_with(b: Dictionary, mill: bool) -> float:
	var speed := 2.0 if maxf(b.boost_until,b.harvest_until) > elapsed else 1.0
	if mill: speed *= B.MILL_BONUS
	return speed

func build_lookups() -> void:
	foe_units = [[],[]]
	lane_foes = [[[],[],[],[],[]],[[],[],[],[],[]]]
	lane_foe_buildings = [[[],[],[],[],[]],[[],[],[],[],[]]]
	lane_foe_taunts = [[[],[],[],[],[]],[[],[],[],[],[]]]
	lane_mill = [[false,false,false,false,false],[false,false,false,false,false]]
	for u: Dictionary in units:
		var against: int = 1-u.team
		foe_units[against].append(u)
		lane_foes[against][u.lane].append(u)
	for b: Dictionary in buildings:
		var against: int = 1-b.team
		if not B.CARDS[b.kind].has("trap"): lane_foe_buildings[against][b.cell.y].append(b)
		if b.kind == "scarecrow": lane_foe_taunts[against][b.cell.y].append(b)
		elif b.kind == "mill" and b.hp > 0: lane_mill[b.team][b.cell.y] = true

func farm_drop(b: Dictionary) -> void:
	gain_ink(b.team,B.FARM_DROP)
	stats[b.team].drops += 1
	event("ink",b.pos,b.team)

func kind_at(team: int, slot: int) -> String:
	return home_cards[team] if slot == FARM_SLOT else decks[team][slot]

func slot_cd(team: int, slot: int) -> float:
	return farm_cd[team] if slot == FARM_SLOT else hand_cd[team][slot]

# Placement rules live in one place: play_check() says why a card cannot go here (Refusal.OK = it
# can). can_play() is the cheap yes/no the AI asks hundreds of times per decision; play_error()
# turns the reason into the sentence the player sees.
enum Refusal {OK, ENDED, PAUSED, NO_CARD, COOLDOWN, GOLD, OFF_GRID, NOT_OURS, OCCUPIED}

func play_check(team: int, slot: int, pos: Vector2) -> Refusal:
	if time_stopped(): return Refusal.PAUSED
	if ended: return Refusal.ENDED
	if paused: return Refusal.PAUSED
	if (slot < 0 or slot >= 4) and slot != FARM_SLOT: return Refusal.NO_CARD
	var kind: String = kind_at(team,slot)
	if kind.is_empty() or not B.CARDS.has(kind): return Refusal.NO_CARD
	var card: Dictionary = B.CARDS[kind]
	if card.get("summon_only",false): return Refusal.NO_CARD
	if slot_cd(team,slot) > 0.00001: return Refusal.COOLDOWN
	if ink[team] < card.cost: return Refusal.GOLD
	if card.type == "spell":
		var lane := int((pos.y-L.GRID_ORIGIN.y)/L.CELL_SIZE.y)
		if not lane in active_lanes or pos.x < L.FIELD_FRAME.position.x or pos.x > L.FIELD_FRAME.end.x:
			return Refusal.OFF_GRID
		return Refusal.OK
	var cell := cell_at(pos)
	if cell.x < 0 or not cell.y in active_lanes: return Refusal.OFF_GRID
	if territory_owner(cell) != team: return Refusal.NOT_OURS
	if card.type == "building":
		var here := building_at(cell)
		if not here.is_empty() and (here.team != team or here.kind != kind): return Refusal.OCCUPIED
	return Refusal.OK

func can_play(team: int, slot: int, pos: Vector2) -> bool:
	return play_check(team,slot,pos) == Refusal.OK

# Why a card cannot go here ("" = it can). The player sees this text when a placement is refused.
func play_error(team: int, slot: int, pos: Vector2) -> String:
	var why := play_check(team,slot,pos)
	match why:
		Refusal.OK: return ""
		Refusal.ENDED: return "戰局已經結束。"
		Refusal.PAUSED: return "暫停中。"
		Refusal.NO_CARD: return "先選一張手牌。"
		Refusal.OFF_GRID: return "要放在戰場的格子上。"
		Refusal.NOT_OURS: return "只能部署在我方領地；建築與城牆周圍八格可擴張，先佔先得。"
		Refusal.OCCUPIED: return "這格已經有別的建築；只有同一種建築可以覆蓋回血。"
	var card: Dictionary = B.CARDS[kind_at(team,slot)]
	if why == Refusal.COOLDOWN: return "%s 還要冷卻 %.1f 秒。" % [card.name,slot_cd(team,slot)]
	return "金幣不足：%s 要 %d，還差 %d。" % [card.name,card.cost,ceili(card.cost-ink[team])]

func play(team: int, slot: int, pos: Vector2) -> bool:
	if not can_play(team,slot,pos): return false
	var kind: String = kind_at(team,slot)
	var card: Dictionary = B.CARDS[kind]
	ink[team] -= card.cost
	if slot == FARM_SLOT: farm_cd[team] = card.cooldown # the farmland slot never rotates
	else:
		# Replace only the played slot; the other three cards and cooldowns stay put.
		decks[team][slot] = decks[team][4]
		decks[team].remove_at(4)
		decks[team].append(kind)
		hand_cd[team][slot] = B.CARDS[decks[team][slot]].cooldown
	stats[team].plays += 1
	stats[team].used[kind] = stats[team].used.get(kind,0)+1
	stats[team].spent[kind] = stats[team].spent.get(kind,0.0)+card.cost
	var cell := cell_at(pos)
	if card.type == "building":
		var here := building_at(cell)
		if here.is_empty(): add_building(team,cell,kind)
		else: refresh_building(here)
	elif card.type == "unit": deploy(team,kind,cell)
	else: spells.append({"kind":kind,"team":team,"pos":pos,"delay":B.SPELL_DELAY})
	memory[1-team] = {"card":kind,"lane":cell.y if cell.y in active_lanes else clampi(int((pos.y-L.GRID_ORIGIN.y)/L.CELL_SIZE.y),0,4)}
	if card.type == "unit":
		recent_lanes[team].append(cell.y)
		if recent_lanes[team].size() > 3: recent_lanes[team].pop_front()
	event("play",pos,team,{"card":kind,"slot":slot})
	return true

func add_building(team: int, cell: Vector2i, kind: String) -> Dictionary:
	claim_around(team,cell)
	next_id += 1
	var data: Dictionary = B.CARDS[kind]
	var b := {"id":next_id,"serial":take_serial(),"kind":kind,"team":team,"cell":cell,"pos":L.cell_center(cell),"hp":data.hp,"max_hp":data.hp,"expires":elapsed+data.expires if data.expires > 0 else -1.0,"boost_until":0.0,"harvest_until":0.0,"ready_at":elapsed+B.FARM_START,"production":0.0,"cd":0.0,"flash":0.0}
	buildings.append(b)
	if data.has("charges"): b.charges = data.charges
	if kind == "farm": stats[team].planted += 1
	return b

# Placing the same building on our own one restores it: full health and a fresh lifetime.
# A farm keeps its production timer and any cultivation boost.
func refresh_building(b: Dictionary) -> void:
	var data: Dictionary = B.CARDS[b.kind]
	b.hp = b.max_hp
	if data.has("charges"): b.charges = data.charges
	if data.expires > 0: b.expires = elapsed+data.expires
	if b.kind == "bonewall": b.thresholds_spawned = 0
	stats[b.team].repairs = stats[b.team].get("repairs",0)+1
	event("heal",b.pos,b.team)

# Fields a unit card: one troop type, a mixed legion ("members"), or the same squad in three
# adjacent lanes ("spread"; shifted inward at the edge lanes). Troops behind the front stand back.
func deployment_column(team: int, lane: int, requested: int) -> int:
	var direction := -1 if team == 0 else 1
	var col := requested
	while col >= 0 and col < L.GRID_COLUMNS:
		if territory_owner(Vector2i(col,lane)) == team: return col
		col += direction
	return front_column(team,lane)

func deploy(team: int, kind: String, cell: Vector2i) -> void:
	var card: Dictionary = B.CARDS[kind]
	var groups: Array = card.get("members",[[kind,card.get("count",1),0.0]])
	var front_offset := 0.0
	for group: Array in groups: front_offset = minf(front_offset,group[2])
	var lanes: Array = [cell.y]
	if card.get("spread",false):
		var middle := clampi(cell.y,1,3)
		lanes = [middle-1,middle,middle+1]
	var forward := 1.0 if team == 0 else -1.0
	# A mixed legion keeps formation: everyone marches at the slowest member's pace.
	var march := INF
	if groups.size() > 1:
		for group: Array in groups: march = minf(march,B.CARDS[group[0]].speed)
	for lane: int in lanes:
		if not lane in active_lanes: continue
		var col := deployment_column(team,lane,cell.x)
		if col < 0: continue
		# Place squads at the rear of the selected cell, mirrored for blue, so enemies
		# inside that cell remain in front of the freshly deployed interceptors.
		var spot := L.cell_center(Vector2i(col,lane))-Vector2(forward*(L.CELL_SIZE.x*0.5-12.0),0)
		# Each lane counts its own spawn order, so a three-lane squad steps out in all lanes at once.
		var n := 0
		for group: Array in groups:
			for i: int in range(group[1]):
				var spawn_pos := spot-Vector2(forward*(group[2]-front_offset),0)
				spawn_pos.x = clampf(spawn_pos.x,L.GRID_ORIGIN.x+12.0,L.GRID_ORIGIN.x+L.GRID_SIZE.x-12.0)
				var u := spawn_unit(team,lane,group[0],spawn_pos)
				u.spawn_delay = n*0.12
				u.card = kind
				if march < INF: u.march = march
				n += 1

func spawn_unit(team: int, lane: int, kind: String, pos: Vector2) -> Dictionary:
	if not lane in active_lanes:
		lane = active_lanes[0]
		pos.y = L.cell_center(Vector2i(0,lane)).y
	next_id += 1
	var data: Dictionary = B.CARDS[kind]
	var u := {"id":next_id,"serial":take_serial(),"kind":kind,"team":team,"lane":lane,"pos":pos,"hp":data.hp,"max_hp":data.hp,"cd":0.0,"phase":rng.randf()*TAU,"face":1.0 if team == 0 else -1.0,"worked":[],"work_id":-1,"work_left":0.0,"spawn_delay":0.0,"charged":false,"flash":0.0,"heal_cd":0.0,"dy":rng.randf_range(-B.PLACE_JITTER,B.PLACE_JITTER)}
	units.append(u)
	u.phased = data.get("phase",false)
	u.stealthed = data.get("stealth",false) or u.phased
	u.flying = data.get("flying",false)
	u.armor = data.get("armor",0.0)
	u.summon_left = 0.0 # a summoner raises its first skeletons as soon as it is on the field
	if kind == "drummer":
		u.drum_cd = data.get("inspire_period",10.0)
		trigger_drum(u)
	return u

func trigger_drum(u: Dictionary) -> void:
	var dur: float = B.CARDS.drummer.get("inspire_duration",3.0)
	team_drum_until[u.team] = maxf(team_drum_until[u.team],elapsed+dur)
	event("drum",u.pos,u.team,{"duration":dur})

func damage(target: Dictionary, amount: float, team: int, kind: String, source: Dictionary = {}, sacrifice: bool = false) -> void:
	if target.hp <= 0: return
	if amount <= 0: return
	if not target.get("phased",false): target.stealthed = false
	if not sacrifice:
		amount *= 1.0-Arcane.resonance(self,target)
		if target.get("armor",0.0) > 0: amount = maxf(1.0,amount-target.armor)
	var dealt := minf(amount,target.hp)
	target.hp -= amount
	if not sacrifice:
		LordExpansion.drain(self,source,dealt,target.pos)
		Arcane.blink(self,target)
	if target.kind == "lord":
		target.last_hit = elapsed
		if target.hp <= 0: target.respawn = B.LORD_RESPAWN
	target.flash = 0.08
	if target.kind == "bonewall":
		var hp_lost: float = target.max_hp - maxf(0.0, target.hp)
		var threshold_reached: int = clampi(int(hp_lost / (target.max_hp * 0.2)), 0, 5)
		var spawned: int = target.get("thresholds_spawned", 0)
		while spawned < threshold_reached:
			spawned += 1
			var forward := 1.0 if target.team == 0 else -1.0
			var spawn_pos: Vector2 = target.pos - Vector2(forward * 45.0, 0.0)
			spawn_pos.x = clampf(spawn_pos.x, L.GRID_ORIGIN.x, L.GRID_ORIGIN.x + L.GRID_SIZE.x)
			var skel := spawn_unit(target.team, target.cell.y, "skeleton", spawn_pos)
			skel.card = "bonewall"
			event("summoned", skel.pos, skel.team)
			link(target.pos, skel.pos, target.team, "summon")
		target.thresholds_spawned = spawned
	if not sacrifice: stats[team].damage[kind] = stats[team].damage.get(kind,0.0)+dealt
	event("hit",target.pos,target.team)
	if target.hp <= 0 and not sacrifice: DarkSorcery.rescue(self,target)
	if target.has("cell") and target.team == 0: building_alarm[target.cell.y] = 1.5
	if target.hp <= 0:
		if target.has("serial"):
			serials_in_use.erase(target.serial)
			# Clear the released number: later cleanup must not free a number reused by a summon.
			var old_serial: int = target.serial
			target.serial = 0
			if not target.has("cell"):
				if B.CARDS[target.kind].has("resonance"):
					death_queue.append({"explosion":true,"pos":target.pos,"team":target.team,"kind":target.kind})
				death_queue.append({"lane":target.lane,"pos":target.pos,"team":target.team,"kind":target.kind,"serial":old_serial,"poison_team":team if kind == "plague" else -1,"curse_team":target.get("curse_team",-1) if (target.get("cursed",false) or target.get("cursed_until",0.0) > elapsed) else -1,"spawn":B.CARDS[target.kind].get("on_death_spawn",[]),"card":target.get("card",target.kind)})
		if target.has("cell"): refresh_territory()
		if target.kind == "farm" and elapsed < 180.0: stats[target.team].farms_lost_early += 1
		var art_kind: String = "lord_"+target.lord if target.kind == "lord" else target.kind
		var face: float = target.get("face",1.0 if target.team == 0 else -1.0)
		if target.has("cell"): face = 1.0
		var visual_pos: Vector2 = target.pos+Vector2(0,target.get("dy",0.0))
		event("death",visual_pos,target.team,{"card":target.kind,"art_kind":art_kind,"face":face})
		if target.kind == "farm" and kind == "fire":
			stats[target.team].burned += 1
			event("burn",target.pos,target.team)

func hit_gate(side: int, lane: int, amount: float, kind: String = "militia", source: Dictionary = {}) -> void:
	if gates[side][lane] <= 0: return # already open; the attackers just walk in
	var dealt: float = minf(gates[side][lane],amount)
	gates[side][lane] = maxf(0,gates[side][lane]-amount)
	LordExpansion.drain(self,source,dealt,Vector2(L.gate_stop(side),L.cell_center(Vector2i(0,lane)).y))
	if gates[side][lane] == 0: refresh_territory()
	if gates[side][lane] == 0 and first_breach < 0: first_breach = elapsed
	if gates[side][lane] == 0: event("breach",Vector2(L.gate_icon_x(side),L.cell_center(Vector2i(0,lane)).y),1-side,{"lane":lane})
	stats[1-side].damage[kind] = stats[1-side].damage.get(kind,0.0)+dealt
	if side == 0: alarm[lane] = 1.5

func grave_drop(b: Dictionary) -> void:
	b.production = 0.0 # death acceleration never carries over into the next cycle
	gain_ink(b.team,B.CARDS.grave.income)
	event("ink",b.pos,b.team)

func add_zone(pos: Vector2, team: int, radius: float, duration: float) -> void:
	zones.append({"pos":pos,"team":team,"radius":radius,"left":duration,"tick":B.CARDS.plague.tick_interval})

func update_zones(dt: float) -> void:
	for zone: Dictionary in zones.duplicate():
		var active := minf(dt,zone.left)
		zone.left -= dt
		zone.tick -= active
		while zone.tick <= 0.000001:
			zone.tick += B.CARDS.plague.tick_interval
			for u: Dictionary in units:
				if u.hp > 0 and u.team != zone.team and u.pos.distance_to(zone.pos) <= zone.radius:
					damage(u,B.CARDS.plague.tick_damage,zone.team,"plague")
		for u: Dictionary in units:
			if u.hp > 0 and u.team != zone.team and u.pos.distance_to(zone.pos) <= zone.radius:
				u.in_poison_zone = true
				u.poison_remaining = 2
				u.poison_team = zone.team
				u.poison_timer = B.CARDS.plague.tick_interval
	zones = zones.filter(func(z: Dictionary) -> bool: return z.left > 0.000001)

	for u: Dictionary in units:
		if u.hp <= 0: continue
		if u.get("in_poison_zone",false):
			u.in_poison_zone = false
			continue
		if u.get("poison_remaining",0) > 0:
			u.poison_timer = u.get("poison_timer",B.CARDS.plague.tick_interval)-dt
			while u.poison_timer <= 0.000001 and u.poison_remaining > 0:
				u.poison_timer += B.CARDS.plague.tick_interval
				u.poison_remaining -= 1
				damage(u,B.CARDS.plague.tick_damage,u.poison_team,"plague")
				if u.hp <= 0: break
			if u.poison_remaining <= 0:
				u.poison_remaining = 0
				u.poison_team = -1

func resolve_deaths() -> void:
	# Append-only during processing: explosions may add more deaths, in deterministic order.
	var index := 0
	while index < death_queue.size():
		var dead: Dictionary = death_queue[index]
		index += 1
		if dead.get("explosion",false):
			var explosion_kind: String = dead.get("kind","bonewall")
			var explosion: Dictionary = B.CARDS[explosion_kind]
			for u: Dictionary in units:
				if u.hp > 0 and u.team != dead.team and u.pos.distance_to(dead.pos) <= explosion.radius:
					damage(u,explosion.explosion_damage,dead.team,explosion_kind)
			event("boneburst",dead.pos,dead.team)
			continue
		for b: Dictionary in buildings:
			if b.hp > 0 and b.kind == "grave" and b.cell.y == dead.lane:
				link(dead.pos,b.pos,b.team,"soul")
				b.production += B.CARDS.grave.death_advance
				if b.production >= B.CARDS.grave.period: grave_drop(b)
		for u: Dictionary in units:
			if u.hp <= 0 or u.kind != "ghoul" or u.pos.distance_to(dead.pos) > B.CARDS.ghoul.radius: continue
			link(dead.pos,u.pos,u.team,"devour")
			u.hp = minf(u.max_hp,u.hp+B.CARDS.ghoul.devour_heal)
			var tier_index: int = B.TIERS.damage.find(u.get("damage",B.CARDS.ghoul.damage))
			u.damage = B.TIERS.damage[maxi(B.tier_index(B.CARDS.ghoul.max_damage_tier),tier_index-1)]
			event("heal",u.pos,u.team)
		if dead.poison_team >= 0:
			add_zone(dead.pos,dead.poison_team,B.CARDS.plague.spread_radius,B.CARDS.plague.spread_duration)
		# Resolve after the original death fed the economy; the new troops are independent.
		if not dead.spawn.is_empty():
			for i: int in range(dead.spawn[1]):
				var child := spawn_unit(dead.team,dead.lane,dead.spawn[0],dead.pos)
				child.card = dead.card
				event("summoned",child.pos,child.team)
		if dead.curse_team >= 0:
			var child := spawn_unit(dead.curse_team,dead.lane,"skeleton",dead.pos)
			child.card = "curse"
			event("summoned",child.pos,child.team)
			event("curse_rise",child.pos,child.team)
			link(dead.pos,child.pos,dead.curse_team,"curse")
	death_queue.clear()

func reaper_target(u: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for other: Dictionary in lane_foes[u.team][u.lane]+lane_foe_buildings[u.team][u.lane]:
		if other.hp <= 0 or other.get("stealthed",false) or u.pos.distance_to(other.pos) > B.CARDS.reaper.range: continue
		if (other.pos.x-u.pos.x)*u.face < 0: continue
		if found.is_empty() or other.serial < found.serial: found = other
	if found.is_empty():
		var forward_lords: Array = lords.filter(func(l: Dictionary) -> bool: return (l.pos.x-u.pos.x)*u.face >= 0)
		return nearest(u.pos,u.team,54.0,forward_lords)
	return found

# Why the lord's skill cannot be cast now ("" = it can).
func skill_error(team: int) -> String:
	if time_stopped(): return "時間凍結中。"
	if ended: return "戰局已經結束。"
	if paused: return "暫停中。"
	var info: Dictionary = B.LORDS[lords[team].lord]
	if lords[team].hp <= 0: return "領主倒下了，復活後才能發動%s。" % info.skill
	if skill_cd[team] > 0.00001: return "%s還要冷卻 %d 秒。" % [info.skill,ceili(skill_cd[team])]
	if lords[team].lord == "underworld" and count_buildings(team,"grave") == 0: return "沒有墓碑"
	if lords[team].lord == "rune" and LordExpansion.rune_cells(self,team).is_empty(): return "領地內沒有可召喚法陣的空格。"
	var cost := B.skill_cost(lords[team].lord)
	if ink[team] < cost: return "金幣不足：%s要 %d，還差 %d。" % [info.skill,int(cost),ceili(cost-ink[team])]
	return ""

func cast_skill(team: int) -> bool:
	if not skill_error(team).is_empty(): return false
	ink[team] -= B.skill_cost(lords[team].lord)
	skill_cd[team] = B.SKILL_COOLDOWN
	var kind: String = lords[team].lord
	stats[team].skills = stats[team].get("skills",0)+1
	var visual_targets: Array[Vector2] = []
	match kind:
		"rune": visual_targets = LordExpansion.cast_runes(self,team)
		"vampire":
			vampire_until[team] = elapsed+B.LORDS.vampire.blood_duration
			for u: Dictionary in units:
				if u.team == team and u.hp > 0: visual_targets.append(u.pos)
		"mage":
			time_stop_team = team
			time_stop_left = B.LORDS.mage.freeze_duration
			time_stop_origin = lords[team].pos
		"underworld":
			for b: Dictionary in buildings:
				if b.hp <= 0 or b.team != team or b.kind != "grave": continue
				for i: int in range(B.LORDS.underworld.summon_count):
					var u := spawn_unit(team,b.cell.y,"skeleton",b.pos)
					u.card = "skill"
					u.spawn_delay = i*0.12
				if record_events: visual_targets.append(b.pos)
		"adventure":
			preload("res://hero_slash.gd").cast(self,team)
		"lion":
			# One knight per lane spawned from home gate, marching slowly.
			for lane: int in active_lanes:
				var gate_cell := Vector2i(0 if team == 0 else L.GRID_COLUMNS - 1, lane)
				if territory_owner(gate_cell) != team: continue
				var u := spawn_unit(team,lane,"knight",L.spawn_position(team,lane))
				u.card = "skill"
				u.march = B.LION_KNIGHT_SPEED
				if record_events: visual_targets.append(u.pos)
		"harvest":
			# A farm in each lane (front-most free home cell), then every farm healed (no extra yield).
			for lane: int in active_lanes:
				for col: int in range(L.GRID_COLUMNS):
					var cell := Vector2i(col if team == 0 else 8-col,lane)
					if territory_owner(cell) == team and building_at(cell).is_empty():
						add_building(team,cell,"farm")
						break
			for b: Dictionary in buildings:
				if b.team == team and b.kind == "farm" and b.hp > 0:
					b.hp = b.max_hp
					if record_events: visual_targets.append(b.pos)
		"iron":
			# Every gate back to full; attackers already clearing rubble must start over.
			for lane: int in active_lanes:
				gates[team][lane] = B.GATE_HP
				claim_around(team,Vector2i(-1 if team == 0 else L.GRID_COLUMNS,lane))
				if record_events: visual_targets.append(Vector2(L.gate_icon_x(team),L.cell_center(Vector2i(0,lane)).y))
			for u: Dictionary in units:
				if u.team != team: u.climb = 0.0
	event("skill",lords[team].pos,team,{"lord":kind,"targets":visual_targets})
	return true

func finish(side: int) -> void:
	ended = true
	winner = side
	event("finish",Vector2(800,450),side)

# Serial numbers (序號, producer 2026-10-30), like Plants vs. Zombies: every unit and building gets
# the lowest serial no living thing holds (one pool for both sides); when it dies its serial is free
# again for the next one. "id" stays unique for the whole match and is only for bookkeeping.
# At the same distance (within SERIAL_TIE px) the higher serial is attacked first.
const SERIAL_TIE := 0.5

func take_serial() -> int:
	var n := 1
	while serials_in_use.has(n): n += 1
	serials_in_use[n] = true
	return n

func nearest(pos: Vector2, team: int, radius: float, candidates: Array, lane: int = -1, can_hit_flying: bool = true) -> Dictionary:
	var found: Dictionary = {}
	var best := radius
	for other: Dictionary in candidates:
		if other.team == team or other.hp <= 0 or other.get("stealthed",false): continue
		if not can_hit_flying and other.get("flying",false): continue
		if lane >= 0 and other.get("lane",other.get("cell",Vector2i(-1,-1)).y) != lane: continue
		var d := pos.distance_to(other.pos)
		if d > radius: continue
		if found.is_empty() or d < best-SERIAL_TIE or (d <= best+SERIAL_TIE and other.get("serial",-1) > found.get("serial",-1)):
			found = other
			best = minf(best,d) if absf(d-best) <= SERIAL_TIE else d
	return found

# Movement and attacks share frontmost-then-nearest priority.
func lord_target(lord: Dictionary) -> Dictionary:
	return Lord.AI.select_target(lord,units,B.LORD_RANGE)

func attack(u: Dictionary, target: Dictionary) -> void:
	Arcane.reveal(self,u)
	var data: Dictionary = B.CARDS[u.kind]
	var amount: float = u.get("damage",data.damage)
	if u.kind == "ox":
		if not u.charged:
			amount = B.OX_CHARGE
			u.charged = true
			if not target.has("cell"): target.pos.x += u.face*B.OX_KNOCKBACK
		if target.has("cell"): amount *= B.OX_BUILDING_BONUS
	if data.has("stun_on_hit"): Arcane.area_hit(self,u,target.pos)
	elif data.get("pierce",false): Arcane.shoot_piercing_arrow(self,u,target)
	elif data.get("projectile",false): shoot(u,target,amount)
	else: damage(target,amount,u.team,u.get("card",u.kind),u)
	if data.get("splash","") == "column": column_slash(u,target,amount)
	u.cd = attack_interval(u)

# A vertical slash: every other enemy troop in the target's column, in this lane and the two lanes
# next to it, takes the same hit.
func column_slash(u: Dictionary, target: Dictionary, amount: float) -> void:
	var x: float = target.pos.x
	for other: Dictionary in foe_units[u.team]:
		if other.hp <= 0 or is_same(other,target) or absi(other.lane-u.lane) > 1 or absf(other.pos.x-x) > L.CELL_SIZE.x*0.5: continue
		damage(other,amount,u.team,u.get("card",u.kind),u)
	event("slash",Vector2(x,L.cell_center(Vector2i(0,u.lane)).y),u.team,{"lane":u.lane})

func shoot(source: Dictionary, target: Dictionary, amount: float) -> void:
	var direction: float = signf(target.pos.x-source.pos.x)
	var origin: Vector2 = source.get("draw",source.pos+Vector2(0,source.get("dy",0.0)))+Vector2(direction*16,-30 if not source.has("cell") else -42)
	projectiles.append({"source":source,"direction":direction,"pos":origin,"start":origin,"target":target,"remaining":B.ARROW_TIME,"amount":amount,"team":source.team,"kind":source.get("card",source.kind)})
	event("arrow",source.pos,source.team)

func update_projectiles(dt: float) -> void:
	for arrow: Dictionary in projectiles:
		arrow.remaining -= dt
		if arrow.get("piercing",false):
			Arcane.advance_piercing_arrow(self,arrow)
			continue
		if arrow.has("impact"):
			arrow.pos = arrow.start.lerp(arrow.impact,clampf(1-arrow.remaining/arrow.flight,0,1))
			if arrow.remaining <= 0:
				for u: Dictionary in units:
					if u.hp > 0 and u.team != arrow.team and u.pos.distance_to(arrow.impact) <= arrow.radius: damage(u,arrow.amount,arrow.team,arrow.kind,arrow.get("source",{}))
				for b: Dictionary in buildings:
					if b.hp > 0 and b.team != arrow.team and b.pos.distance_to(arrow.impact) <= arrow.radius: damage(b,arrow.amount,arrow.team,arrow.kind,arrow.get("source",{}))
				event("stone_impact",arrow.impact,arrow.team,{"radius":arrow.radius})
			continue
		arrow.pos = arrow.start.lerp(arrow.target.get("draw",arrow.target.pos)+Vector2(0,-30),clampf(1-arrow.remaining/B.ARROW_TIME,0,1))
		if arrow.remaining <= 0 and arrow.target.hp > 0: damage(arrow.target,arrow.amount,arrow.team,arrow.kind,arrow.get("source",{}))
	projectiles = projectiles.filter(func(a: Dictionary) -> bool: return a.remaining > 0)

func heal(u: Dictionary, dt: float) -> void:
	if u.kind != "healer": return
	u.heal_cd -= dt
	if u.heal_cd > 0: return
	u.heal_cd = B.HEAL_INTERVAL
	for ally: Dictionary in units:
		if ally.team == u.team and ally.hp > 0 and u.pos.distance_to(ally.pos) <= B.HEAL_RADIUS:
			ally.hp = minf(ally.max_hp,ally.hp+B.HEAL_AMOUNT)
			event("heal",ally.pos,u.team)
			if not is_same(ally,u): link(u.pos,ally.pos,u.team,"heal")

func cultivate(u: Dictionary, dt: float) -> bool:
	if u.kind != "farmer": return false
	if u.work_left > 0:
		u.work_left -= dt
		if u.work_left <= 0:
			for b: Dictionary in buildings:
				if b.id == u.work_id and b.hp > 0:
					b.boost_until = elapsed+B.BOOST_TIME
					b.hp = minf(b.max_hp,b.hp+B.FARMER_HEAL)
					stats[u.team].cultivated += 1
					event("cultivate",b.pos,u.team)
		return true
	for b: Dictionary in buildings:
		if b.hp <= 0 or b.team != u.team or b.kind != "farm" or b.cell.y != u.lane or b.id in u.worked: continue
		var distance: float = (b.pos.x-u.pos.x)*u.face
		if distance >= -0.01 and distance <= B.CARDS[u.kind].speed*dt+0.01:
			u.pos.x = b.pos.x
			u.worked.append(b.id)
			u.work_id = b.id
			u.work_left = B.CULTIVATE_TIME
			event("hoe",b.pos,u.team)
			return true
	return false

# One fixed simulation step. The phase order is part of the rules (tools/golden_matches.json
# fails if it changes): deaths, AI plays, clocks and income, buildings, spells and
# clouds, arrows, lords, troops, then deaths again and cleanup.
func step(dt: float) -> void:
	if time_stopped():
		step_time_stop(dt)
		return
	if paused or ended: return
	elapsed += dt
	last_dt = dt
	resolve_deaths()
	update_ai(dt)
	if time_stopped(): return
	tick_clocks(dt)
	build_lookups()
	Arcane.update_traps(self)
	update_buildings(dt)
	update_spells(dt)
	update_zones(dt)
	update_projectiles(dt)
	for lord: Dictionary in lords:
		if lord_active[lord.team]:
			Lord.step(self,lord,dt)
			if active_lanes.size() == 1:
				lord.pos.y = L.cell_center(Vector2i(0,active_lanes[0])).y
				lord.target.y = lord.pos.y
	update_units(dt)
	resolve_deaths()
	remove_dead()
	update_clock()

# Card and skill cooldowns, base income, lane alarms.
func tick_clocks(dt: float) -> void:
	for team: int in range(2):
		# Card cooldowns speed up together with ink (x1.5 after 3:00, x2 after 5:00).
		for slot: int in range(4): hand_cd[team][slot] = maxf(0,hand_cd[team][slot]-dt*multiplier())
		farm_cd[team] = maxf(0,farm_cd[team]-dt*multiplier())
		skill_cd[team] = maxf(0,skill_cd[team]-dt)
		base_clock[team] += dt*multiplier()
		while base_clock[team] >= B.BASE_INTERVAL-0.000001:
			base_clock[team] -= B.BASE_INTERVAL
			gain_ink(team,1.0)
	for lane: int in active_lanes:
		alarm[lane] = maxf(0,alarm[lane]-dt)
		building_alarm[lane] = maxf(0,building_alarm[lane]-dt)

# Expiry, farm and grave income, tower shots.
func update_buildings(dt: float) -> void:
	for b: Dictionary in buildings:
		b.flash = maxf(0,b.flash-dt)
		if b.hp <= 0: continue
		if b.expires > 0 and elapsed >= b.expires:
			b.hp = 0
			refresh_territory()
			event("death",b.pos,b.team,{"card":b.kind,"art_kind":b.kind,"face":1.0})
			continue
		if Arcane.update_building(self,b,dt): continue
		if b.kind == "grave":
			b.production += dt
			if b.production >= B.CARDS.grave.period: grave_drop(b)
		elif b.kind == "farm":
			var active_dt: float = clampf(elapsed-b.ready_at,0,dt)
			b.production += active_dt*farm_speed_with(b,lane_mill[b.team][b.cell.y])*multiplier()
			while b.production >= B.FARM_INTERVAL-0.000001:
				b.production -= B.FARM_INTERVAL
				farm_drop(b)
		elif b.kind == "tower":
			b.cd -= dt
			var target := nearest(b.pos,b.team,B.CARDS.tower.range,foe_units[b.team])
			if not target.is_empty() and b.cd <= 0:
				shoot(b,target,B.CARDS.tower.damage)
				b.cd = B.CARDS.tower.interval

func catapult_target(b: Dictionary) -> Dictionary:
	var data: Dictionary = B.CARDS[b.kind]
	var taunt := taunting_scarecrow(b)
	if not taunt.is_empty():
		var d: float = b.pos.distance_to(taunt.pos)
		if d >= data.min_range and d <= data.range: return taunt
	var found: Dictionary = {}
	var best := -1.0
	for target: Dictionary in lane_foes[b.team][b.lane] + lane_foe_buildings[b.team][b.lane]:
		if target.hp <= 0 or target.get("stealthed",false): continue
		if (target.pos.x-b.pos.x)*b.face < 0: continue
		var distance: float = b.pos.distance_to(target.pos)
		if distance < data.min_range or distance > data.range: continue
		if distance > best or (is_equal_approx(distance,best) and target.serial > found.get("serial",0)):
			best = distance
			found = target
	return found

# Buff the actual marching speed (including a legion's formation or a slowed ox), once only.
func movement_speed(u: Dictionary) -> float:
	var data: Dictionary = B.CARDS[u.kind]
	var base: float = B.OX_SLOW_SPEED if u.kind == "ox" and u.charged else u.get("march",data.speed)
	u.inspired = false
	if (u.kind != "drummer" and team_drum_until[u.team] > elapsed) or LordExpansion.active(self,u):
		u.inspired = true
		var index: int = B.TIERS.speed.find(base)
		base = B.TIERS.speed[index-1] if index > B.tier_index("S") else base # one tier faster, never past S
	if u.get("slow_left",0.0) > 0:
		base *= 0.5
	return base

func attack_interval(u: Dictionary) -> float:
	var data: Dictionary = B.CARDS[u.kind]
	var base: float = data.interval
	if (u.kind != "drummer" and team_drum_until[u.team] > elapsed) or LordExpansion.active(self,u):
		var index: int = B.TIERS.interval.find(base)
		return B.TIERS.interval[index-1] if index > B.tier_index("S") else base # one tier faster, never past S
	return base

func update_spells(dt: float) -> void:
	for spell: Dictionary in spells:
		spell.delay -= dt
		if spell.delay <= 0: cast_spell(spell)
	spells = spells.filter(func(s: Dictionary) -> bool: return s.delay > 0)

func update_units(dt: float) -> void:
	# Summons append to units; a snapshot prevents them acting in their birth step.
	for u: Dictionary in units.duplicate():
		if update_unit(u,dt): return # an invader just ended the match

# One troop's turn: summon, heal, then fight, cultivate or march. True when it ends the match.
func update_unit(u: Dictionary, dt: float) -> bool:
	u.flash = maxf(0,u.flash-dt)
	if u.hp <= 0: return false
	if u.spawn_delay > 0:
		u.spawn_delay -= dt
		return false
	u.cd = maxf(0,u.cd-dt)
	if u.get("slow_left",0.0) > 0:
		u.slow_left = maxf(0.0,u.slow_left-dt)
	if u.get("stun_left",0.0) > 0:
		u.stun_left = maxf(0.0,u.stun_left-dt)
		return false
	var data: Dictionary = B.CARDS[u.kind]
	if u.kind == "necromancer": summon_skeletons(u,data,dt)
	if u.kind == "drummer":
		u.drum_cd = u.get("drum_cd",10.0)-dt
		if u.drum_cd <= 0:
			u.drum_cd += B.CARDS.drummer.get("inspire_period",10.0)
			trigger_drum(u)
	heal(u,dt)
	if u.kind == "catapult":
		var target := catapult_target(u)
		if not target.is_empty():
			if u.cd <= 0:
				projectiles.append({"source":u,"pos":u.pos,"start":u.pos,"impact":target.pos,"flight":data.flight_time,"remaining":data.flight_time,"amount":data.area_damage,"radius":data.radius,"team":u.team,"kind":u.kind})
				u.cd = attack_interval(u)
				event("catapult_fire",u.pos,u.team,{"target":target.pos})
			return false
		return march(u,data,dt)
	var target := choose_target(u,data)
	if not target.is_empty():
		if u.cd <= 0: attack(u,target)
		return false
	if Arcane.repair(self,u,dt): return false
	if cultivate(u,dt): return false
	return march(u,data,dt)

func summon_skeletons(u: Dictionary, data: Dictionary, dt: float) -> void:
	u.summon_left -= dt
	if u.summon_left > 0: return
	u.summon_left += data.summon_interval
	var col := clampi(floori((u.pos.x-L.GRID_ORIGIN.x)/L.CELL_SIZE.x),0,L.GRID_COLUMNS-1)
	for lane: int in range(maxi(0,u.lane-1),mini(5,u.lane+2)):
		for i: int in range(data.get("summon_per_lane",1)):
			var child := spawn_unit(u.team,lane,"skeleton",L.cell_center(Vector2i(col,lane)))
			child.card = u.get("card",u.kind)
			event("summoned",child.pos,u.team)
			link(u.pos,child.pos,u.team,"summon")

# 稻草人: an enemy scarecrow whose 3 x 3 block (its lane and the two next to it, its column and the
# two next to it) holds this troop draws all of its attacks, from wherever it stands - ravens and
# rams included. The nearest such scarecrow wins; level ones go by the higher serial.
func taunting_scarecrow(u: Dictionary) -> Dictionary:
	var col := clampi(floori((u.pos.x-L.GRID_ORIGIN.x)/L.CELL_SIZE.x),0,L.GRID_COLUMNS-1)
	var found: Dictionary = {}
	for lane: int in range(maxi(0,u.lane-1),mini(5,u.lane+2)):
		for b: Dictionary in lane_foe_taunts[u.team][lane]:
			if b.hp <= 0 or absi(b.cell.x-col) > 1: continue
			if found.is_empty():
				found = b
				continue
			var d: float = u.pos.distance_to(b.pos)
			var best: float = u.pos.distance_to(found.pos)
			if d < best-SERIAL_TIE or (d <= best+SERIAL_TIE and b.serial > found.serial): found = b
	return found

# Whom this troop attacks right now ({} = nobody in reach).
func choose_target(u: Dictionary, data: Dictionary) -> Dictionary:
	var foe_buildings: Array = lane_foe_buildings[u.team][u.lane].filter(func(other: Dictionary) -> bool: return (other.pos.x-u.pos.x)*u.face >= 0)
	if u.get("phased",false): return nearest(u.pos,u.team,data.range,foe_buildings)
	if data.has("blink_step"):
		var candidates: Array = lane_foes[u.team][u.lane]+lane_foe_buildings[u.team][u.lane]
		var forward: Array = candidates.filter(func(other: Dictionary) -> bool: return (other.pos.x-u.pos.x)*u.face >= 0)
		var front := nearest(u.pos,u.team,data.range,forward,-1,false)
		if not front.is_empty(): return front
	var taunt := taunting_scarecrow(u)
	if not taunt.is_empty() and u.pos.distance_to(taunt.pos) <= data.range: return taunt
	var foe_units: Array = lane_foes[u.team][u.lane].filter(func(other: Dictionary) -> bool: return (other.pos.x-u.pos.x)*u.face >= 0)
	var target: Dictionary = {} if data.get("hits","") == "buildings" else nearest(u.pos,u.team,data.range,foe_units,-1,data.range > B.MELEE_RANGE)
	var building := nearest(u.pos,u.team,data.range,foe_buildings)
	if data.get("prefers","") == "farm":
		var farms: Array = lane_foe_buildings[u.team][u.lane].filter(func(b: Dictionary) -> bool: return b.kind == "farm" and (b.pos.x-u.pos.x)*u.face >= -data.range)
		var farm := nearest(u.pos,u.team,INF,farms)
		if not farm.is_empty():
			building = farm if u.pos.distance_to(farm.pos) <= data.range else {}
	if not building.is_empty() and (target.is_empty() or u.pos.distance_to(building.pos) < u.pos.distance_to(target.pos)): target = building
	if data.get("target_rule","") == "lowest_serial": target = reaper_target(u)
	elif data.get("hits","") != "buildings" and target.is_empty():
		var forward_lords: Array = lords.filter(func(l: Dictionary) -> bool: return (l.pos.x-u.pos.x)*u.face >= 0)
		target = nearest(u.pos,u.team,54.0,forward_lords)
	return target

# Nothing to hit: walk to the enemy gate, batter it, clear its rubble, walk in. True = match won.
func march(u: Dictionary, data: Dictionary, dt: float) -> bool:
	var enemy: int = 1-u.team
	var taunt := taunting_scarecrow(u)
	var target_lane: int = taunt.cell.y if not taunt.is_empty() else u.lane
	var target_y: float = L.cell_center(Vector2i(0,target_lane)).y
	if not is_equal_approx(u.pos.y,target_y):
		u.pos.y = move_toward(u.pos.y,target_y,movement_speed(u)*dt)
		if absf(u.pos.y-target_y) <= 0.01:
			u.pos.y = target_y
			u.lane = target_lane
		else:
			var new_lane: int = clampi(roundi((u.pos.y-L.GRID_ORIGIN.y)/L.CELL_SIZE.y-0.5),0,4)
			if new_lane != u.lane: u.lane = new_lane
	var open: bool = gates[enemy][u.lane] <= 0
	var climbed: bool = u.get("climb",0.0) >= B.RUBBLE_TIME
	var stop: float = L.gate_icon_x(enemy) if open and climbed else L.gate_stop(enemy)
	var forward := 1.0 if u.team == 0 else -1.0
	if (stop-u.pos.x)*forward > 0.001:
		u.pos.x = move_toward(u.pos.x,stop,movement_speed(u)*dt)
	elif open and not climbed:
		u.climb = u.get("climb",0.0)+dt
		if enemy == 0: alarm[u.lane] = 1.5
	elif open:
		if not invasion_victory[u.team]: return false
		event("invaded",u.pos,u.team,{"lane":u.lane,"unit_kind":u.kind})
		finish(u.team)
		return true
	elif u.cd <= 0:
		Arcane.reveal(self,u)
		if data.get("pierce",false):
			Arcane.shoot_piercing_arrow(self,u)
			u.cd = attack_interval(u)
			return false
		if data.has("stun_on_hit"):
			Arcane.area_hit(self,u,Vector2(L.gate_stop(enemy),u.pos.y))
			u.cd = attack_interval(u)
			return false
		var amount: float = u.get("damage",data.damage)
		if u.kind == "ox":
			amount = (B.OX_CHARGE if not u.charged else data.damage)*B.OX_BUILDING_BONUS
			u.charged = true
		hit_gate(1-u.team,u.lane,amount,u.get("card",u.kind),u)
		u.cd = attack_interval(u)
	return false

# Free the serials of the dead and drop them.
func remove_dead() -> void:
	for gone: Dictionary in units+buildings:
		if gone.hp <= 0 and gone.serial > 0:
			serials_in_use.erase(gone.serial)
			gone.serial = 0
	units = units.filter(func(u: Dictionary) -> bool: return u.hp > 0)
	buildings = buildings.filter(func(b: Dictionary) -> bool: return b.hp > 0)

func cast_spell(s: Dictionary) -> void:
	var data: Dictionary = B.CARDS[s.kind]
	event("spell",s.pos,s.team,{"card":s.kind,"radius":data.radius})
	if s.kind == "curse":
		for u: Dictionary in units:
			if u.hp > 0 and u.team != s.team and u.pos.distance_to(s.pos) <= data.radius:
				u.cursed = true
				u.cursed_until = INF
				u.curse_team = s.team
				link(s.pos,u.pos,s.team,"curse")
		return
	if s.kind == "plague":
		add_zone(s.pos,s.team,data.radius,data.duration)
		return
	if s.kind == "harvest":
		for b: Dictionary in buildings:
			if b.team == s.team and b.hp > 0 and b.kind == "farm" and b.pos.distance_to(s.pos) <= data.radius:
				b.harvest_until = elapsed+B.HARVEST_TIME
				link(s.pos,b.pos,s.team,"harvest")
		return
	for u: Dictionary in units:
		if u.team != s.team and u.pos.distance_to(s.pos) <= data.radius:
			if s.kind == "fire": u.pos.x += B.FIRE_KNOCKBACK*(1 if s.team == 0 else -1)
			damage(u,data.damage,s.team,s.kind)
	for b: Dictionary in buildings:
		if b.team != s.team and b.pos.distance_to(s.pos) <= data.radius: damage(b,data.building_damage,s.team,s.kind)
	for lane: int in active_lanes:
		var gate_pos := Vector2(L.gate_stop(1-s.team),L.cell_center(Vector2i(0,lane)).y)
		if gate_pos.distance_to(s.pos) <= data.radius: hit_gate(1-s.team,lane,data.gate_damage,s.kind)

func update_clock() -> void:
	if ended: return
	for ramp: float in [B.RAMP_1,B.RAMP_2]:
		if elapsed >= ramp and elapsed-last_dt < ramp: event("ramp",Vector2(800,50),0,{"multiplier":multiplier()})

# What the AI needs to decide on its lord's skill.
func skill_state(team: int) -> Dictionary:
	var farms := 0
	for b: Dictionary in buildings:
		if b.team == team and b.kind == "farm" and b.hp > 0: farms += 1
	var gate_total := 0.0
	var broken := 0
	for hp: float in gates[team]:
		gate_total += hp
		if hp <= 0: broken += 1
	var my_army := units.filter(func(u: Dictionary) -> bool: return u.team == team and u.hp > 0 and not u.kind in ["farmer","artificer"])
	var my_army_hp := 0.0
	for u: Dictionary in my_army: my_army_hp += u.hp
	return {"rune_lanes":LordExpansion.rune_cells(self,team).size() if lords[team].lord == "rune" else 0,"slash_targets":units.filter(func(u: Dictionary) -> bool: return u.team != team and u.hp > 0 and u.spawn_delay <= 0 and preload("res://hero_slash.gd").contains(lords[team].pos,u.pos,team)).size() if lords[team].lord == "adventure" else 0,"troops":my_army.size(),"troop_hp":my_army_hp,"lord":lords[team].lord,"ready":lords[team].hp > 0 and skill_cd[team] <= 0,"ink":ink[team],"elapsed":elapsed,"farms":farms,"graves":count_buildings(team,"grave"),"gate_share":gate_total/(5*B.GATE_HP),"broken":broken,"difficulty":difficulty,"params":ai_params[team]}

func snapshot(team: int) -> Dictionary:
	var candidates: Array = []
	for slot: int in [0,1,2,3,FARM_SLOT]:
		for row: int in range(5):
			for col: int in range(9):
				var cell := Vector2i(col,row)
				var pos := L.cell_center(cell)
				if can_play(team,slot,pos): candidates.append({"slot":slot,"kind":kind_at(team,slot),"pos":pos,"cell":cell})
	return {"team":team,"ink":ink[team],"enemy_ink":ink[1-team],"difficulty":difficulty,"elapsed":elapsed,"wave_until":wave_until[team],"memory":memory[team].duplicate(),"recent":recent_lanes[team].duplicate(),"saving":ai_save[team],"params":ai_params[team],"units":units,"buildings":buildings,"gates":gates,"candidates":candidates,"owned_cells":territory.count(team),"active_lanes":active_lanes.duplicate()}

func update_ai(dt: float) -> void:
	if elapsed < ai_start: return
	for team: int in range(2):
		if not ai_enabled[team]: continue
		if not ai_pending[team].is_empty():
			ai_delay[team] -= dt
			if ai_delay[team] <= 0:
				var c: Dictionary = ai_pending[team]
				if c.kind == kind_at(team,c.slot) and play(team,c.slot,c.pos):
					if c.get("wave",false) and elapsed >= wave_until[team]: wave_until[team] = elapsed+ai_params[team].get("wave_time",6.0)
				ai_pending[team] = {}
			continue
		ai_clock[team] -= dt
		if ai_clock[team] <= 0:
			ai_clock[team] = B.AI_TICK
			var plan: Dictionary = AI.skill_plan(skill_state(team))
			ai_save[team] = plan.save
			if plan.cast and cast_skill(team):
				if time_stopped(): return
				continue
			ai_pending[team] = AI.decide(snapshot(team))
			ai_delay[team] = [1.2,0.6,0.2][difficulty]
