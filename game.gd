extends Node2D
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")
const ART = preload("res://manuscript_art.gd")
const PAPER = preload("res://assets/parchment-background.png")
const LORD_ART = preload("res://assets/manuscript-v1/lord-simple-v2.png")
const INK := Color("463529")
const RED := Color("9c3d30")
const BLUE := Color("355b78")
var model: RefCounted
var font: Font
var textures: Dictionary = {}
var selected := -1
var notice := "1–4 選牌 · 點戰場放置 · 右鍵取消 · 空白鍵暫停"
var screen := "battle"
var effects: Array[Dictionary] = []
var seed_value := 1
var ui: Array[Control] = []
var fx_enabled := true
var shake_enabled := true
var shake_left := 0.0

func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Noto Serif TC","PMingLiU","Microsoft JhengHei"])
	font = sf
	for pair: Array in [["militia","manuscript-v1/militia-red.png"],["militia_blue","manuscript-v1/militia-blue.png"],["farmer","farmer.png"],["farm","farmland.png"],["castle_red","manuscript-v1/castle-red.png"],["castle_blue","manuscript-v1/castle-blue.png"]]:
		textures[pair[0]] = load("res://assets/"+pair[1])
	seed_value = int(Time.get_unix_time_from_system())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.substr(7))
	start_battle()

func start_battle() -> void:
	model = Battle.new(seed_value)
	selected = -1
	screen = "battle"
	effects.clear()
	clear_ui()
	queue_redraw()

func clear_ui() -> void:
	for control: Control in ui:
		remove_child(control)
		control.queue_free()
	ui.clear()

func button(rect: Rect2, caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ead6aa")
	style.border_color = Color("846539")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal",style)
	b.add_theme_color_override("font_color",INK)
	b.pressed.connect(action)
	add_child(b)
	ui.append(b)
	return b

func _physics_process(dt: float) -> void:
	if screen != "battle": return
	model.step(dt)
	consume_events()

func consume_events() -> void:
	for e: Dictionary in model.events:
		if e.kind == "breach": notice = "第 %d 路破門！" % (model.cell_at(Vector2(L.GRID_ORIGIN.x,e.pos.y)).y+1)
		if e.kind == "overflow" and e.team == 0: notice = "墨水已滿 50，繼續產出的墨水會浪費。"
		if fx_enabled:
			var copy := e.duplicate()
			copy.life = 0.7
			effects.append(copy)
	model.events.clear()

func _process(dt: float) -> void:
	for e: Dictionary in effects: e.life -= dt
	effects = effects.filter(func(e: Dictionary) -> bool: return e.life > 0)
	queue_redraw()

func card_rect(slot: int) -> Rect2:
	return Rect2(410+slot*145,730,132,158)

func _unhandled_input(event: InputEvent) -> void:
	if screen != "battle": return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4: selected = event.keycode-KEY_1
		if event.keycode == KEY_ESCAPE: selected = -1
		if event.keycode == KEY_SPACE: model.paused = not model.paused
		if event.keycode == KEY_R:
			if model.paused or model.ended: start_battle()
			else: notice = "戰鬥中 R 不重開；空白鍵暫停後可重玩。"
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: selected = -1
		if event.button_index == MOUSE_BUTTON_LEFT:
			var pos := get_global_mouse_position()
			if L.PAUSE_RECT.has_point(pos): model.paused = not model.paused
			for i: int in range(4):
				if card_rect(i).has_point(pos):
					selected = i
					return
			if selected >= 0 and model.play(0,selected,pos): selected = -1

func label_at(pos: Vector2, text: String, size: int = 20, color: Color = INK) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2, fill: Color = Color("e8d5ab"), border: Color = Color("9b7844")) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	draw_style_box(style,rect)

func bar(rect: Rect2, value: float, maximum: float, color: Color) -> void:
	draw_rect(rect,Color("69543c"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value/maximum,0,1),rect.size.y)),color)

func art(kind: String, team: int = 0) -> Texture2D:
	if team == 1 and textures.has(kind+"_blue"): return textures[kind+"_blue"]
	return textures.get(kind,textures.militia)

func draw_card(kind: String, rect: Rect2, slot: int = -1) -> void:
	var data: Dictionary = B.CARDS[kind]
	draw_texture_rect(ART.card(selected == slot and slot >= 0),rect,false)
	var tint := Color.WHITE if model.ink[0] >= data.cost else Color(0.45,0.45,0.45)
	draw_texture_rect(art(kind),Rect2(rect.position+Vector2(22,24),Vector2(rect.size.x-44,82)),false,tint)
	label_at(rect.position+Vector2(14,130),data.name,18)
	label_at(rect.position+Vector2(rect.size.x-29,26),str(data.cost),19)
	label_at(rect.position+Vector2(12,23),str(slot+1) if slot >= 0 else "次",15)
	if slot >= 0 and model.ink[0] < data.cost: label_at(rect.position+Vector2(18,149),"差 %d 墨水" % ceili(data.cost-model.ink[0]),12,RED)
	if slot >= 0 and model.cooldown[0] > 0:
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,rect.size.y*model.cooldown[0]/B.PLAY_COOLDOWN)),Color(0.15,0.1,0.05,0.25))

func _draw() -> void:
	if font == null or model == null: return
	draw_texture_rect(PAPER,Rect2(Vector2.ZERO,L.VIEWPORT_SIZE),false)
	panel(L.PAGE_FRAME,Color(0.85,0.74,0.53,0.15))
	draw_battle()

func draw_battle() -> void:
	panel(L.FIELD_FRAME,Color("d8c29a"))
	draw_texture_rect(textures.castle_red,L.CASTLE_RECTS[0],false)
	draw_texture_rect(textures.castle_blue,L.CASTLE_RECTS[1],false)
	for row: int in range(5):
		for col: int in range(9):
			var cell := Vector2i(col,row)
			var rect := Rect2(L.GRID_ORIGIN+Vector2(cell)*L.CELL_SIZE,L.CELL_SIZE)
			if selected >= 0 and model.can_play(0,selected,L.cell_center(cell)): draw_rect(rect,Color(0.3,0.5,0.2,0.19))
			draw_rect(rect,Color(0.3,0.25,0.2,0.35),false)
	for b: Dictionary in model.buildings:
		draw_texture_rect(art(b.kind,b.team),Rect2(b.pos-Vector2(45,39),Vector2(90,78)),false)
		bar(Rect2(b.pos-Vector2(30,43),Vector2(60,4)),b.hp,b.max_hp,RED if b.team == 0 else BLUE)
		if b.boost_until > model.elapsed: draw_arc(b.pos,37,0,TAU,20,Color.GOLD,2)
	layout_formations()
	var ordered: Array = model.units.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.draw.y < b.draw.y)
	for u: Dictionary in ordered: draw_unit(u)
	for lord: Dictionary in model.lords: draw_lord(lord)
	for lane: int in range(5):
		var y := L.cell_center(Vector2i(0,lane)).y
		for team: int in range(2):
			var x := L.gate_icon_x(team)
			panel(Rect2(x-18,y-24,36,45),RED if team == 0 else BLUE)
			label_at(Vector2(x-8,y+5),str(lane+1),20,Color("f6e5bf"))
			bar(Rect2(x-22,y+28,44,4),model.gates[team][lane],B.GATE_HP,RED if team == 0 else BLUE)
		if model.alarm[lane] > 0: draw_circle(Vector2(235,y-34),8,RED)
		elif model.building_alarm[lane] > 0: draw_circle(Vector2(235,y-34),8,Color.GOLD)
	draw_preview()
	draw_effects()
	draw_hud()
	if model.paused or model.ended:
		panel(L.OVERLAY_RECT,Color("ead6aa"))
		label_at(L.OVERLAY_TITLE,"戰局暫停" if not model.ended else ("紅獅勝利" if model.winner == 0 else "藍旗勝利"),30)
		label_at(L.OVERLAY_HELP,"空白鍵繼續 · R 重新開始",20)

func draw_unit(u: Dictionary) -> void:
	var pos: Vector2 = u.draw
	var bounce := sin(model.elapsed*8+u.phase)*2
	draw_set_transform(pos+Vector2(0,bounce),0,Vector2(u.face,1))
	draw_texture_rect(art(u.kind,u.team),Rect2(-32,-54,64,70),false,Color(1.5,1.5,1.5) if u.flash > 0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	bar(Rect2(pos-Vector2(23,59),Vector2(46,4)),u.hp,u.max_hp,RED if u.team == 0 else BLUE)

func draw_lord(lord: Dictionary) -> void:
	if lord.hp <= 0: return
	draw_texture_rect(LORD_ART,Rect2(lord.pos-Vector2(39,67),Vector2(78,94)),false,Color.WHITE if lord.team == 0 else Color(0.6,0.8,1))
	bar(Rect2(lord.pos-Vector2(30,72),Vector2(60,4)),lord.hp,B.LORD_HP,RED if lord.team == 0 else BLUE)

func layout_formations() -> void:
	for team: int in range(2):
		var forward := 1.0 if team == 0 else -1.0
		for lane: int in range(5):
			var column: Array = model.units.filter(func(u: Dictionary) -> bool: return u.team == team and u.lane == lane)
			column.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pos.x*forward > b.pos.x*forward)
			var limit := INF
			for u: Dictionary in column:
				var x := minf(u.pos.x*forward,limit)
				limit = x-L.FORMATION_GAP
				u.draw = Vector2(x*forward,u.pos.y)

func draw_preview() -> void:
	if selected < 0: return
	var pos := get_global_mouse_position()
	var cell: Vector2i = model.cell_at(pos)
	if cell.x < 0: return
	var kind: String = model.decks[0][selected]
	var data: Dictionary = B.CARDS[kind]
	var color := Color(0.2,0.7,0.3,0.35) if model.can_play(0,selected,pos) else Color(0.8,0.1,0.1,0.35)
	if data.type == "spell": draw_circle(pos,data.radius,color)
	else:
		draw_texture_rect(art(kind),Rect2(L.cell_center(cell)-Vector2(35,40),Vector2(70,80)),false,Color(1,1,1,0.5))
		if data.type == "unit":
			draw_line(L.cell_center(cell),Vector2(L.gate_stop(1),L.cell_center(cell).y),color,3)
			if kind == "farmer":
				for b: Dictionary in model.buildings:
					if b.kind == "farm" and b.team == 0 and b.cell.y == cell.y and b.cell.x >= cell.x: draw_circle(b.pos,40,color,false,3)

func draw_effects() -> void:
	for e: Dictionary in effects:
		if e.kind == "ink": draw_circle(e.pos.lerp(Vector2(150,790),1-e.life/0.7),6,Color("293b59"))
		elif e.kind == "spell": draw_circle(e.pos,e.get("radius",50.0)*(1-e.life/0.7),Color(0.7,0.3,0.1,e.life*0.4))
		elif e.kind == "cultivate": draw_arc(e.pos,30,0,TAU,16,Color.GOLD,3)

func draw_hud() -> void:
	panel(L.HUD_FRAME)
	for team: int in range(2):
		var x := 65.0 if team == 0 else 1050.0
		label_at(Vector2(x,43),("紅獅" if team == 0 else "藍旗")+"  ♛ %d" % model.crowns[team],23,RED if team == 0 else BLUE)
		bar(Rect2(x,53,350,10),model.castle[team],B.CASTLE_HP,RED if team == 0 else BLUE)
		label_at(Vector2(x+170,43),"墨水 %d / 50" % model.ink[team],18)
	var time := maxi(0,int(B.MATCH_TIME-model.elapsed))
	label_at(Vector2(725,58),"%02d:%02d" % [time/60,time%60],30)
	panel(L.PAUSE_RECT)
	label_at(L.PAUSE_RECT.position+Vector2(10,27),"Ⅱ",23)
	panel(L.COMMAND_FRAME)
	label_at(Vector2(50,723),notice,16)
	label_at(Vector2(65,780),"墨水 %d / 50" % model.ink[0],29)
	for i: int in range(10):
		panel(Rect2(65+i*29,797,22,12),Color("304461") if model.ink[0] >= (i+1)*5 else Color("b9a57e"))
	label_at(Vector2(65,840),"每秒 +%.1f · 農田 %d" % [model.production_rate(0),model.count_buildings(0)],20)
	for i: int in range(4): draw_card(model.decks[0][i],card_rect(i),i)
	draw_card(model.decks[0][4],Rect2(1000,730,120,158))
	label_at(Vector2(1150,780),"雙方領主",22)
	for lord: Dictionary in model.lords:
		var y: float = 815+lord.team*42
		label_at(Vector2(1150,y),"%s  %d / 900" % ["紅獅" if lord.team == 0 else "藍旗",maxi(0,int(lord.hp))],18)

