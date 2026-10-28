extends Node2D
const LAYOUT = preload("res://layout.gd")
const BALANCE = preload("res://balance.gd")
const ART = preload("res://manuscript_art.gd")
var red_castle: Texture2D
var blue_castle: Texture2D

const LORD = preload("res://lord.gd")
const PAPER = preload("res://assets/parchment-background.png")
const MILITIA = preload("res://assets/manuscript-v1/militia-red.png")
const BLUE_MILITIA = preload("res://assets/manuscript-v1/militia-blue.png")
const LORD_ART = preload("res://assets/manuscript-v1/lord-simple-v2.png")
const FARM = preload("res://assets/farmland.png")
const FARMER = preload("res://assets/farmer.png")
const INK := Color("463529")
const RED := Color("9c3d30")
const BLUE := Color("355b78")
const GRID_ORIGIN := LAYOUT.GRID_ORIGIN
const CELL_SIZE := LAYOUT.CELL_SIZE
const GRID_COLUMNS := LAYOUT.GRID_COLUMNS
const GRID_ROWS := LAYOUT.GRID_ROWS
const DEPLOY_COLUMNS := LAYOUT.DEPLOY_COLUMNS
const FORMATION_GAP := LAYOUT.FORMATION_GAP
const MELEE_RANGE := BALANCE.MELEE_RANGE
# T0 retains v1 pursuit; forward-only movement is T1.
const SIGHT_RANGE := BALANCE.SIGHT_RANGE
var font: Font
var lord: CharacterBody2D
var units: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var gates: Array = []
var castle: Array[float] = [BALANCE.CASTLE_HP, BALANCE.CASTLE_HP]
var alarm: Array[float] = [0.0,0.0,0.0,0.0,0.0] # seconds left of the red "our gate is under attack" pulse, per lane
var buildings: Array[Dictionary] = []
var selected_card: String = ""
var gold: float = BALANCE.START_GOLD
var selected: int = 2
var elapsed: float = 0.0
var enemy_timer: float = BALANCE.ENEMY_INITIAL_DELAY
var recruit_cd: float = 0.0
var skill_cd: float = 0.0
var ended: bool = false
var paused: bool = false
var notice: String = "選卡後點左側三欄的格子，或按 1–5 放進該路。右鍵取消。"
var buttons: Array[Button] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	red_castle = load("res://assets/manuscript-v1/castle-red.png")
	blue_castle = load("res://assets/manuscript-v1/castle-blue.png")
	configure_rng(OS.get_cmdline_user_args())
	for team: int in range(2):
		var side: Array[float] = []
		side.resize(GRID_ROWS)
		side.fill(BALANCE.GATE_HP)
		gates.append(side)
	add_building(0, Vector2i(0, 0), "farm")
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC", "Arial"])
	font = system_font
	for pair: Array in [["left",KEY_A],["right",KEY_D],["up",KEY_W],["down",KEY_S]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var key := InputEventKey.new()
			key.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0],key)
	lord = LORD.new()
	lord.game = self
	lord.position = LAYOUT.LORD_START
	add_child(lord)
	make_card(LAYOUT.CARD_X[0],MILITIA,"民兵出陣","可部署於農田","Q",str(int(BALANCE.MILITIA_COST)),recruit)
	make_card(LAYOUT.CARD_X[1],FARM,"農田","收入 +%.1f / 秒" % BALANCE.FARM_INCOME,"F",str(int(BALANCE.FARM_COST)),build_farm)
	make_card(LAYOUT.CARD_X[2],LORD_ART,"領主旋斬","範圍傷害 %d" % int(BALANCE.SKILL_DAMAGE),"SPACE","%ds" % int(BALANCE.SKILL_COOLDOWN),skill)
	make_button(LAYOUT.PAUSE_RECT.position, LAYOUT.PAUSE_RECT.size, "Ⅱ", toggle_pause)
	make_button(LAYOUT.RESTART_RECT.position, LAYOUT.RESTART_RECT.size, "重玩", restart)
	queue_redraw()

func make_card(x: float, texture: Texture2D, title: String, detail: String, key: String, price: String, action: Callable) -> void:
	var card = preload("res://action_card.gd").new()
	card.position = Vector2(x,LAYOUT.CARD_Y)
	card.size = LAYOUT.CARD_SIZE
	card.scale = LAYOUT.CARD_SCALE
	card.artwork = texture
	card.title_text = title
	card.detail_text = detail
	card.key_text = key
	card.price_text = price
	card.card_font = font
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = title + "：" + detail
	for state: String in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0,0,0,0)
		style.border_color = Color(0,0,0,0)
		if state == "pressed":
			style.bg_color = Color("b99556")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.shadow_color = Color(0,0,0,0.4)
		style.shadow_size = 0
		card.add_theme_stylebox_override(state,style)
	card.pressed.connect(action)
	add_child(card)
	buttons.append(card)

func _process(_delta: float) -> void:
	if buttons.size() < 5:
		return
	buttons[0].disabled = ended or paused or gold < BALANCE.MILITIA_COST or recruit_cd > 0
	buttons[1].disabled = ended or paused or gold < BALANCE.FARM_COST or farm_count(0) >= DEPLOY_COLUMNS * GRID_ROWS
	buttons[2].disabled = ended or paused or skill_cd > 0 or lord.respawn > 0
	buttons[0].set("cooldown",recruit_cd)
	buttons[0].set("cooldown_max",BALANCE.RECRUIT_COOLDOWN)
	buttons[2].set("cooldown",skill_cd)
	buttons[2].set("cooldown_max",BALANCE.SKILL_COOLDOWN)
	for i: int in range(3):
		buttons[i].set("chosen",(i == 0 and selected_card == "militia") or (i == 1 and selected_card == "farm"))
		buttons[i].queue_redraw()
	queue_redraw()

func make_button(pos: Vector2, size: Vector2, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.position = pos
	button.size = size
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",Color("f9eac9"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("493c30")
	style.border_color = Color("b89352")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate()
	hover.bg_color = Color("756044")
	button.add_theme_stylebox_override("hover",hover)
	button.pressed.connect(action)
	add_child(button)
	buttons.append(button)

func lane_y(lane: int) -> float:
	return cell_center(Vector2i(0,lane)).y

func cell_center(cell: Vector2i) -> Vector2:
	return LAYOUT.cell_center(cell)

func cell_at(point: Vector2) -> Vector2i:
	if not Rect2(GRID_ORIGIN,CELL_SIZE * Vector2(GRID_COLUMNS,GRID_ROWS)).has_point(point):
		return Vector2i(-1,-1)
	var offset := (point-GRID_ORIGIN)/CELL_SIZE
	return Vector2i(floori(offset.x),floori(offset.y))

func can_place(cell: Vector2i) -> bool:
	if ended or paused or selected_card.is_empty():
		return false
	if cell.x < 0 or cell.x >= DEPLOY_COLUMNS or cell.y < 0 or cell.y >= GRID_ROWS:
		return false
	if selected_card == "farm" and not building_at(cell).is_empty():
		return false
	if selected_card == "farm":
		if gold < BALANCE.FARM_COST:
			return false
		for unit: Dictionary in units:
			if unit.hp > 0 and cell_at(unit.pos) == cell:
				return false
		return true
	return selected_card == "militia" and gold >= BALANCE.MILITIA_COST and recruit_cd <= 0

func place_card(cell: Vector2i) -> bool:
	if not can_place(cell):
		if not ended and not paused and not selected_card.is_empty():
			notice = "無法放置：僅限我方左側三欄空地，並需足夠金幣。"
		return false
	selected = cell.y
	if selected_card == "farm":
		gold -= BALANCE.FARM_COST
		add_building(0, cell, "farm")
		notice = "農田已建於第 %d 欄、第 %d 路，收入 +1.5 / 秒。" % [cell.x+1,cell.y+1]
	else:
		gold -= BALANCE.MILITIA_COST
		recruit_cd = BALANCE.RECRUIT_COOLDOWN
		spawn_unit(0, cell.y, "militia", cell_center(cell))
		notice = "民兵已部署於第 %d 欄、第 %d 路。" % [cell.x+1,cell.y+1]
	selected_card = ""
	queue_redraw()
	return true

func place_in_lane(lane: int) -> bool:
	# Keyboard deploy: militia go to the lane's front column, farms take the first free cell from the back.
	if ended or paused or selected_card.is_empty():
		return false
	var columns: Array = range(DEPLOY_COLUMNS-1,-1,-1) if selected_card == "militia" else range(DEPLOY_COLUMNS)
	for col: int in columns:
		if can_place(Vector2i(col,lane)):
			return place_card(Vector2i(col,lane))
	notice = "第 %d 路沒有可放的格子。" % [lane+1]
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			selected = event.keycode - KEY_1
			if not selected_card.is_empty():
				place_in_lane(selected)
		match event.keycode:
			KEY_Q: recruit()
			KEY_F: build_farm()
			KEY_SPACE: skill()
			KEY_ESCAPE: toggle_pause()
			KEY_R:
				# R sits next to WASD and F, so mid-battle it only explains how to restart.
				if ended or paused:
					restart()
				else:
					notice = "戰鬥中按 R 不會重開：先按 Esc 暫停，再按 R。"
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not selected_card.is_empty():
				selected_card = ""
				notice = "已取消放置。"
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var cell := cell_at(get_global_mouse_position())
			if cell.x >= 0:
				selected = cell.y
				if not selected_card.is_empty():
					place_card(cell)
	queue_redraw()

func recruit() -> void:
	if ended or paused:
		return
	if gold < BALANCE.MILITIA_COST:
		notice = "金幣不足：民兵要 25 金幣。"
		return
	if recruit_cd > 0:
		notice = "民兵整隊中，稍等一下再出兵。"
		return
	selected_card = "militia"
	notice = "民兵：點左側三欄的格子，或按 1–5 放進該路（25 金幣）。"

func build_farm() -> void:
	if ended or paused:
		return
	if farm_count(0) >= DEPLOY_COLUMNS * GRID_ROWS:
		notice = "部署區已經種滿 15 塊農田。"
		return
	if gold < BALANCE.FARM_COST:
		notice = "金幣不足：農田要 60 金幣。"
		return
	selected_card = "farm"
	notice = "農田：點左側三欄的空格，或按 1–5 放進該路（60 金幣）。"

func configure_rng(arguments: PackedStringArray) -> void:
	rng.randomize()
	for argument: String in arguments:
		if argument.begins_with("--seed=") and argument.substr(7).is_valid_int():
			rng.seed = int(argument.substr(7))

func add_building(team: int, cell: Vector2i, kind: String) -> void:
	buildings.append({"kind": kind, "team": team, "cell": cell,
		"hp": BALANCE.FARM_HP, "expires": -1.0, "boost_until": 0.0})

func building_at(cell: Vector2i) -> Dictionary:
	for building: Dictionary in buildings:
		if building.cell == cell and building.hp > 0:
			return building
	return {}

func farm_count(team: int) -> int:
	var count := 0
	for building: Dictionary in buildings:
		if building.kind == "farm" and building.team == team and building.hp > 0:
			count += 1
	return count

func income() -> float:
	return BALANCE.BASE_INCOME + farm_count(0) * BALANCE.FARM_INCOME

func spawn_unit(team: int, lane: int, kind: String, pos: Vector2) -> void:
	units.append({"kind":kind,"team":team,"lane":lane,"pos":pos,"hp":BALANCE.MILITIA_HP,"cd":0.0,"phase":rng.randf()*TAU,"face":1.0 if team == 0 else -1.0})

func spawn_enemy() -> void:
	var lane := rng.randi_range(0, GRID_ROWS - 1)
	spawn_unit(1, lane, "militia", LAYOUT.spawn_position(1, lane))

func nearest_enemy(pos: Vector2, distance: float) -> Dictionary:
	var found: Dictionary = {}
	for unit: Dictionary in units:
		if unit.team == 1 and unit.hp > 0:
			var d := pos.distance_to(unit.pos)
			if d < distance:
				distance = d
				found = unit
	return found

func skill() -> void:
	if ended or paused:
		return
	if lord.respawn > 0:
		notice = "領主倒下了，復活後才能旋斬。"
		return
	if skill_cd > 0:
		notice = "旋斬冷卻中，還要 %d 秒。" % ceili(skill_cd)
		return
	skill_cd = BALANCE.SKILL_COOLDOWN
	selected_card = ""
	for unit: Dictionary in units:
		if unit.team == 1 and unit.pos.distance_to(lord.position) < BALANCE.SKILL_RANGE:
			unit.hp -= BALANCE.SKILL_DAMAGE
			burst(shown_at(unit) + Vector2(0,-35),"−%d" % int(BALANCE.SKILL_DAMAGE),RED)
	effects.append({"pos":lord.position,"text":"","color":Color("c38b25"),"life":0.6,"ring":true})
	notice = "領主旋斬！對附近敵軍造成 65 傷害。"

func burst(pos: Vector2, caption: String, color: Color) -> void:
	effects.append({"pos":pos,"text":caption,"color":color,"life":0.7,"ring":false})

func _physics_process(delta: float) -> void:
	if ended or paused:
		return
	elapsed += delta
	gold += income() * delta
	recruit_cd = maxf(0,recruit_cd-delta)
	skill_cd = maxf(0,skill_cd-delta)
	enemy_timer -= delta
	if enemy_timer <= 0:
		spawn_enemy()
		if elapsed > BALANCE.ENEMY_DOUBLE_AFTER:
			spawn_enemy()
		enemy_timer = maxf(BALANCE.ENEMY_MIN_DELAY,BALANCE.ENEMY_BASE_DELAY-elapsed/BALANCE.ENEMY_RAMP_TIME)
	for lane: int in range(GRID_ROWS):
		alarm[lane] = maxf(0,alarm[lane]-delta)
	for unit: Dictionary in units:
		if unit.hp <= 0:
			continue
		unit.cd = maxf(0,unit.cd-delta)
		var forward := 1.0 if unit.team == 0 else -1.0
		# Nearest foe in this lane, ahead or behind (see SIGHT_RANGE).
		var target: Dictionary = {}
		var closest := SIGHT_RANGE
		for other: Dictionary in units:
			if other.team != unit.team and other.lane == unit.lane and other.hp > 0:
				var distance: float = absf(unit.pos.x-other.pos.x)
				if distance < closest:
					closest = distance
					target = other
		var in_melee := not target.is_empty() and closest < MELEE_RANGE
		var hits_lord: bool = unit.team == 1 and lord.respawn <= 0 and unit.pos.distance_to(lord.position) < BALANCE.LORD_TARGET_RANGE
		var at_gate: bool = unit.pos.x >= LAYOUT.gate_stop(1) if unit.team == 0 else unit.pos.x <= LAYOUT.gate_stop(0)
		if hits_lord and not in_melee and lord.position.x != unit.pos.x:
			unit.face = signf(lord.position.x-unit.pos.x)
		elif not target.is_empty() and target.pos.x != unit.pos.x:
			unit.face = signf(target.pos.x-unit.pos.x)
		else:
			unit.face = forward
		if in_melee or hits_lord or (at_gate and target.is_empty()):
			if unit.cd <= 0:
				unit.cd = BALANCE.MILITIA_ATTACK_INTERVAL
				var damage := BALANCE.MILITIA_DAMAGE
				if unit.team == 0 and lord.respawn <= 0 and unit.pos.distance_to(lord.position) < BALANCE.AURA_RANGE:
					damage = BALANCE.MILITIA_BUFF_DAMAGE
				if in_melee:
					target.hp -= damage
					burst(shown_at(target)+Vector2(0,-45),"−%d" % int(damage),INK)
				elif hits_lord:
					lord.damage(damage)
				else:
					hit_gate(1-unit.team,unit.lane,damage)
		else:
			# March forward, or walk toward a foe in sight (possibly back to defend our own gate).
			unit.pos.x += unit.face * BALANCE.MILITIA_SPEED * delta
	for i: int in range(units.size()-1,-1,-1):
		if units[i].hp <= 0:
			if units[i].team == 1:
				gold += BALANCE.KILL_GOLD
			units.remove_at(i)
	for i: int in range(effects.size()-1,-1,-1):
		effects[i].life -= delta
		if effects[i].life <= 0:
			effects.remove_at(i)
	if castle[0] <= 0 or castle[1] <= 0:
		ended = true
		notice = "勝利！敵方主堡已被攻破。" if castle[1] <= 0 else "敗北。整頓軍隊，再戰一次！"
	queue_redraw()

func hit_gate(side: int, lane: int, damage: float) -> void:
	# side: whose gate / castle takes the hit (0 = ours).
	if gates[side][lane] > 0:
		gates[side][lane] = maxf(0,gates[side][lane]-damage)
		if gates[side][lane] <= 0:
			notice = ("第 %d 路城門被攻破！敵軍開始攻打主堡。" if side == 0 else "攻破敵方第 %d 路城門！") % [lane+1]
	else:
		castle[side] = maxf(0,castle[side]-damage)
	if side == 0:
		alarm[lane] = BALANCE.ALARM_DURATION

func toggle_pause() -> void:
	if not ended:
		paused = not paused
		buttons[3].text = "▶" if paused else "Ⅱ"
	queue_redraw()

func restart() -> void:
	get_tree().reload_current_scene()

func label_at(pos: Vector2, caption: String, size: int = 20, color: Color = INK) -> void:
	draw_string(font,pos,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func bar(rect: Rect2, value: float, maximum: float, color: Color) -> void:
	draw_rect(rect,Color("4c4032"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value/maximum,0,1),rect.size.y)),color)

func _draw() -> void:
	if font == null:
		return
	draw_texture_rect(PAPER, Rect2(Vector2.ZERO, LAYOUT.VIEWPORT_SIZE), false)
	panel(LAYOUT.PAGE_FRAME,Color(0.85,0.74,0.53,0.15),Color("80633c"),4)
	panel(LAYOUT.FIELD_FRAME,Color("d8c29a"),Color("b69b60"),4)
	draw_texture_rect(red_castle,LAYOUT.CASTLE_RECTS[0],false)
	draw_texture_rect(blue_castle,LAYOUT.CASTLE_RECTS[1],false)
	for side: int in range(2):
		for row: int in range(2):
			draw_texture_rect(ART.ornament(side + row * 2),Rect2(50+side*1340,120+row*440,155,110),false)
	panel(LAYOUT.HUD_FRAME,Color("e6cea0"),Color("aa8e56"),8)
	for side: int in range(2):
		portrait(LAYOUT.PORTRAITS[side],RED if side == 0 else BLUE,side == 1)
		label_at(LAYOUT.CASTLE_NAMES[side],"紅獅主堡" if side == 0 else "藍旗主堡",17,RED if side == 0 else BLUE)
		bar(LAYOUT.CASTLE_BARS[side],castle[side],BALANCE.CASTLE_HP,RED if side == 0 else BLUE)
		draw_texture_rect(ART.health_frame(),LAYOUT.CASTLE_FRAMES[side],false)
		label_at(LAYOUT.CASTLE_VALUES[side],str(int(castle[side])),17,RED if side == 0 else BLUE)
	panel(LAYOUT.CLOCK_FRAME,Color("e8d5a9"),Color("7b7567"),6)
	label_at(LAYOUT.CLOCK_TEXT,"%02d:%02d" % [int(elapsed)/60,int(elapsed)%60],27,Color("493321"))
	for lane: int in range(GRID_ROWS):
		var y := lane_y(lane)
		if lane == selected:
			draw_rect(Rect2(GRID_ORIGIN + Vector2(0,lane*CELL_SIZE.y),Vector2(LAYOUT.GRID_SIZE.x,CELL_SIZE.y)),Color(0.64,0.48,0.18,0.09))
		for team: int in range(2):
			var x := LAYOUT.gate_icon_x(team)
			if gates[team][lane] > 0:
				draw_texture_rect(red_castle if team == 0 else blue_castle,Rect2(x-18,y-24,36,48),false)
	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLUMNS):
			var rect := Rect2(GRID_ORIGIN + Vector2(col,row)*CELL_SIZE,CELL_SIZE)
			if col < DEPLOY_COLUMNS:
				draw_rect(rect,Color(0.32,0.46,0.20,0.17))
			draw_rect(rect,Color(0.30,0.29,0.23,0.45),false,1)
	draw_line(GRID_ORIGIN+Vector2(DEPLOY_COLUMNS*CELL_SIZE.x,0),GRID_ORIGIN+Vector2(DEPLOY_COLUMNS*CELL_SIZE.x,GRID_ROWS*CELL_SIZE.y),Color("738553"),3)
	for building: Dictionary in buildings:
		if building.hp <= 0:
			continue
		var center := cell_center(building.cell)
		draw_texture_rect(FARM,Rect2(center-Vector2(45,33),Vector2(90,60)),false)
		draw_texture_rect(FARMER,Rect2(center+Vector2(18,-6),Vector2(29,30)),false)
		label_at(center+Vector2(-21,44),"+%.1f/s" % BALANCE.FARM_INCOME,12,Color("49603a"))
	if not selected_card.is_empty() and not ended and not paused:
		var hovered := cell_at(get_global_mouse_position())
		if hovered.x >= 0:
			var valid := can_place(hovered)
			var rect := Rect2(GRID_ORIGIN+Vector2(hovered)*CELL_SIZE,CELL_SIZE)
			draw_rect(rect,Color(0.2,0.75,0.5,0.3) if valid else Color(0.85,0.15,0.12,0.3))
			draw_rect(rect,Color("4a9d72") if valid else Color("bb4233"),false,3)
			var center := cell_center(hovered)
			draw_texture_rect(FARM if selected_card == "farm" else MILITIA,Rect2(center-Vector2(38,43),Vector2(76,76)),false,Color(1,1,1,0.55))
	layout_formations()
	var ordered := units.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.draw.y < b.draw.y)
	# The lord is drawn here as well (not by his own node), so he sorts by depth with the
	# soldiers and stays underneath the pause / result banner.
	var lord_drawn := not lord.visible
	for unit: Dictionary in ordered:
		if not lord_drawn and lord.position.y < unit.draw.y:
			draw_lord()
			lord_drawn = true
		var p: Vector2 = unit.draw + Vector2(0,24)
		var bounce := sin(elapsed*8+unit.phase)*2.0
		draw_ellipse_shadow(p,RED if unit.team == 0 else BLUE)
		draw_set_transform(p,0,Vector2(unit.face,1))
		draw_texture_rect(MILITIA if unit.team == 0 else BLUE_MILITIA,Rect2(-37,-78+bounce,74,79),false)
		draw_set_transform(Vector2.ZERO)
		bar(Rect2(p.x-20,p.y-80,40,4),unit.hp,BALANCE.MILITIA_HP,RED if unit.team == 0 else BLUE)
	if not lord_drawn:
		draw_lord()
	for effect: Dictionary in effects:
		if effect.ring:
			draw_arc(effect.pos,BALANCE.SKILL_RANGE*(1-effect.life/0.6),0,TAU,48,effect.color,4)
		else:
			label_at(effect.pos+Vector2(0,-(0.7-effect.life)*25),effect.text,17,effect.color)
	draw_lane_status()
	panel(LAYOUT.COMMAND_FRAME,Color("e3c999"),Color("aa8e56"),4)
	label_at(LAYOUT.COMMAND_TITLE,"軍需與部署",16,Color("6f4e2e"))
	label_at(LAYOUT.NOTICE_TEXT,notice,15,Color("61462e"))
	panel(LAYOUT.ECONOMY_FRAME,Color("e8d5ab"),Color("b69b67"),6)
	draw_texture_rect(ART.object_icon(0),LAYOUT.GOLD_ICON,false)
	label_at(LAYOUT.GOLD_TEXT,str(int(gold)),32,Color("694523"))
	label_at(LAYOUT.INCOME_TEXT,"+%.1f / 秒" % income(),18,Color("56633d"))
	label_at(LAYOUT.FARM_COUNT_TEXT,"第 %d 路  ·  農田 %d / %d" % [selected+1,farm_count(0),DEPLOY_COLUMNS*GRID_ROWS],17,Color("58442d"))
	for pip: int in range(LAYOUT.GOLD_PIP_COUNT):
		panel(Rect2(LAYOUT.GOLD_PIP_ORIGIN+Vector2(pip*LAYOUT.GOLD_PIP_STEP,0),LAYOUT.GOLD_PIP_SIZE),Color("e0b754") if gold >= (pip+1)*BALANCE.MILITIA_COST else Color("bca878"),Color("665b43"),3)
	label_at(LAYOUT.ECONOMY_HELP,"選卡 → 點格子或按 1–5 · 右鍵取消",14,Color("79674a"))
	panel(LAYOUT.LORD_FRAME,Color("e8d5ab"),Color("b69b67"),6)
	label_at(LAYOUT.LORD_TITLE,"領主指揮",19,Color("563b25"))
	bar(LAYOUT.LORD_BAR,lord.hp,BALANCE.LORD_HP,Color("c85743"))
	label_at(LAYOUT.LORD_HP_TEXT,"%d / %d" % [maxi(0,int(lord.hp)),int(BALANCE.LORD_HP)],16,Color("68492c"))
	label_at(LAYOUT.LORD_STATE_TEXT,"復活中 · %ds" % ceili(lord.respawn) if lord.respawn > 0 else "WASD 移動 · 靠近自動攻擊",16,Color("6d5337"))
	label_at(LAYOUT.LORD_AURA_TEXT,"光環：附近民兵傷害提升",15,Color("6e693b"))
	label_at(LAYOUT.LORD_HELP_TEXT,"Esc 暫停  /  暫停中按 R 重玩",14,Color("79674a"))
	if ended or paused:
		draw_rect(LAYOUT.OVERLAY_RECT,Color(0.19,0.14,0.09,0.95))
		label_at(LAYOUT.OVERLAY_TITLE,notice if ended else "戰局暫停",27,Color("f6e5bf"))
		label_at(LAYOUT.OVERLAY_HELP,"按 R 重新開戰" if ended else "按 Esc 繼續 · 按 R 重新開始",19,Color("d7b677"))

func draw_lane_status() -> void:
	# Drawn over the soldiers: units standing at a gate used to hide its health bar, "破門" and the lane number.
	var pulse := 0.5+0.5*sin(elapsed*10.0)
	for lane: int in range(GRID_ROWS):
		var y := lane_y(lane)
		var warn := alarm[lane] > 0
		draw_circle(Vector2(LAYOUT.gate_icon_x(0),y-31),11.0+(2.5*pulse if warn else 0.0),Color("b8402f").lerp(Color("e8664a"),pulse) if warn else Color("ead6aa"))
		label_at(Vector2(LAYOUT.gate_icon_x(0)-4,y-26),str(lane+1),14,Color("fff3dc") if warn else INK)
		for team: int in range(2):
			var x := LAYOUT.gate_icon_x(team)
			var color := RED if team == 0 else BLUE
			if gates[team][lane] > 0:
				bar(Rect2(x-20,y+25,40,4),gates[team][lane],BALANCE.GATE_HP,color)
			else:
				panel(Rect2(x-23,y-13,46,21),Color("efe0bf"),color,4)
				label_at(Vector2(x-14,y+3),"破門",14,color)

func shown_at(unit: Dictionary) -> Vector2:
	return unit.get("draw",unit.pos)

func layout_formations() -> void:
	# Soldiers of one lane often stand on the very same spot (they all halt 47 px from the same foe),
	# which reads as one soldier. Spread them front-to-back on screen only; combat keeps using `pos`.
	for team: int in range(2):
		var forward := 1.0 if team == 0 else -1.0
		for lane: int in range(GRID_ROWS):
			var column: Array[Dictionary] = []
			for unit: Dictionary in units:
				if unit.team == team and unit.lane == lane:
					column.append(unit)
			column.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pos.x*forward > b.pos.x*forward)
			var limit := INF
			for rank: int in range(column.size()):
				var unit: Dictionary = column[rank]
				var x: float = unit.pos.x*forward
				var crowded := x > limit
				x = minf(x,limit)
				limit = x-FORMATION_GAP
				unit["draw"] = Vector2(x*forward,unit.pos.y+(8.0 if crowded and rank % 2 == 1 else 0.0))

func draw_lord() -> void:
	draw_arc(lord.position+Vector2(0,24),23,0,TAU,32,Color("b88428"),2.0)
	var height := 104.0
	var width := height*LORD_ART.get_width()/float(LORD_ART.get_height())
	draw_set_transform(lord.position+Vector2(0,-24+lord.bob),0,Vector2(-1 if lord.facing_left else 1,1))
	draw_texture_rect(LORD_ART,Rect2(-width/2,-height/2,width,height),false)
	draw_set_transform(Vector2.ZERO)
	bar(Rect2(lord.position.x-26,lord.position.y-80,52,4),lord.hp,BALANCE.LORD_HP,Color("b3382d"))

func draw_ellipse_shadow(pos: Vector2, color: Color) -> void:
	draw_set_transform(pos,0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,23,Color(color,0.3))
	draw_set_transform(Vector2.ZERO)

func panel(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func portrait(center: Vector2, color: Color, flip: bool) -> void:
	draw_circle(center,24,Color("ddc18a"))
	draw_arc(center,23,0,TAU,40,color,2)
	draw_set_transform(center,0,Vector2(-1 if flip else 1,1))
	draw_texture_rect_region(LORD_ART,Rect2(-21,-23,42,46),Rect2(385,40,370,350),Color.WHITE if not flip else Color(0.65,0.8,1))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(ART.portrait_frame(flip),Rect2(center-Vector2(32,34),Vector2(64,74)),false)
