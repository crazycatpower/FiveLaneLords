extends Node2D
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const DeckStore = preload("res://deck_store.gd")
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
var screen := "title"
var player_deck: Array = []
var deck_path := "user://deck.json"
var deck_tab := "unit"
var difficulty := 1
var spectating := false
var menu_notice := ""
var start_button: Button
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
	for pair: Array in [["militia","manuscript-v1/militia-red.png"],["farmer","farmer.png"],["farm","farmland.png"],["castle_red","manuscript-v1/castle-red.png"],["castle_blue","manuscript-v1/castle-red.png"]]:
		textures[pair[0]] = load("res://assets/"+pair[1])
	for kind: String in B.CARDS:
		var file := "res://assets/manuscript-v1/"+kind+".png"
		if ResourceLoader.exists(file): textures[kind] = load(file)
	seed_value = int(Time.get_unix_time_from_system())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.substr(7))
	player_deck = DeckStore.load_deck(deck_path)
	model = Battle.new(seed_value,player_deck)
	show_title()

func start_battle() -> void:
	if not DeckStore.valid(player_deck):
		show_deck()
		return
	DeckStore.save_deck(player_deck,deck_path)
	model = Battle.new(seed_value,player_deck,B.PRESETS[difficulty])
	model.difficulty = difficulty
	model.ai_enabled = [spectating,true]
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
		if e.kind == "breach": notice = ("我方第 %d 路城門被攻破！敵兵走進來就輸了。" if e.team == 1 else "攻破藍旗第 %d 路城門！派兵走進去就贏。") % (e.lane+1)
		if e.kind == "ramp": notice = "墨水產出加快 ×%.1f" % e.multiplier
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

func art(kind: String, _team: int = 0) -> Texture2D:
	return textures.get(kind,textures.militia)

func draw_card(kind: String, rect: Rect2, slot: int = -1) -> void:
	var data: Dictionary = B.CARDS[kind]
	var s := rect.size
	var short: bool = screen == "battle" and model.ink[0] < data.cost
	draw_texture_rect(ART.card(selected == slot and slot >= 0),rect,false)
	draw_texture_rect(art(kind),Rect2(rect.position+s*Vector2(0.17,0.13),s*Vector2(0.66,0.5)),false,Color(0.45,0.45,0.45) if short else Color.WHITE)
	# Name and type sit above the frame's bottom corner flowers (they start ~83% down).
	draw_string(font,rect.position+Vector2(0,s.y*0.74),data.name,HORIZONTAL_ALIGNMENT_CENTER,s.x,17,INK)
	draw_string(font,rect.position+Vector2(0,s.y*0.83),{"unit":"部隊","building":"建築","spell":"法術"}[data.type],HORIZONTAL_ALIGNMENT_CENTER,s.x,12,Color("7a6446"))
	# Ink cost badge, top right.
	var badge := rect.position+Vector2(s.x-19,19)
	draw_circle(badge,15,Color("2f3f5c"))
	draw_arc(badge,15,0,TAU,24,Color("cfaa60"),2)
	draw_string(font,badge+Vector2(-15,6),str(data.cost),HORIZONTAL_ALIGNMENT_CENTER,30,16,Color("f3e6c4"))
	if slot >= 0:
		draw_rect(Rect2(rect.position+Vector2(7,7),Vector2(22,22)),Color("725138"))
		draw_string(font,rect.position+Vector2(7,24),str(slot+1),HORIZONTAL_ALIGNMENT_CENTER,22,14,Color("efdfb9"))
	if short and slot >= 0:
		draw_string(font,rect.position+Vector2(0,s.y*0.42),"差 %d" % ceili(data.cost-model.ink[0]),HORIZONTAL_ALIGNMENT_CENTER,s.x,20,Color("f3e6c4"))
	if slot >= 0 and model.cooldown[0] > 0:
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,rect.size.y*model.cooldown[0]/B.PLAY_COOLDOWN)),Color(0.15,0.1,0.05,0.25))

func _draw() -> void:
	if font == null or model == null: return
	draw_texture_rect(PAPER,Rect2(Vector2.ZERO,L.VIEWPORT_SIZE),false)
	panel(L.PAGE_FRAME,Color(0.85,0.74,0.53,0.15))
	if screen == "battle": draw_battle()
	elif screen == "deck": draw_deck()
	elif screen == "help": draw_help()
	else: draw_title()

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
		team_shadow(b.pos+Vector2(0,30),40,RED if b.team == 0 else BLUE)
		draw_texture_rect(art(b.kind,b.team),Rect2(b.pos-Vector2(45,39),Vector2(90,78)),false,team_tint(b.team))
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
	for arrow: Dictionary in model.projectiles:
		draw_line(arrow.pos-Vector2(12,0),arrow.pos,INK,2)
	draw_preview()
	draw_effects()
	draw_hud()
	if model.paused or model.ended:
		panel(L.OVERLAY_RECT,Color("ead6aa"))
		label_at(L.OVERLAY_TITLE,"戰局暫停" if not model.ended else ("紅獅勝利！我軍攻進藍旗主堡" if model.winner == 0 else "敗北：藍旗士兵攻進了我方主堡"),30)
		label_at(L.OVERLAY_HELP,"空白鍵繼續 · R 重新開始",20)

# Both sides share one art set (producer decision); until recolored art exists, tint the blue side
# and put a team-coloured shadow under every unit and building so sides read at a glance.
func team_tint(team: int) -> Color:
	return Color.WHITE if team == 0 else Color(0.62,0.78,1.25)

func team_shadow(center: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(center,0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,radius,Color(color,0.45))
	draw_set_transform(Vector2.ZERO)

func draw_unit(u: Dictionary) -> void:
	var pos: Vector2 = u.draw
	var bounce := sin(model.elapsed*8+u.phase)*2
	team_shadow(pos+Vector2(0,15),22,RED if u.team == 0 else BLUE)
	draw_set_transform(pos+Vector2(0,bounce),0,Vector2(u.face,1))
	draw_texture_rect(art(u.kind,u.team),Rect2(-32,-54,64,70),false,Color(1.5,1.5,1.5) if u.flash > 0 else team_tint(u.team))
	draw_set_transform(Vector2.ZERO)
	bar(Rect2(pos-Vector2(23,59),Vector2(46,4)),u.hp,u.max_hp,RED if u.team == 0 else BLUE)
	var climb: float = u.get("climb",0.0)
	if climb > 0 and climb < B.RUBBLE_TIME: bar(Rect2(pos-Vector2(23,66),Vector2(46,4)),climb,B.RUBBLE_TIME,Color.GOLD) # clearing the rubble

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
		var standing: int = model.gates[team].filter(func(hp: float) -> bool: return hp > 0).size()
		label_at(Vector2(x,43),("紅獅" if team == 0 else "藍旗")+"  城門 %d / 5" % standing,23,RED if team == 0 else BLUE)
		for lane: int in range(5): bar(Rect2(x+lane*70,53,62,10),model.gates[team][lane],B.GATE_HP,RED if team == 0 else BLUE)
		label_at(Vector2(x+170,43),"墨水 %d / 50" % model.ink[team],18)
	var time := int(model.elapsed)
	label_at(Vector2(725,58),"%02d:%02d" % [time/60,time%60],30,RED if model.multiplier() > 1 else INK)
	if model.multiplier() > 1: label_at(Vector2(722,79),"墨水 ×%.1f" % model.multiplier(),14,RED)
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


func show_title() -> void:
	screen = "title"
	clear_ui()
	button(Rect2(650,330,300,55),"開始對戰",func(): spectating = false; start_battle())
	button(Rect2(650,398,300,55),"觀戰模式",func(): spectating = true; start_battle())
	button(Rect2(650,466,300,55),"牌組編成",show_deck)
	button(Rect2(650,534,300,55),"操作說明",show_help)
	button(Rect2(650,670,300,50),"離開",func(): get_tree().quit())
	button(Rect2(650,602,300,55),"難度："+["簡單","普通","困難"][difficulty],func(): difficulty = (difficulty+1)%3; show_title())
	queue_redraw()

func draw_title() -> void:
	draw_texture_rect(textures.castle_red,Rect2(100,290,350,480),false)
	draw_texture_rect(textures.castle_blue,Rect2(1150,290,350,480),false)
	draw_string(font,Vector2(0,190),"羊皮紙戰記",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,76,INK)
	draw_string(font,Vector2(0,245),"種下村莊，寫下你的戰史。",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,28,INK)
	draw_string(font,Vector2(0,800),"八張村莊牌 · 五路戰線 · 城門一破，敵兵進家就輸",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,23,INK)

func show_deck() -> void:
	screen = "deck"
	clear_ui()
	for i: int in range(3):
		var index := i
		button(Rect2(120+i*300,155,270,45),B.PRESET_NAMES[i],func(): player_deck = B.PRESETS[index].duplicate(); show_deck())
	for i: int in range(3):
		var tab: String = ["unit","building","spell"][i]
		button(Rect2(120+i*210,235,190,44),["部隊","建築","法術"][i],func(): deck_tab = tab; show_deck())
	var index := 0
	for kind: String in B.CARDS:
		if B.CARDS[kind].type != deck_tab: continue
		var card_kind := kind
		var rect := Rect2(120+index%8*170,310,150,190)
		var b := button(rect,"",func(): toggle_deck_card(card_kind))
		b.tooltip_text = card_description(kind)
		b.modulate = Color(1,1,1,0.01)
		index += 1
	button(Rect2(120,805,220,50),"回到標題",show_title)
	start_button = button(Rect2(1220,805,240,50),"儲存並開戰",func(): spectating = false; start_battle())
	start_button.disabled = not DeckStore.valid(player_deck)
	queue_redraw()

func toggle_deck_card(kind: String) -> void:
	if kind in player_deck: player_deck.erase(kind)
	elif player_deck.size() < 8: player_deck.append(kind)
	else: menu_notice = "先取消一張已選卡牌，再加入新卡。"
	if DeckStore.valid(player_deck): DeckStore.save_deck(player_deck,deck_path)
	show_deck()

func draw_deck() -> void:
	label_at(Vector2(120,100),"村莊牌組",48)
	label_at(Vector2(1060,100),"%d / 8 張 · 平均 %.1f 墨水" % [player_deck.size(),DeckStore.average(player_deck)],24)
	var index := 0
	for kind: String in B.CARDS:
		if B.CARDS[kind].type != deck_tab: continue
		var rect := Rect2(120+index%8*170,310,150,190)
		draw_card(kind,rect)
		if kind in player_deck: draw_rect(rect,Color("9b3d2c"),false,4)
		index += 1
	label_at(Vector2(120,555),"已選牌組（點上方卡牌加入或移除）",24)
	for i: int in range(player_deck.size()): draw_card(player_deck[i],Rect2(120+i*170,585,150,190))
	label_at(Vector2(400,840),"需選滿 8 張不同卡牌，並包含農田。" if not DeckStore.valid(player_deck) else menu_notice,20,RED)

func card_description(kind: String) -> String:
	var card: Dictionary = B.CARDS[kind]
	var descriptions := {"farm":"種下三秒後開始，每十秒產出兩滴墨水。","farmer":"兩名農民向前行軍，順路耕田 1.5 秒，農田加速十五秒。","mill":"同一路農田產量速度 +50%，每方一座。","scarecrow":"吸引附近敵兵攻擊，存在二十五秒。","tower":"每 0.8 秒射箭，射程 200，存在四十秒。","harvest":"範圍內農田立即各產兩墨水，八秒加速。","rain":"範圍部隊傷害 200，建築與城門 60。","fire":"部隊傷害 320，建築 640，城門 100。","ox":"首擊 120 並擊退，建築傷害 ×1.5。","healer":"每秒治療附近友軍 12 血。","ram":"穿過部隊，只攻擊建築與城門。","hunter":"射程 170，箭矢飛行 0.35 秒。","knight":"600 生命的重裝主力。","mob":"五名暴民，錯開出場。","militia":"兩名民兵，基本近戰主力。"}
	return "%s · %d 墨水\n%s" % [card.name,card.cost,descriptions.get(kind,"")]

func show_help() -> void:
	screen = "help"
	clear_ui()
	button(Rect2(650,770,300,55),"回到標題",show_title)
	queue_redraw()

func draw_help() -> void:
	panel(Rect2(270,130,1060,600))
	label_at(Vector2(350,215),"操作與勝負",44)
	var lines := ["1–4 或點卡牌選牌，再點戰場放置；右鍵／Esc 取消。","空白鍵暫停；暫停時按 R 重玩，戰鬥中 R 不會重開。","農田自己產墨水；農民從田後方出發，順路耕田加速。","部隊只往前走，領主會自行回防；箭樓可守護後方。","打破對方城門後，該路部隊可部署到第六欄。","城門破了，任何一名敵兵走進家門就輸——沒有時間限制。","三分鐘後墨水產出 ×1.5，五分鐘後 ×2；上限 50。"]
	for i: int in range(lines.size()): label_at(Vector2(350,290+i*52),lines[i],23)
