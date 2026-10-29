extends Node2D
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const DeckStore = preload("res://deck_store.gd")
const Battle = preload("res://battle.gd")
const Tutorial = preload("res://tutorial.gd")
const ART = preload("res://manuscript_art.gd")
const PAPER = preload("res://assets/parchment-background.png")
const LORD_ART = preload("res://assets/manuscript-v1/lord-simple-v2.png")
const INK := Color("463529")
const RED := Color("9c3d30")
const BLUE := Color("355b78")
var model: RefCounted
var font: Font
var textures: Dictionary = {}
var blue_art: Dictionary = {}
const ROMAN := ["I","II","III","IV","V"]
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
var sound: Node
var sound_enabled := true
var hover_slot := -1
var dragging := false
var press_pos := Vector2.ZERO
var press_was_selected := false
var speed := 1
var tutorial: RefCounted = null
const RESULT_RECT := Rect2(380,170,840,380)
const SPEEDS := [1,2,4,8]
const SPEED_RECTS := [Rect2(1360,826,46,36),Rect2(1412,826,46,36),Rect2(1464,826,46,36),Rect2(1516,826,46,36)]

func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Noto Serif TC","PMingLiU","Microsoft JhengHei"])
	# Bundled Noto Serif TC subset (tools/build_font.py); the system font only covers glyphs it lacks.
	var bundled: FontFile = load("res://assets/fonts/ManuscriptSerif-subset.ttf")
	if bundled != null:
		bundled.fallbacks = [sf]
		font = bundled
	else: font = sf
	for pair: Array in [["militia","manuscript-v1/militia-red.png"],["farmer","farmer.png"],["farm","farmland.png"],["castle_red","manuscript-v1/castle-red.png"],["castle_blue","manuscript-v1/castle-red.png"]]:
		textures[pair[0]] = load("res://assets/"+pair[1])
	for kind: String in B.CARDS:
		var file := "res://assets/manuscript-v1/"+kind+".png"
		if ResourceLoader.exists(file): textures[kind] = load(file)
	for pair: Array in [["gate","gate"],["inkpot","ink"],["crest","crown"]]:
		textures[pair[0]] = load("res://assets/manuscript-v1/"+pair[1]+".png")
	textures["lord"] = LORD_ART
	# One shared art set (producer decision): the blue side is made by swapping red cloth to blue,
	# not by tinting the whole picture (that turned red into purple and darkened the fields).
	for kind: String in textures:
		if kind != "castle_blue": blue_art[kind] = recolor_blue(textures[kind],256 if kind == "castle_red" else 180)
	textures.castle_blue = textures.castle_red
	blue_art.castle_blue = blue_art.castle_red
	seed_value = int(Time.get_unix_time_from_system())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.substr(7))
	load_settings()
	sound = preload("res://sound_bank.gd").new()
	add_child(sound)
	sound.enabled = sound_enabled
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
	tutorial = null
	enter_battle("觀戰中：AI 操控雙方。1–4 或 + / − 調整速度，空白鍵暫停。" if spectating else "拖曳卡牌到戰場，或按 1–4 選牌再點格子 · 右鍵取消 · 空白鍵暫停")

# T10: scripted first match with a fixed deck; the blue side stays idle until the last step.
func start_tutorial() -> void:
	spectating = false
	model = Battle.new(seed_value,Tutorial.DECK.duplicate(),B.PRESETS[0].duplicate())
	model.difficulty = 0
	model.ai_enabled = [false,true]
	model.ai_start = 1e9
	model.lord_active[1] = false
	model.add_building(1,Vector2i(7,2),"farm") # practice target for the fire step
	tutorial = Tutorial.new()
	enter_battle(tutorial.caption())
	prepare_tutorial_step()

func prepare_tutorial_step() -> void:
	if tutorial == null: return
	if tutorial.complete:
		model.ai_start = model.elapsed+5.0
		model.lord_active[1] = true
		notice = tutorial.caption()
		return
	var step: Dictionary = tutorial.current()
	var deck: Array = model.decks[0]
	var index := deck.find(step.card)
	if index >= 4:
		deck[index] = deck[0]
		deck[0] = step.card
		index = 0
	model.hand_cd[0][index] = 0.0 # the tutorial never makes the player wait for the card it asks for
	model.ink[0] = maxf(model.ink[0],B.CARDS[step.card].cost+2.0)
	if step.done == "breach": model.gates[1][2] = minf(model.gates[1][2],40.0)
	notice = tutorial.caption()

func restart() -> void:
	if tutorial != null: start_tutorial()
	else: start_battle()

func enter_battle(message: String) -> void:
	selected = -1
	dragging = false
	speed = 1
	position = Vector2.ZERO
	notice = message
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
	# Spectate mode can fast-forward: several fixed steps per frame, so results match 1x exactly.
	for i: int in range(speed if spectating else 1):
		model.step(dt)
		var advanced: bool = tutorial != null and tutorial.observe(model.events)
		consume_events()
		if advanced: prepare_tutorial_step()

func consume_events() -> void:
	for e: Dictionary in model.events:
		if e.kind == "breach": notice = ("我方第 %d 路城門被攻破！敵兵走進來就輸了。" if e.team == 1 else "攻破藍旗第 %d 路城門！派兵走進去就贏。") % (e.lane+1)
		if e.kind == "ramp": notice = "墨水產出與卡牌冷卻加快 ×%.1f" % e.multiplier
		if e.kind == "overflow" and e.team == 0 and not spectating: notice = "墨水已滿 50，繼續產出的墨水會浪費。"
		if sound != null: sound.cue(e.kind)
		if e.kind == "breach" and shake_enabled: shake_left = 0.25
		if fx_enabled:
			var copy := e.duplicate()
			copy.life = {"burn":5.0,"death":0.35,"play":0.45,"ink":0.6}.get(e.kind,0.7)
			copy.duration = copy.life
			effects.append(copy)
	model.events.clear()

func _process(dt: float) -> void:
	if model != null and model.paused: dt = 0
	shake_left = maxf(0,shake_left-dt)
	position = Vector2(sin(shake_left*180),cos(shake_left*210))*shake_left*18 if shake_enabled and shake_left > 0 else Vector2.ZERO
	for e: Dictionary in effects: e.life -= dt
	effects = effects.filter(func(e: Dictionary) -> bool: return e.life > 0)
	queue_redraw()

func card_rect(slot: int) -> Rect2:
	return Rect2(410+slot*145,730,132,158)

func card_at(pos: Vector2) -> int:
	for i: int in range(4):
		if card_rect(i).has_point(pos): return i
	return -1

func toggle_pause() -> void:
	if not model.ended: model.paused = not model.paused

func set_speed(value: int) -> void:
	speed = value
	notice = "觀戰速度 ×%d" % speed

# Buttons on the pause / result banner: [rect, caption, action].
func overlay_buttons() -> Array:
	var y := RESULT_RECT.end.y-60 if model.ended else L.OVERLAY_RECT.position.y+95
	var items: Array = []
	if not model.ended: items.append([Rect2(490,y,190,40),"繼續",toggle_pause])
	items.append([Rect2(700,y,190,40),"重新開始",restart])
	items.append([Rect2(910,y,190,40),"回到標題",show_title])
	return items

func try_play(slot: int, pos: Vector2) -> bool:
	var reason: String = model.play_error(0,slot,pos)
	if reason.is_empty() and model.play(0,slot,pos):
		selected = -1
		return true
	notice = reason
	effects.append({"kind":"fail","pos":pos,"life":0.5,"duration":0.5})
	if sound != null: sound.cue("fail")
	return false

func _unhandled_input(event: InputEvent) -> void:
	if screen != "battle": return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			var index: int = event.keycode-KEY_1
			if spectating: set_speed(SPEEDS[index])
			else: selected = -1 if selected == index else index
		if spectating and event.keycode in [KEY_EQUAL,KEY_KP_ADD,KEY_PLUS]: set_speed(SPEEDS[mini(SPEEDS.find(speed)+1,SPEEDS.size()-1)])
		if spectating and event.keycode in [KEY_MINUS,KEY_KP_SUBTRACT]: set_speed(SPEEDS[maxi(SPEEDS.find(speed)-1,0)])
		if event.keycode == KEY_ESCAPE:
			if selected >= 0: selected = -1
			else: toggle_pause()
		if event.keycode == KEY_SPACE: toggle_pause()
		if event.keycode == KEY_R:
			if model.paused or model.ended: restart()
			else: notice = "戰鬥中 R 不重開；空白鍵暫停後可重玩。"
	if event is InputEventMouseMotion:
		hover_slot = -1 if spectating else card_at(event.position)
	if event is InputEventMouseButton:
		var pos: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected = -1
			dragging = false
		if event.button_index != MOUSE_BUTTON_LEFT: return
		if event.pressed:
			if model.paused or model.ended:
				for item: Array in overlay_buttons():
					if item[0].has_point(pos):
						item[2].call()
						return
				if L.PAUSE_RECT.has_point(pos): toggle_pause()
				return
			if L.PAUSE_RECT.has_point(pos):
				toggle_pause()
				return
			if spectating:
				for i: int in range(SPEEDS.size()):
					if SPEED_RECTS[i].has_point(pos): set_speed(SPEEDS[i])
				return
			var slot := card_at(pos)
			if slot >= 0:
				# Press on a card selects it and starts a drag; releasing over the field plays it.
				press_was_selected = selected == slot
				selected = slot
				dragging = true
				press_pos = pos
				return
			if selected >= 0: try_play(selected,pos)
		elif dragging:
			dragging = false
			var slot := card_at(pos)
			if slot < 0 and pos.distance_to(press_pos) > 12 and selected >= 0: try_play(selected,pos)
			elif slot == selected and press_was_selected and pos.distance_to(press_pos) <= 12: selected = -1 # clicking the selected card again puts it back

func label_at(pos: Vector2, text: String, size: int = 20, color: Color = INK) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2, fill: Color = Color("ecdcb6"), border: Color = INK) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(border,0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	draw_style_box(style,rect)
	if rect.size.x > 30 and rect.size.y > 20: draw_rect(rect.grow(-4),Color(border,0.3),false,1)

func bar(rect: Rect2, value: float, maximum: float, color: Color) -> void:
	draw_rect(rect.grow(1),Color(INK,0.8))
	draw_rect(rect,Color("dccba3"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value/maximum,0,1),rect.size.y)),color)

# Hand-drawn ink stroke: a slightly wavering line instead of a ruler-straight one.
func ink_line(a: Vector2, b: Vector2, seed: float, color: Color = Color(INK,0.35), width: float = 1.6) -> void:
	var points := PackedVector2Array()
	var normal := (b-a).orthogonal().normalized()
	for i: int in range(33):
		var t := i/32.0
		points.append(a.lerp(b,t)+normal*(sin(t*17.0+seed*3.1)*1.4+sin(t*43.0+seed)*0.6))
	draw_polyline(points,color,width,true)

# Manuscript-style diagonal hatching clipped to a rectangle.
func hatch(rect: Rect2, color: Color, step: float = 13.0) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var d := -h
	while d < w:
		var x0 := d
		var y0 := h
		var x1 := d+h
		var y1 := 0.0
		if x0 < 0:
			y0 += x0
			x0 = 0
		if x1 > w:
			y1 += x1-w
			x1 = w
		if x0 < x1: draw_line(rect.position+Vector2(x0,y0),rect.position+Vector2(x1,y1),color,1.2,true)
		d += step

func ink_frame(rect: Rect2) -> void:
	draw_rect(rect,Color(INK,0.8),false,3)
	draw_rect(rect.grow(-6),Color(INK,0.45),false,1)

func art(kind: String, team: int = 0) -> Texture2D:
	if team == 1 and blue_art.has(kind): return blue_art[kind]
	return textures.get(kind,textures.militia)

# Copy of a texture with saturated reds turned to the blue banner colour; other colours untouched.
static func recolor_blue(source: Texture2D, max_size: int) -> Texture2D:
	var img := source.get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var scale := minf(1.0,float(max_size)/maxf(img.get_width(),img.get_height()))
	if scale < 1.0: img.resize(maxi(1,roundi(img.get_width()*scale)),maxi(1,roundi(img.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c := img.get_pixel(x,y)
			if c.a < 0.05 or c.s < 0.33 or c.v < 0.18 or (c.h > 0.07 and c.h < 0.93): continue
			c.h = 0.6
			c.s = minf(1.0,c.s*0.95)
			c.v = c.v*0.9
			img.set_pixel(x,y,c)
	return ImageTexture.create_from_image(img)

func draw_card(kind: String, rect: Rect2, slot: int = -1) -> void:
	var data: Dictionary = B.CARDS[kind]
	var s := rect.size
	var short: bool = screen == "battle" and model.ink[0] < data.cost
	draw_texture_rect(ART.card(selected == slot and slot >= 0),rect,false)
	draw_texture_rect(art(kind),Rect2(rect.position+s*Vector2(0.17,0.13),s*Vector2(0.66,0.5)),false,Color(0.45,0.45,0.45) if short else Color.WHITE)
	# Name and type sit above the frame's bottom corner flowers (they start ~83% down).
	draw_string(font,rect.position+Vector2(0,s.y*0.74),data.name,HORIZONTAL_ALIGNMENT_CENTER,s.x,17,INK)
	draw_string(font,rect.position+Vector2(0,s.y*0.83),"%s · 冷卻 %ds" % [data.role,int(data.cooldown)] if screen != "battle" else data.role,HORIZONTAL_ALIGNMENT_CENTER,s.x,12,Color("7a6446"))
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
	if slot >= 0 and screen == "battle" and model.hand_cd[0][slot] > 0:
		var left: float = model.hand_cd[0][slot]
		draw_rect(Rect2(rect.position+Vector2(6,6),Vector2(rect.size.x-12,(rect.size.y-12)*clampf(left/maxf(0.1,data.cooldown),0,1))),Color(0.12,0.08,0.04,0.45))
		draw_string(font,rect.position+Vector2(0,s.y*0.45),"%.0f" % ceilf(left),HORIZONTAL_ALIGNMENT_CENTER,s.x,30,Color("fff3dc"))

func _draw() -> void:
	if font == null or model == null: return
	draw_texture_rect(PAPER,Rect2(Vector2.ZERO,L.VIEWPORT_SIZE),false)
	panel(L.PAGE_FRAME,Color(0.85,0.74,0.53,0.15))
	if screen == "battle": draw_battle()
	elif screen == "deck": draw_deck()
	elif screen == "help": draw_help()
	elif screen == "settings": draw_string(font,Vector2(0,220),"畫面與音效設定",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,40,INK)
	else: draw_title()

func draw_battle() -> void:
	var field: Rect2 = L.FIELD_FRAME
	draw_texture_rect_region(PAPER,field,Rect2(field.position*0.6,field.size*0.6))
	draw_rect(field,Color(0.98,0.93,0.80,0.28))
	ink_frame(field)
	var corner := Vector2(96,86)
	draw_texture_rect(ART.ornament(0),Rect2(field.position+Vector2(8,8),corner),false,Color(1,1,1,0.85))
	draw_texture_rect(ART.ornament(1),Rect2(Vector2(field.end.x-8-corner.x,field.position.y+8),corner),false,Color(1,1,1,0.85))
	draw_texture_rect(ART.ornament(2),Rect2(Vector2(field.position.x+8,field.end.y-8-corner.y),corner),false,Color(1,1,1,0.85))
	draw_texture_rect(ART.ornament(3),Rect2(field.end-Vector2(8,8)-corner,corner),false,Color(1,1,1,0.85))
	draw_texture_rect(art("castle_red",0),L.CASTLE_RECTS[0],false)
	draw_texture_rect(art("castle_blue",1),L.CASTLE_RECTS[1],false)
	var grid := Rect2(L.GRID_ORIGIN,L.GRID_SIZE)
	var zone := Vector2(3*L.CELL_SIZE.x,L.GRID_SIZE.y)
	# Deploy zones are hatched in each side's ink; a breached lane's extra columns get a lighter hatch.
	hatch(Rect2(grid.position,zone),Color(RED,0.2))
	hatch(Rect2(grid.position+Vector2(6*L.CELL_SIZE.x,0),zone),Color(BLUE,0.2))
	for lane: int in range(5):
		var row_y := grid.position.y+lane*L.CELL_SIZE.y
		if model.gates[1][lane] <= 0: hatch(Rect2(Vector2(grid.position.x+zone.x,row_y),Vector2(zone.x,L.CELL_SIZE.y)),Color(RED,0.1),18)
		if model.gates[0][lane] <= 0: hatch(Rect2(Vector2(grid.position.x+zone.x,row_y),Vector2(zone.x,L.CELL_SIZE.y)),Color(BLUE,0.1),18)
	if selected >= 0:
		for row: int in range(5):
			for col: int in range(9):
				var cell := Vector2i(col,row)
				if model.can_play(0,selected,L.cell_center(cell)): draw_rect(Rect2(L.GRID_ORIGIN+Vector2(cell)*L.CELL_SIZE,L.CELL_SIZE).grow(-4),Color(0.35,0.55,0.2,0.16))
	for lane: int in range(6):
		var y := grid.position.y+lane*L.CELL_SIZE.y
		ink_line(Vector2(grid.position.x,y),Vector2(grid.end.x,y),lane,Color(INK,0.45 if lane == 0 or lane == 5 else 0.28))
	for col: int in [3,6]:
		var x := grid.position.x+col*L.CELL_SIZE.x
		var y := grid.position.y
		while y < grid.end.y:
			draw_line(Vector2(x,y),Vector2(x,minf(y+9,grid.end.y)),Color(INK,0.4),1.5)
			y += 16
	for lane: int in range(5):
		draw_string(font,Vector2(grid.position.x+6,grid.position.y+lane*L.CELL_SIZE.y+20),ROMAN[lane],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(INK,0.6))
	for b: Dictionary in model.buildings:
		team_shadow(b.pos+Vector2(0,30),40,Color(0.25,0.17,0.08))
		draw_texture_rect(art(b.kind,b.team),Rect2(b.pos-Vector2(45,39),Vector2(90,78)),false)
		bar(Rect2(b.pos-Vector2(30,43),Vector2(60,4)),b.hp,b.max_hp,RED if b.team == 0 else BLUE)
		if b.boost_until > model.elapsed: draw_arc(b.pos,37,0,TAU,20,Color.GOLD,2)
	layout_formations()
	var ordered: Array = model.units.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.draw.y < b.draw.y)
	for u: Dictionary in ordered: draw_unit(u)
	for lord: Dictionary in model.lords: draw_lord(lord)
	var pulse := 0.5+0.5*sin(model.elapsed*10.0)
	for lane: int in range(5):
		var y := L.cell_center(Vector2i(0,lane)).y
		for team: int in range(2):
			var x := L.gate_icon_x(team)
			var standing: bool = model.gates[team][lane] > 0
			var gate_rect := Rect2(x-27,y-30,54,50)
			if standing: draw_texture_rect(art("gate",team),gate_rect,false)
			else:
				draw_texture_rect(art("gate",team),gate_rect,false,Color(0.55,0.5,0.45,0.35))
				for i: int in range(7): draw_circle(Vector2(x-18+i*6,y+16+sin(i*2.3)*3),3+(i%3),Color(0.45,0.38,0.3,0.8))
			bar(Rect2(x-22,y+24,44,4),model.gates[team][lane],B.GATE_HP,RED if team == 0 else BLUE)
		var gx := L.gate_icon_x(0)
		if model.alarm[lane] > 0: draw_arc(Vector2(gx,y-4),34+4*pulse,0,TAU,28,Color(RED,0.5+0.4*pulse),3)
		elif model.building_alarm[lane] > 0: draw_arc(Vector2(gx,y-4),34,0,TAU,28,Color(0.85,0.6,0.1,0.7),2)
	for arrow: Dictionary in model.projectiles:
		draw_line(arrow.pos-Vector2(12,0),arrow.pos,INK,2)
	draw_preview()
	draw_effects()
	draw_hud()
	if tutorial != null and not model.ended:
		panel(Rect2(290,98,1020,34),Color("f6ead0"))
		draw_string(font,Vector2(290,121),tutorial.caption(),HORIZONTAL_ALIGNMENT_CENTER,1020,18,INK)
	if model.ended: draw_result()
	elif model.paused:
		panel(L.OVERLAY_RECT,Color("efe0bd"))
		draw_string(font,L.OVERLAY_RECT.position+Vector2(0,58),"戰局暫停" if not model.ended else ("紅獅勝利！我軍攻進藍旗主堡" if model.winner == 0 else "敗北：藍旗士兵攻進了我方主堡"),HORIZONTAL_ALIGNMENT_CENTER,L.OVERLAY_RECT.size.x,30,INK)
		for item: Array in overlay_buttons():
			panel(item[0],Color("f6ead0"))
			draw_string(font,item[0].position+Vector2(0,27),item[1],HORIZONTAL_ALIGNMENT_CENTER,item[0].size.x,20,INK)

# T10 result screen: who won and how, with both sides' match statistics.
func draw_result() -> void:
	var r := RESULT_RECT
	panel(r,Color("efe0bd"))
	ink_frame(r.grow(-8))
	var title := "紅獅勝利！我軍攻進藍旗主堡" if model.winner == 0 else "敗北：藍旗士兵攻進了我方主堡"
	draw_string(font,r.position+Vector2(0,62),title,HORIZONTAL_ALIGNMENT_CENTER,r.size.x,32,RED if model.winner == 0 else BLUE)
	var t := int(model.elapsed)
	draw_string(font,r.position+Vector2(0,96),"戰鬥時間 %02d:%02d" % [t/60,t%60],HORIZONTAL_ALIGNMENT_CENTER,r.size.x,18,INK)
	var rows: Array = [["打破的城門","breaches"],["產出墨水","produced"],["浪費的墨水","wasted"],["種下農田","planted"],["被燒掉的田","burned"],["出牌數","plays"]]
	var left := r.position.x+170
	draw_string(font,Vector2(left+210,r.position.y+135),"紅獅",HORIZONTAL_ALIGNMENT_CENTER,120,20,RED)
	draw_string(font,Vector2(left+350,r.position.y+135),"藍旗",HORIZONTAL_ALIGNMENT_CENTER,120,20,BLUE)
	for i: int in range(rows.size()):
		var y := r.position.y+168+i*26
		draw_string(font,Vector2(left,y),rows[i][0],HORIZONTAL_ALIGNMENT_LEFT,-1,18,INK)
		for team: int in range(2):
			var value: float = result_value(team,rows[i][1])
			draw_string(font,Vector2(left+210+team*140,y),str(int(value)),HORIZONTAL_ALIGNMENT_CENTER,120,18,INK)
	for item: Array in overlay_buttons():
		panel(item[0],Color("f6ead0"))
		draw_string(font,item[0].position+Vector2(0,27),item[1],HORIZONTAL_ALIGNMENT_CENTER,item[0].size.x,20,INK)

func result_value(team: int, key: String) -> float:
	if key == "breaches": return model.gates[1-team].filter(func(hp: float) -> bool: return hp <= 0).size()
	return float(model.stats[team].get(key,0))

func team_shadow(center: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(center,0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,radius,Color(color,0.45))
	draw_set_transform(Vector2.ZERO)

func draw_unit(u: Dictionary) -> void:
	var pos: Vector2 = u.draw-Vector2(u.face*4,0) if fx_enabled and u.flash > 0 else u.draw # small knockback on hit
	var bounce := sin(model.elapsed*8+u.phase)*2
	team_shadow(pos+Vector2(0,15),22,Color(0.25,0.17,0.08))
	draw_set_transform(pos+Vector2(0,bounce),0,Vector2(u.face,1))
	draw_texture_rect(art(u.kind,u.team),Rect2(-32,-54,64,70),false,Color(1.6,1.6,1.6) if fx_enabled and u.flash > 0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	bar(Rect2(pos-Vector2(23,59),Vector2(46,4)),u.hp,u.max_hp,RED if u.team == 0 else BLUE)
	var climb: float = u.get("climb",0.0)
	if climb > 0 and climb < B.RUBBLE_TIME: bar(Rect2(pos-Vector2(23,66),Vector2(46,4)),climb,B.RUBBLE_TIME,Color.GOLD) # clearing the rubble

func draw_lord(lord: Dictionary) -> void:
	if lord.hp <= 0: return
	team_shadow(lord.pos+Vector2(0,24),30,Color(0.25,0.17,0.08))
	draw_arc(lord.pos+Vector2(0,24),30,0,TAU,32,Color(0.8,0.6,0.15,0.8),2) # gold ring marks the lords
	# The art faces right; the blue lord is mirrored so both lords face the enemy.
	draw_set_transform(lord.pos,0,Vector2(1 if lord.team == 0 else -1,1))
	draw_texture_rect(art("lord",lord.team),Rect2(Vector2(-39,-67),Vector2(78,94)),false)
	draw_set_transform(Vector2.ZERO)
	bar(Rect2(lord.pos-Vector2(30,72),Vector2(60,4)),lord.hp,B.LORD_HP,RED if lord.team == 0 else BLUE)

func layout_formations() -> void:
	# Units may overlap (producer decision 2026-10-29). Each one keeps the small up/down offset it got
	# when it was placed, so a crowd still reads as several soldiers. Drawing only; combat uses `pos`.
	for u: Dictionary in model.units: u.draw = u.pos+Vector2(0,u.get("dy",0.0))

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
		var progress: float = 1-e.life/e.duration
		match e.kind:
			"ink": draw_circle(e.pos.lerp(Vector2(100,790) if e.team == 0 else Vector2(1240,40),progress),6,Color("293b59"))
			"spell": draw_circle(e.pos,e.get("radius",50.0)*progress,Color(0.7,0.3,0.1,e.life*0.4))
			"cultivate", "hoe":
				for i: int in range(6): draw_circle(e.pos+Vector2((i-3)*8*progress,-sin(progress*PI)*28),3,Color("8a642c"))
			"play":
				var source := card_rect(e.get("slot",0)).get_center() if e.team == 0 else Vector2(1240,40)
				if progress < 0.6: draw_texture_rect(art(e.card),Rect2(source.lerp(e.pos,progress/0.6)-Vector2(25,30),Vector2(50,60)),false,Color(1,1,1,0.75))
				else: draw_circle(e.pos,(progress-0.6)*90,Color(0.2,0.15,0.1,(1-progress)*0.3))
			"death":
				draw_texture_rect(art(e.card,e.team),Rect2(e.pos-Vector2(32,54),Vector2(64,70)),false,Color(1,1,1,1-progress))
				for i: int in range(5): draw_circle(e.pos+Vector2(cos(i*2),sin(i*2))*progress*24,3*(1-progress),INK)
			"burn":
				draw_circle(e.pos,35,Color(0.15,0.07,0.02,0.35*(1-progress)))
				if progress < 0.3:
					for i: int in range(5): draw_circle(e.pos+Vector2((i-2)*10,-15-10*sin(e.life*12+i)),8,Color(0.9,0.4,0.05,0.6))
			"breach":
				for i: int in range(8): draw_line(e.pos+Vector2(cos(i),sin(i))*progress*55,e.pos+Vector2(cos(i),sin(i))*progress*65,Color("6e4825"),3)
			"heal": label_at(e.pos+Vector2(-10,-30-progress*20),"+",20,Color(0.2,0.5,0.25,1-progress))
			"fail":
				var c := Color(0.75,0.12,0.1,1-progress)
				draw_line(e.pos+Vector2(-14,-14),e.pos+Vector2(14,14),c,4)
				draw_line(e.pos+Vector2(-14,14),e.pos+Vector2(14,-14),c,4)
	for spell: Dictionary in model.spells:
		var height: float = spell.delay/B.SPELL_DELAY*160
		draw_texture_rect(art(spell.kind),Rect2(spell.pos-Vector2(22,30+height),Vector2(44,60)),false)

func draw_hud() -> void:
	panel(L.HUD_FRAME)
	for team: int in range(2):
		var x := 95.0 if team == 0 else 1070.0
		draw_texture_rect(art("crest",team),Rect2(x-58,21,48,50),false)
		draw_texture_rect(art("inkpot",team),Rect2(x+238,22,28,26),false)
		var standing: int = model.gates[team].filter(func(hp: float) -> bool: return hp > 0).size()
		label_at(Vector2(x,43),("紅獅" if team == 0 else "藍旗")+"  城門 %d / 5" % standing,23,RED if team == 0 else BLUE)
		for lane: int in range(5): bar(Rect2(x+lane*70,53,62,10),model.gates[team][lane],B.GATE_HP,RED if team == 0 else BLUE)
		label_at(Vector2(x+270,43),"%d / 50" % model.ink[team],18)
	panel(Rect2(712,24,140,58),Color("f2e3c0"))
	var time := int(model.elapsed)
	label_at(Vector2(725,58),"%02d:%02d" % [time/60,time%60],30,RED if model.multiplier() > 1 else INK)
	if model.multiplier() > 1: label_at(Vector2(735,76),"墨水 ×%.1f" % model.multiplier(),13,RED)
	panel(L.PAUSE_RECT)
	label_at(L.PAUSE_RECT.position+Vector2(10,27),"Ⅱ",23)
	panel(L.COMMAND_FRAME)
	label_at(Vector2(50,723),notice,16)
	draw_texture_rect(art("inkpot",0),Rect2(56,742,46,44),false)
	label_at(Vector2(110,780),"墨水 %d / 50" % model.ink[0],29)
	# Smooth ink bar; the selected (or hovered) card's cost is outlined: gold = affordable, red = not yet.
	var focus := selected if selected >= 0 else hover_slot
	var need: float = B.CARDS[model.decks[0][focus]].cost if focus >= 0 and not spectating else 0.0
	for i: int in range(10):
		var seg := Rect2(65+i*29,797,22,12)
		panel(seg,Color("b9a57e"))
		var fill: float = clampf((model.ink[0]-i*5)/5.0,0,1)
		if fill > 0: draw_rect(Rect2(seg.position+Vector2(1,1),Vector2((seg.size.x-2)*fill,seg.size.y-2)),Color("304461"))
		if need > i*5: draw_rect(seg.grow(2),Color("cfaa60") if model.ink[0] >= need else RED,false,2)
	label_at(Vector2(65,840),"每秒 +%.1f · 農田 %d" % [model.production_rate(0),model.count_buildings(0)],20)
	for i: int in range(4):
		var r := card_rect(i)
		if i == selected: r.position.y -= 16
		elif i == hover_slot: r.position.y -= 8
		draw_card(model.decks[0][i],r,i)
	if spectating:
		for i: int in range(SPEEDS.size()):
			panel(SPEED_RECTS[i],Color("c9a96a") if speed == SPEEDS[i] else Color("e8d5ab"))
			draw_string(font,SPEED_RECTS[i].position+Vector2(0,25),"×%d" % SPEEDS[i],HORIZONTAL_ALIGNMENT_CENTER,SPEED_RECTS[i].size.x,18,INK)
	var mouse := get_global_mouse_position()
	if dragging and selected >= 0 and card_at(mouse) < 0 and model.cell_at(mouse).x < 0:
		draw_texture_rect(art(model.decks[0][selected]),Rect2(mouse-Vector2(30,36),Vector2(60,72)),false,Color(1,1,1,0.7))
	draw_card(model.decks[0][4],Rect2(1000,730,120,158))
	label_at(Vector2(1150,780),"雙方領主",22)
	for lord: Dictionary in model.lords:
		var y: float = 815+lord.team*42
		label_at(Vector2(1150,y),"%s  %d / 900" % ["紅獅" if lord.team == 0 else "藍旗",maxi(0,int(lord.hp))],18)


func show_title() -> void:
	screen = "title"
	clear_ui()
	var items: Array = [["開始對戰",func(): spectating = false; start_battle()],["新手教學",start_tutorial],["觀戰模式",func(): spectating = true; start_battle()],["牌組編成",show_deck],["操作說明",show_help],["難度："+["簡單","普通","困難"][difficulty],func(): difficulty = (difficulty+1)%3; show_title()],["設定",show_settings],["離開",func(): get_tree().quit()]]
	for i: int in range(items.size()): button(Rect2(650,292+i*56,300,48),items[i][0],items[i][1])
	queue_redraw()

func draw_title() -> void:
	draw_texture_rect(textures.castle_red,Rect2(100,290,350,480),false)
	draw_texture_rect(art("castle_blue",1),Rect2(1150,290,350,480),false)
	draw_string(font,Vector2(0,190),"羊皮紙戰記",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,76,INK)
	draw_string(font,Vector2(0,240),"種下村莊，寫下你的戰史。",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,28,INK)
	draw_string(font,Vector2(0,808),"八張村莊牌 · 五路戰線 · 城門一破，敵兵進家就輸",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,23,INK)

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
	var descriptions := {"farm":"種下三秒後開始，每十秒產出兩滴墨水。","farmer":"兩名農民向前走，順路耕田 1.5 秒，那塊田十五秒內產量加倍。","mill":"同一路農田產量 ×2；同一路多座不疊加。","scarecrow":"吸引附近敵兵攻擊它，存在二十五秒。","tower":"每 0.8 秒射箭，射程 200，存在四十秒。","harvest":"範圍內農田立刻各產一滴，八秒內產量加倍。","rain":"範圍內部隊 200 傷害，建築與城門 60。","fire":"部隊 420 傷害，建築 840，城門 140。","ox":"第一下衝撞 150 並擊退，拆建築 ×1.5。","healer":"每秒治療附近友軍 15 血。","ram":"1600 血，無視部隊，每兩秒對城門或建築 160 傷害；城門破了就直接走進去。","hunter":"射程 170 的遠程手，兩名。","knight":"1000 血的重裝主坦。","mob":"五名暴民，錯開出場。","militia":"兩名民兵，便宜的擋路與循環牌。"}
	return "%s · %d 墨水 · 冷卻 %d 秒 · %s\n%s" % [card.name,card.cost,int(card.cooldown),card.role,descriptions.get(kind,"")]

func show_help() -> void:
	screen = "help"
	clear_ui()
	button(Rect2(650,770,300,55),"回到標題",show_title)
	queue_redraw()

func draw_help() -> void:
	panel(Rect2(270,130,1060,600))
	label_at(Vector2(350,215),"操作與勝負",44)
	var lines := ["1–4 或點卡牌選牌，再點戰場放置；右鍵／Esc 取消。","空白鍵暫停；暫停時按 R 重玩，戰鬥中 R 不會重開。","農田自己產墨水；農民從田後方出發，順路耕田加速。","部隊只往前走，領主會自行回防；箭樓可守護後方。","打破對方城門後，該路部隊可部署到第六欄。","城門破了，任何一名敵兵走進家門就輸——沒有時間限制。","三分鐘後墨水與卡牌冷卻 ×1.5，五分鐘後 ×2；墨水上限 50。"]
	for i: int in range(lines.size()): label_at(Vector2(350,290+i*52),lines[i],23)

func save_settings() -> void:
	var file := FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"effects":fx_enabled,"shake":shake_enabled,"sound":sound_enabled}))

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"): return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	if data is Dictionary:
		fx_enabled = bool(data.get("effects",true))
		shake_enabled = bool(data.get("shake",true))
		sound_enabled = bool(data.get("sound",true))

func show_settings() -> void:
	screen = "settings"
	clear_ui()
	button(Rect2(600,300,400,55),"特效："+("開" if fx_enabled else "關"),func(): fx_enabled = not fx_enabled; effects.clear(); save_settings(); show_settings())
	button(Rect2(600,380,400,55),"震動："+("開" if shake_enabled else "關"),func(): shake_enabled = not shake_enabled; save_settings(); show_settings())
	button(Rect2(600,460,400,55),"音效："+("開" if sound_enabled else "關"),func(): sound_enabled = not sound_enabled; sound.enabled = sound_enabled; save_settings(); show_settings())
	button(Rect2(600,600,400,55),"回到標題",show_title)
	queue_redraw()
