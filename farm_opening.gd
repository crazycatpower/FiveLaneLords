extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const BANDIT = preload("res://assets/manuscript-v1/bandit.png")
const TENT = preload("res://assets/manuscript-v1/bandit-tent.png")
const VILLAGE = preload("res://assets/manuscript-v1/village.png")

var active := false
var time := 0.0
var attacked := false
var killed := false
var burned := false
var arrived := false
var arrived_at := -1.0
var raid_played := false
var timeline: Array[String] = []

func start(g) -> void:
	active = true
	time = 0
	attacked = false
	killed = false
	burned = false
	arrived = false
	arrived_at = -1
	raid_played = false
	timeline.clear()
	var m = g.model
	m.active_lanes.assign([2])
	m.buildings.clear()
	m.units.clear()
	m.refresh_territory()
	m.add_building(0,Vector2i(0,2),"farm")
	m.add_building(0,Vector2i(2,2),"farm")
	# Fixed opening hands, but every deployment pays the normal cost and rotates its real slot.
	m.decks[0] = g.adventure.STAGES[g.adventure.index].deck.duplicate()
	# One opening raid in reserve; subsequent raids require normal income.
	m.decks[1] = g.adventure.STAGES[g.adventure.index].enemy_deck.duplicate()
	m.ink[1] = float(B.CARDS.bandit.cost)
	m.home_cards[1] = ""
	m.ai_enabled = [false,false]
	m.lord_active = [false,false]
	m.lords[0].hp = 0
	m.lords[1].hp = 0
	m.invasion_victory.assign([true,true])
	m.play(0,0,L.cell_center(Vector2i(0,2)))
	timeline.append("0.00 farmer card played")

func advance(g, _dt: float) -> bool:
	if not active or g.model.paused: return false
	var m = g.model
	time = m.elapsed
	# A scheduled card play, never a spawn or damage trigger.
	if time >= 0.5 and not raid_played:
		raid_played = m.play(1,0,L.cell_center(Vector2i(8,2)))
		if raid_played: timeline.append("%.2f bandit card played" % time)
	return false

func observe(g) -> void:
	var m = g.model
	time = m.elapsed
	for e: Dictionary in m.events:
		if e.kind == "cultivate": timeline.append("%.2f cultivation finished" % time)
		if e.kind == "death": timeline.append("%.2f death" % time)
	if not active: return
	if not attacked and m.units.any(func(u: Dictionary) -> bool: return u.team == 0 and u.kind == "farmer" and u.hp < u.max_hp):
		attacked = true
	killed = not m.units.any(func(u: Dictionary) -> bool: return u.team == 0 and u.kind == "farmer" and u.hp > 0)
	burned = m.count_buildings(0,"farm") == 1
	var at_village: bool = m.units.any(func(u: Dictionary) -> bool: return u.team == 1 and u.hp > 0 and u.pos.x <= L.cell_center(Vector2i(0,2)).x+B.MELEE_RANGE+5)
	if killed and burned and at_village:
		arrived = true
		arrived_at = time
		active = false
		m.lord_active[0] = true
		m.lords[0].hp = m.lords[0].max_hp
		m.lords[0].pos = Vector2(309,394)
		m.ai_enabled = [false,true]
		timeline.append("%.2f lord arrived; normal AI enabled" % time)
		g.notice = "領主率隊反攻！部署手牌摧毀強盜帳篷。"

func paint(g) -> void:
	var m = g.model
	g.draw_battle_landscape(L.FIELD_FRAME)
	g.ink_frame(L.FIELD_FRAME)
	var road := Rect2(L.GRID_ORIGIN.x,336,L.GRID_SIZE.x,116)
	g.draw_rect(road,Color(0.72,0.66,0.43,0.4))
	g.ink_line(road.position,Vector2(road.end.x,road.position.y),4,Color("8a8055"),2)
	g.ink_line(Vector2(road.position.x,road.end.y),road.end,5,Color("8a8055"),2)
	for col: int in range(9):
		var cell := Vector2i(col,2)
		var r := Rect2(L.GRID_ORIGIN+Vector2(cell)*L.CELL_SIZE,L.CELL_SIZE)
		var owner: int = m.territory_owner(cell)
		if owner >= 0: g.draw_rect(r,Color(g.RED if owner == 0 else g.BLUE,0.13))
		if not active and g.selected >= 0 and m.can_play(0,g.selected,L.cell_center(cell)):
			g.draw_rect(r.grow(-4),Color(1,0.86,0.3,0.24))
			g.draw_rect(r.grow(-4),Color("b58b2e"),false,2)
	g.draw_fitted(TENT,Rect2(1325,235,225,220),Color.WHITE if m.gates[1][2] > 0 else Color(0.5,0.4,0.3,0.7))
	g.bar(Rect2(1370,464,135,7),m.gates[1][2],B.GATE_HP,g.BLUE)
	g.label_at(Vector2(1367,489),"強盜帳篷",20)
	g.draw_fitted(VILLAGE,Rect2(40,240,225,220),Color.WHITE if m.gates[0][2] > 0 else Color(0.5,0.45,0.35,0.7))
	g.bar(Rect2(85,464,135,7),m.gates[0][2],B.GATE_HP,g.RED)
	g.label_at(Vector2(115,489),"邊境農莊",20)
	for b: Dictionary in m.buildings:
		g.draw_combat_actor(b.kind,b,b.pos,1.0 if b.team == 0 else -1.0)
		if b.hp < b.max_hp: g.bar(Rect2(b.pos-Vector2(30,40),Vector2(60,5)),b.hp,b.max_hp,g.RED if b.team == 0 else g.BLUE)
	g.layout_formations()
	var visible: Array = m.units.filter(func(u: Dictionary) -> bool: return u.hp > 0 and u.get("spawn_delay",0.0) <= 0)
	for u: Dictionary in visible:
		# Stable visual lanes: deaths no longer reshuffle the remaining sprites.
		u.draw = u.pos+Vector2(0,[-22.0,0.0,22.0][u.id%3])
	visible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.draw.y < b.draw.y)
	for u: Dictionary in visible:
		if u.team == 1 and u.kind == "bandit":
			var p: Vector2 = u.draw
			p.y += sin(m.elapsed*7)*2
			if u.cd > 0.6: p.x += sin(time*15)*7
			var is_stealth: bool = u.get("stealthed",false)
			var tint: Color = Color(0.40,0.48,0.60,0.42) if is_stealth else Color.WHITE
			g.draw_fitted_facing(BANDIT,Rect2(p-Vector2(43,73),Vector2(86,104)),-1.0,tint) # enemy bandits walk left
			if is_stealth:
				g.draw_circle(p+Vector2(0,18),12+sin(m.elapsed*9)*3,Color(0.2,0.15,0.1,0.18))
			if u.hp < u.max_hp: g.bar(Rect2(p-Vector2(25,75),Vector2(50,4)),u.hp,u.max_hp,g.BLUE)
		else:
			if u.kind == "farmer" and u.work_left > 0:
				g.draw_set_transform(u.draw,sin(time*9)*0.08)
				g.draw_texture_rect(g.art("farmer"),g.actor_rect("farmer"),false)
				g.draw_set_transform(Vector2.ZERO)
				if u.hp < u.max_hp: g.bar(Rect2(u.draw-Vector2(24,68),Vector2(48,4)),u.hp,u.max_hp,g.RED)
			else: g.draw_unit(u)
	if m.lord_active[0] or arrived: g.draw_lord(m.lords[0])
	for a: Dictionary in m.projectiles: g.draw_line(a.pos-Vector2(12,0),a.pos,g.INK,2)
	g.draw_effects()
	if not active and g.model.cell_at(g.get_global_mouse_position()).y == 2: g.draw_preview()
	g.draw_hud(true)
	paint_status(g)
	# Replace the five-gate summary with this stage's single objective.
	for team: int in range(2):
		var x := 44.0 if team == 0 else 1014.0
		g.label_at(Vector2(x+8,44),"邊境農莊" if team == 0 else "強盜營地",22,g.RED if team == 0 else g.BLUE)
		g.bar(Rect2(x+8,55,330,9),m.gates[team][2],B.GATE_HP,g.RED if team == 0 else g.BLUE)
	g.panel(g.library.INFO_RECT,Color("ecdcb6"))
	g.draw_string(g.font,g.library.INFO_RECT.position+Vector2(0,30),"第 1-1 關 · 單路",HORIZONTAL_ALIGNMENT_CENTER,g.library.INFO_RECT.size.x,15,g.INK)
	if not m.ended and not m.paused and (active or (arrived and time-arrived_at < 7.0)):
		var speaker := "農民"
		var speaker_color := Color("4a7838")
		var words := "這茬麥子長得真不賴。"
		if time >= 2.5 and time < 6.5:
			words = "前面還有一塊，耕完收工。"
		elif time >= 6.5 and m.stats[0].cultivated < 6:
			words = "快了，最後幾鋤頭。"
		elif m.stats[0].cultivated >= 6 and not attacked and not killed:
			words = "搞定！……等等，草裡有人？"
		elif attacked and not killed:
			speaker = "強盜"
			speaker_color = Color("7a2b22")
			words = "動手！一個別放過！"
		elif killed and not burned:
			speaker = "強盜"
			speaker_color = Color("7a2b22")
			words = "把田砸了，進村！"
		elif burned and not arrived:
			speaker = "村民"
			speaker_color = Color("8c382b")
			words = "田被砸了！強盜摸過來了！"
		elif arrived:
			speaker = "領主"
			speaker_color = Color(g.RED)
			if time - arrived_at < 3.0:
				words = "敢動我的麥田？"
			else:
				words = "抄傢伙，隨我踏平他們營地！"
		var box := Rect2(360,545,880,78)
		g.panel(box,Color("ebd9b4"))
		g.ink_frame(box.grow(-2))
		# Speaker pill
		var pill := Rect2(box.position.x+18,box.position.y+15,84,28)
		g.draw_rect(pill,speaker_color)
		g.draw_string(g.font,pill.position+Vector2(0,20),speaker,HORIZONTAL_ALIGNMENT_CENTER,pill.size.x,17,Color("fff6de"))
		# Dialogue text
		g.draw_string(g.font,Vector2(box.position.x+116,box.position.y+36),words,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-130,22,g.INK)
		# Subtitle / Hint
		var hint := "空白鍵暫停" if active else "選牌部署在我方領地，開始反攻"
		g.draw_string(g.font,Vector2(box.position.x+18,box.position.y+65),hint,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-36,14,Color("796344"))
		if active: g.draw_rect(Rect2(410,725,790,158),Color(0.2,0.17,0.12,0.45))
	if m.ended: g.draw_result()
	elif m.paused:
		g.panel(L.OVERLAY_RECT)
		g.label_at(L.OVERLAY_RECT.position+Vector2(50,58),"戰局暫停",30)
		for item: Array in g.overlay_buttons():
			g.panel(item[0])
			g.draw_string(g.font,item[0].position+Vector2(0,27),item[1],HORIZONTAL_ALIGNMENT_CENTER,item[0].size.x,20,g.INK)

func paint_status(g) -> void:
	var m = g.model
	if not arrived:
		g.panel(g.SKILL_RECT,Color("bcb19a"))
		g.draw_string(g.font,g.SKILL_RECT.position+Vector2(0,32),"領主尚未抵達",HORIZONTAL_ALIGNMENT_CENTER,g.SKILL_RECT.size.x,21,g.INK)
	else:
		g.draw_skill_button()
		g.label_at(Vector2(1220,817),B.LORDS[m.lords[0].lord].name,18,g.RED)
		g.bar(Rect2(1220,828,208,6),m.lords[0].hp,m.lords[0].max_hp,g.RED)
		g.label_at(Vector2(1440,837),"%d / %d" % [maxi(0,int(m.lords[0].hp)),m.lords[0].max_hp],14)
	g.label_at(Vector2(1220,870),"敵方據點：強盜帳篷",17,g.BLUE)
