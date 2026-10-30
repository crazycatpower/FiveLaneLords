extends Node2D
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const DeckStore = preload("res://deck_store.gd")
const Battle = preload("res://battle.gd")
const Tutorial = preload("res://tutorial.gd")
const ART = preload("res://manuscript_art.gd")
const PAPER = preload("res://assets/parchment-background.png")
const INK := Color("463529")
const RED := Color("9c3d30")
const BLUE := Color("355b78")
# Battlefield palette (art-direction sheet): our meadow, the sandy no-man's land, the enemy's frost.
const MEADOW := Color("7d9c54")
const SAND := Color("b08b52")
const FROST := Color("5a8fd0")
const PAPER_TINT := Color(0.94,0.90,0.83) # the whole page a little darker: less glare
const FIELD_TINT := Color(0.88,0.82,0.70)
var vignette: GradientTexture2D
var model: RefCounted
var font: Font
var textures: Dictionary = {}
var blue_art: Dictionary = {}
static var recolor_cache: Dictionary = {}
const ROMAN := ["I","II","III","IV","V"]
var selected := -1
var notice := "1–4 選牌 · 點戰場放置 · 右鍵取消 · 空白鍵暫停"
var screen := "title"
var player_deck: Array = []
var player_lord := "iron"
var deck_path := "user://deck.json"
var deck_tab := "unit"
var difficulty := 1
var spectating := false
var menu_notice := ""
# Spectate setup: each side's deck, lord and where the deck came from (WATCH_SOURCES index, -1 = edited by hand).
var watch_decks: Array = [[],[]]
var watch_lords: Array = ["lion","lion"]
var watch_source: Array = [0,0]
const WATCH_SOURCES := ["隨機","向日葵流","穩健農莊","劫掠隊","我的牌組"]
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
const SPEED_RECTS := [Rect2(1360,736,46,32),Rect2(1412,736,46,32),Rect2(1464,736,46,32),Rect2(1516,736,46,32)]
const NEXT_RECT := Rect2(1102,748,96,128)
const SKILL_RECT := Rect2(1212,734,356,54)

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
	for pair: Array in [["gate","gate"],["crest","crown"]]:
		textures[pair[0]] = load("res://assets/manuscript-v1/"+pair[1]+".png")
	for lord_kind: String in B.LORDS:
		textures["lord_"+lord_kind] = load("res://assets/manuscript-v1/lord-"+lord_kind+".png")
	# One shared art set (producer decision): the blue side is made by swapping red cloth to blue,
	# not by tinting the whole picture (that turned red into purple and darkened the fields).
	for kind: String in textures:
		if kind != "castle_blue": blue_art[kind] = recolor_blue(textures[kind],0 if kind == "castle_red" else 384,kind)
	textures.castle_blue = textures.castle_red
	# Darkened field edges pull the eye to the middle of the battle.
	var shade := Gradient.new()
	shade.set_color(0,Color(0.2,0.12,0.04,0.0))
	shade.set_color(1,Color(0.2,0.12,0.04,0.34))
	shade.add_point(0.62,Color(0.2,0.12,0.04,0.0))
	vignette = GradientTexture2D.new()
	vignette.gradient = shade
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5,0.5)
	vignette.fill_to = Vector2(1.0,1.0)
	vignette.width = 256
	vignette.height = 256
	blue_art.castle_blue = blue_art.castle_red
	seed_value = int(Time.get_unix_time_from_system())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.substr(7))
	load_settings()
	sound = preload("res://sound_bank.gd").new()
	add_child(sound)
	sound.enabled = sound_enabled
	var saved: Dictionary = DeckStore.load_full(deck_path)
	player_deck = saved.cards
	player_lord = saved.lord
	model = Battle.new(seed_value,player_deck,[],player_lord)
	show_title()

func start_battle() -> void:
	if spectating:
		for team: int in range(2):
			if not DeckStore.valid(watch_decks[team]): set_watch_source(team,0)
		model = Battle.new(seed_value,watch_decks[0].duplicate(),watch_decks[1].duplicate(),watch_lords[0],watch_lords[1])
	else:
		if not DeckStore.valid(player_deck):
			show_deck()
			return
		DeckStore.save_deck(player_deck,deck_path,player_lord)
		model = Battle.new(seed_value,player_deck,B.PRESETS[difficulty],player_lord,B.PRESET_LORDS[difficulty])
	model.difficulty = difficulty
	model.ai_enabled = [spectating,true]
	tutorial = null
	enter_battle("觀戰中：AI 操控雙方。1–4 或 + / − 調整速度，空白鍵暫停。" if spectating else "拖曳卡牌到戰場，或按 1–4／F 選牌再點格子 · 右鍵取消 · 空白鍵暫停")

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
	if step.done == "skill":
		model.ink[0] = maxf(model.ink[0],B.SKILL_COST)
		model.skill_cd[0] = 0.0
		model.lords[0].hp = model.lords[0].max_hp
		model.lords[0].respawn = 0.0
		selected = -1
		dragging = false
		notice = tutorial.caption()
		return
	if step.card == "farm": model.farm_cd[0] = 0.0
	else:
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
		if e.kind == "skill": notice = "%s%s發動「%s」！" % ["紅方" if e.team == 0 else "藍方",B.LORDS[e.lord].name,B.LORDS[e.lord].skill]
		if e.kind == "ramp": notice = "金幣產出與卡牌冷卻加快 ×%.1f" % e.multiplier
		if e.kind == "overflow" and e.team == 0 and not spectating: notice = "金幣已滿 50，繼續產出的金幣會浪費。"
		if sound != null: sound.cue(e.kind)
		if e.kind == "breach" and shake_enabled: shake_left = 0.25
		if fx_enabled:
			var copy := e.duplicate()
			copy.life = {"burn":5.0,"death":0.35,"play":0.45,"ink":0.6,"skill":1.0}.get(e.kind,0.7)
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

# Hand area: the permanent farmland slot, the four rotating cards, then the next-card preview.
func card_rect(slot: int) -> Rect2:
	if slot == Battle.FARM_SLOT: return Rect2(418,730,124,158)
	return Rect2(560+slot*134,730,124,158)

func card_at(pos: Vector2) -> int:
	for i: int in [0,1,2,3,Battle.FARM_SLOT]:
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
		if event.keycode == KEY_Q and not spectating: try_skill()
		if event.keycode == KEY_F and not spectating: selected = -1 if selected == Battle.FARM_SLOT else Battle.FARM_SLOT
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
			if SKILL_RECT.has_point(pos):
				try_skill()
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

func lord_art(kind: String, team: int = 0) -> Texture2D:
	return art("lord_"+kind,team)

# Recolour only designated team materials. Natural fields/skin/wood are not team ink.
# Ox cloth additionally has a spatial mask so its brown coat never enters the palette swap.
static func team_material(kind: String, uv: Vector2, c: Color) -> bool:
	if kind in ["farm","farmer","harvest","rain","fire"]: return false
	if kind == "ox" and not Rect2(0.30,0.20,0.26,0.36).has_point(uv): return false
	if kind == "ram" and uv.y > 0.55: return false
	# Architecture's weathered red paint is less saturated than character cloth.
	if kind in ["castle_red","castle_blue"]:
		if Rect2(0.45,0.65,0.27,0.35).has_point(uv): return false # wooden gate, not painted team cloth
		return c.a >= 0.05 and c.s >= 0.33 and c.v >= 0.18 and (c.h <= 0.07 or c.h >= 0.93)
	return c.a >= 0.05 and c.s >= 0.55 and c.v >= 0.25 and (c.h <= 0.035 or c.h >= 0.965)

static func recolor_blue(source: Texture2D, max_size: int, kind: String = "") -> Texture2D:
	if kind in ["farm","farmer","harvest","rain","fire"]: return source
	var key := str(source.get_instance_id())+":"+str(max_size)+":"+kind
	if recolor_cache.has(key): return recolor_cache[key]
	var img := source.get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var scale := minf(1.0,float(max_size)/maxf(img.get_width(),img.get_height())) if max_size > 0 else 1.0
	if scale < 1.0: img.resize(maxi(1,roundi(img.get_width()*scale)),maxi(1,roundi(img.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c := img.get_pixel(x,y)
			if not team_material(kind,Vector2(float(x)/img.get_width(),float(y)/img.get_height()),c): continue
			c.h = 0.6
			c.s = minf(1.0,c.s*0.95)
			c.v *= 0.9
			img.set_pixel(x,y,c)
	var result := ImageTexture.create_from_image(img)
	recolor_cache[key] = result
	return result

static func fitted_rect(source_size: Vector2, box: Rect2, bottom: bool = false) -> Rect2:
	var size := source_size*minf(box.size.x/source_size.x,box.size.y/source_size.y)
	var pos := box.position+(box.size-size)*0.5
	if bottom: pos.y = box.end.y-size.y
	return Rect2(pos,size)

func draw_fitted(texture: Texture2D, box: Rect2, shade: Color = Color.WHITE, bottom: bool = false) -> void:
	draw_texture_rect(texture,fitted_rect(texture.get_size(),box,bottom),false,shade)

func actor_rect(kind: String) -> Rect2:
	if kind.begins_with("lord_"): return fitted_rect(art(kind).get_size(),Rect2(-47,-67,94,94),true)
	if kind in ["farm","mill","tower","scarecrow"]: return fitted_rect(art(kind).get_size(),Rect2(-45,-39,90,78),true)
	var width := 112.0 if kind in ["ox","ram"] else 80.0
	return fitted_rect(art(kind).get_size(),Rect2(-width/2,-63,width,80),true)

func draw_actor(kind: String, team: int, pos: Vector2, face: float, shade: Color = Color.WHITE) -> void:
	draw_set_transform(pos,0,Vector2(face,1))
	draw_texture_rect(art(kind,team),actor_rect(kind),false,shade)
	draw_set_transform(Vector2.ZERO)

func card_art_kinds(kind: String) -> Array:
	return B.CARDS[kind].get("art",[kind])

func draw_card_art(kind: String, box: Rect2, team: int = 0, shade: Color = Color.WHITE) -> void:
	var kinds := card_art_kinds(kind)
	for i: int in range(kinds.size()):
		var part := box
		if kinds.size() > 1:
			part.size.x = box.size.x*0.58
			part.position.x += i*box.size.x*0.42
		draw_fitted(art(kinds[i],team),part,shade,true)

func draw_card(kind: String, rect: Rect2, slot: int = -1) -> void:
	var data: Dictionary = B.CARDS[kind]
	var s := rect.size
	var short: bool = screen == "battle" and model.ink[0] < data.cost
	draw_texture_rect(ART.card(selected == slot and slot >= 0),rect,false)
	var shade := Color(0.45,0.45,0.45) if short else Color.WHITE
	draw_card_art(kind,Rect2(rect.position+s*Vector2(0.08,0.13),s*Vector2(0.84,0.5)),0,shade)
	# Name and type sit above the frame's bottom corner flowers (they start ~83% down).
	draw_string(font,rect.position+Vector2(0,s.y*0.74),data.name,HORIZONTAL_ALIGNMENT_CENTER,s.x,17,INK)
	draw_string(font,rect.position+Vector2(0,s.y*0.83),data.role,HORIZONTAL_ALIGNMENT_CENTER,s.x,12,Color("7a6446"))
	if screen != "battle":
		# Outside battle the top-left corner shows the card's cooldown (in battle it shows the hand slot).
		draw_rect(Rect2(rect.position+Vector2(7,7),Vector2(34,20)),Color("725138"))
		draw_string(font,rect.position+Vector2(7,22),"%ds" % int(data.cooldown),HORIZONTAL_ALIGNMENT_CENTER,34,13,Color("efdfb9"))
	# Ink cost badge, top right.
	var badge := rect.position+Vector2(s.x-19,19)
	draw_circle(badge,15,Color("2f3f5c"))
	draw_arc(badge,15,0,TAU,24,Color("cfaa60"),2)
	draw_string(font,badge+Vector2(-15,6),str(data.cost),HORIZONTAL_ALIGNMENT_CENTER,30,16,Color("f3e6c4"))
	if slot >= 0:
		var key := "F" if slot == Battle.FARM_SLOT else str(slot+1)
		draw_rect(Rect2(rect.position+Vector2(7,7),Vector2(22,22)),Color("3f5a2c") if slot == Battle.FARM_SLOT else Color("725138"))
		draw_string(font,rect.position+Vector2(7,24),key,HORIZONTAL_ALIGNMENT_CENTER,22,14,Color("efdfb9"))
	if short and slot >= 0:
		draw_string(font,rect.position+Vector2(0,s.y*0.42),"差 %d" % ceili(data.cost-model.ink[0]),HORIZONTAL_ALIGNMENT_CENTER,s.x,20,Color("f3e6c4"))
	if slot >= 0 and screen == "battle" and model.slot_cd(0,slot) > 0:
		var left: float = model.slot_cd(0,slot)
		draw_rect(Rect2(rect.position+Vector2(6,6),Vector2(rect.size.x-12,(rect.size.y-12)*clampf(left/maxf(0.1,data.cooldown),0,1))),Color(0.12,0.08,0.04,0.45))
		draw_string(font,rect.position+Vector2(0,s.y*0.45),"%.0f" % ceilf(left),HORIZONTAL_ALIGNMENT_CENTER,s.x,30,Color("fff3dc"))

func _draw() -> void:
	if font == null or model == null: return
	draw_texture_rect(PAPER,Rect2(Vector2.ZERO,L.VIEWPORT_SIZE),false,PAPER_TINT)
	if screen != "battle": draw_landscape(L.PAGE_FRAME.grow(-7),0.46)
	panel(L.PAGE_FRAME,Color(0.85,0.74,0.53,0.15))
	if screen == "battle": draw_battle()
	elif screen == "deck": draw_deck()
	elif screen == "watch": draw_watch()
	elif screen == "help": draw_help()
	elif screen == "settings": draw_string(font,Vector2(0,220),"畫面與音效設定",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,40,INK)
	else: draw_title()

# Flat manuscript pigments over paper; deterministic strokes never consume battle RNG.
func draw_battle_landscape(field: Rect2) -> void:
	draw_rect(field,Color("81975e"))
	draw_texture_rect(PAPER,field,false,Color(1,1,1,0.08))

func draw_landscape(rect: Rect2, horizon: float) -> void:
	draw_rect(rect,Color("8db7cb"))
	var top := rect.position
	var line_y := top.y+rect.size.y*horizon
	# Faint geometric sky ornament, like the painted diaper patterns in manuscripts.
	for x: int in range(int(top.x)+22,int(rect.end.x)-20,58):
		for y: int in range(int(top.y)+14,int(line_y)-10,42):
			draw_polyline(PackedVector2Array([Vector2(x,y-9),Vector2(x+15,y),Vector2(x,y+9),Vector2(x-15,y),Vector2(x,y-9)]),Color(0.85,0.92,0.89,0.22),1.4,true)
	for layer: int in range(3):
		var points := PackedVector2Array()
		for i: int in range(65):
			var x := rect.size.x*i/64.0
			var y := line_y+layer*rect.size.y*0.12+sin(i*0.12+layer*1.7)*rect.size.y*0.025
			points.append(top+Vector2(x,y-top.y))
		points.append(rect.end)
		points.append(Vector2(top.x,rect.end.y))
		draw_colored_polygon(points,[Color("7e9661"),Color("708a51"),Color("81965b")][layer])
	for i: int in range(95 if rect.size.y > 200 else 0):
		var x := top.x+12+fposmod(i*137.39,rect.size.x-24)
		var y := line_y+32+fposmod(i*79.73,maxf(1,rect.end.y-line_y-46))
		tuft(Vector2(x,y),Color(0.77,0.80,0.49,0.34),7+float(i%5))
	# Let the existing parchment grain show through the painted pigments.
	draw_texture_rect(PAPER,rect,false,Color(1,1,1,0.19))

func draw_battle() -> void:
	var field: Rect2 = L.FIELD_FRAME
	draw_texture_rect_region(PAPER,field,Rect2(field.position*0.6,field.size*0.6),FIELD_TINT)
	if tutorial == null: draw_battle_landscape(field.grow(-7))
	ink_frame(field)
	var corner := Vector2(96,86)
	draw_texture_rect(ART.ornament(0),Rect2(field.position+Vector2(8,8),corner),false,Color(1,1,1,0.85))
	draw_texture_rect(ART.ornament(1),Rect2(Vector2(field.end.x-8-corner.x,field.position.y+8),corner),false,Color(1,1,1,0.85))
	draw_texture_rect(ART.ornament(2),Rect2(Vector2(field.position.x+8,field.end.y-8-corner.y),corner),false,Color(1,1,1,0.85))
	draw_texture_rect(ART.ornament(3),Rect2(field.end-Vector2(8,8)-corner,corner),false,Color(1,1,1,0.85))
	draw_texture_rect(art("castle_red",0),L.CASTLE_RECTS[0],false)
	draw_mirrored(art("castle_blue",1),L.CASTLE_RECTS[1])
	var grid := Rect2(L.GRID_ORIGIN,L.GRID_SIZE)
	draw_ground(grid)
	if selected >= 0:
		for row: int in range(5):
			for col: int in range(9):
				var cell := Vector2i(col,row)
				if model.can_play(0,selected,L.cell_center(cell)):
					var r := Rect2(L.GRID_ORIGIN+Vector2(cell)*L.CELL_SIZE,L.CELL_SIZE).grow(-5)
					draw_rect(r,Color(1.0,0.93,0.55,0.22))
					draw_rect(r,Color(0.85,0.65,0.15,0.7),false,2)
	for lane: int in range(6):
		var y := grid.position.y+lane*L.CELL_SIZE.y
		ink_line(Vector2(grid.position.x,y),Vector2(grid.end.x,y),lane,Color(INK,0.55 if lane == 0 or lane == 5 else 0.38),2.0)
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
		draw_actor(b.kind,b.team,b.pos,1.0)
		if b.hp < b.max_hp: bar(Rect2(b.pos-Vector2(30,43),Vector2(60,5)),b.hp,b.max_hp,RED if b.team == 0 else BLUE)
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
	var rows: Array = [["打破的城門","breaches"],["產出金幣","produced"],["浪費的金幣","wasted"],["種下農田","planted"],["被燒掉的田","burned"],["出牌數","plays"]]
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

# Ground under a soldier: a dark shadow with a ring in the team's colour, so sides read at a glance.
func team_base(center: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(center,0,Vector2(1,0.34))
	draw_circle(Vector2.ZERO,radius,Color(0.18,0.12,0.06,0.42))
	draw_circle(Vector2.ZERO,radius,Color(color,0.55),false,4.0)
	draw_set_transform(Vector2.ZERO)

# The battlefield floor: tinted zones, alternating lane shade, grass and pebbles, darker edges.
func draw_ground(grid: Rect2) -> void:
	if tutorial != null: return # The tutorial keeps an undecorated parchment field.
	var cw: float = L.CELL_SIZE.x
	var ch: float = L.CELL_SIZE.y
	for lane: int in range(5):
		var row := Rect2(grid.position+Vector2(0,lane*ch),Vector2(grid.size.x,ch))
		if lane % 2 == 1: draw_rect(row,Color(0.25,0.16,0.06,0.06))
		# A broken gate lets the attacker deploy three columns deeper in that lane.
		if model.gates[1][lane] <= 0: draw_rect(Rect2(row.position+Vector2(3*cw,0),Vector2(3*cw,ch)),Color(MEADOW,0.2))
		if model.gates[0][lane] <= 0: draw_rect(Rect2(row.position+Vector2(3*cw,0),Vector2(3*cw,ch)),Color(FROST,0.2))
	# Faint cell lines inside both deploy zones, where cards can be placed.
	for col: int in [1,2,7,8]:
		var x: float = grid.position.x+col*cw
		draw_line(Vector2(x,grid.position.y),Vector2(x,grid.end.y),Color(INK,0.12),1.0)
	for row: int in range(5):
		for col: int in range(9):
			var origin: Vector2 = grid.position+Vector2(col*cw,row*ch)
			var middle: bool = col >= 3 and col <= 5
			for i: int in range(2 if middle else 3):
				var h: float = fposmod(sin(row*12.9898+col*78.233+i*37.719)*43758.5453,1.0)
				var k: float = fposmod(sin(row*39.346+col*11.135+i*93.989)*24634.6345,1.0)
				var p: Vector2 = origin+Vector2(10+h*(cw-20),10+k*(ch-20))
				if middle and i == 1: draw_circle(p,1.6+h*1.4,Color(0.35,0.25,0.15,0.28)) # pebble
				else: tuft(p,Color(0.27,0.33,0.12,0.42) if col < 3 or col > 5 else Color(0.40,0.32,0.15,0.30),6.0+h*4.0)
	draw_texture_rect(vignette,L.FIELD_FRAME.grow(-4),false)

# Three ink strokes fanning up from one point: a grass tuft.
func tuft(base: Vector2, color: Color, height: float) -> void:
	for a: float in [-0.5,0.0,0.45]:
		draw_line(base,base+Vector2(sin(a)*height*0.8,-cos(a)*height),color,1.3,true)

func team_shadow(center: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(center,0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,radius,Color(color,0.45))
	draw_set_transform(Vector2.ZERO)

func draw_unit(u: Dictionary) -> void:
	var pos: Vector2 = u.draw-Vector2(u.face*4,0) if fx_enabled and u.flash > 0 else u.draw # small knockback on hit
	var bounce := sin(model.elapsed*8+u.phase)*2
	team_base(pos+Vector2(0,16),24,RED if u.team == 0 else BLUE)
	draw_actor(u.kind,u.team,pos+Vector2(0,bounce),u.face,Color(1.6,1.6,1.6) if fx_enabled and u.flash > 0 else Color.WHITE)
	if u.hp < u.max_hp: bar(Rect2(pos-Vector2(24,68),Vector2(48,5)),u.hp,u.max_hp,RED if u.team == 0 else BLUE)
	var climb: float = u.get("climb",0.0)
	if climb > 0 and climb < B.RUBBLE_TIME: bar(Rect2(pos-Vector2(24,75),Vector2(48,4)),climb,B.RUBBLE_TIME,Color.GOLD) # clearing the rubble

func draw_lord(lord: Dictionary) -> void:
	if lord.hp <= 0: return
	team_shadow(lord.pos+Vector2(0,24),30,Color(0.25,0.17,0.08))
	draw_arc(lord.pos+Vector2(0,24),30,0,TAU,32,Color(0.8,0.6,0.15,0.8),2) # gold ring marks the lords
	# The art faces right; the blue lord is mirrored so both lords face the enemy.
	draw_actor("lord_"+lord.lord,lord.team,lord.pos,1.0 if lord.team == 0 else -1.0)
	if lord.hp < lord.max_hp: bar(Rect2(lord.pos-Vector2(30,72),Vector2(60,4)),lord.hp,lord.max_hp,RED if lord.team == 0 else BLUE)

func layout_formations() -> void:
	# Units may overlap (producer decision 2026-10-29). Each one keeps the small up/down offset it got
	# when it was placed, so a crowd still reads as several soldiers. Drawing only; combat uses `pos`.
	for u: Dictionary in model.units: u.draw = u.pos+Vector2(0,u.get("dy",0.0))

func draw_preview() -> void:
	if selected < 0: return
	var pos := get_global_mouse_position()
	var cell: Vector2i = model.cell_at(pos)
	if cell.x < 0: return
	var kind: String = model.kind_at(0,selected)
	var data: Dictionary = B.CARDS[kind]
	var color := Color(0.2,0.7,0.3,0.35) if model.can_play(0,selected,pos) else Color(0.8,0.1,0.1,0.35)
	if data.type == "spell": draw_circle(pos,data.radius,color)
	else:
		draw_card_art(kind,Rect2(L.cell_center(cell)-Vector2(45,40),Vector2(90,80)),0,Color(1,1,1,0.5))
		if data.type == "unit":
			var lanes: Array = [cell.y]
			if data.get("spread",false):
				var middle := clampi(cell.y,1,3)
				lanes = [middle-1,middle,middle+1]
			for lane: int in lanes: draw_line(Vector2(L.cell_center(cell).x,L.cell_center(Vector2i(0,lane)).y),Vector2(L.gate_stop(1),L.cell_center(Vector2i(0,lane)).y),color,3)
			if kind == "farmer":
				for b: Dictionary in model.buildings:
					if b.kind == "farm" and b.team == 0 and b.cell.y == cell.y and b.cell.x >= cell.x: draw_circle(b.pos,40,color,false,3)

func draw_effects() -> void:
	for e: Dictionary in effects:
		var progress: float = 1-e.life/e.duration
		match e.kind:
			"skill": draw_skill_effect(e,progress)
			"ink": draw_circle(e.pos.lerp(Vector2(80,765) if e.team == 0 else Vector2(1322,35),progress),7,Color("d9a62e"))
			"spell": draw_circle(e.pos,e.get("radius",50.0)*progress,Color(0.7,0.3,0.1,e.life*0.4))
			"cultivate", "hoe":
				for i: int in range(6): draw_circle(e.pos+Vector2((i-3)*8*progress,-sin(progress*PI)*28),3,Color("8a642c"))
			"play":
				var source := card_rect(e.get("slot",0)).get_center() if e.team == 0 else Vector2(1240,40)
				if progress < 0.6: draw_card_art(e.card,Rect2(source.lerp(e.pos,progress/0.6)-Vector2(35,30),Vector2(70,60)),e.team,Color(1,1,1,0.75))
				else: draw_circle(e.pos,(progress-0.6)*90,Color(0.2,0.15,0.1,(1-progress)*0.3))
			"death":
				draw_actor(e.get("art_kind",e.card),e.team,e.pos,e.get("face",1.0 if e.team == 0 else -1.0),Color(1,1,1,1-progress))
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

# Visual-only skill cues: positions were captured at cast time, no battle state is changed.
func draw_skill_effect(e: Dictionary, progress: float) -> void:
	var strength := sin(clampf(progress,0.0,1.0)*PI)
	var gold := Color(1.0,0.82,0.30,strength*0.85)
	var direction := 1.0 if e.team == 0 else -1.0
	for point: Vector2 in e.get("targets",[]):
		match e.lord:
			"lion":
				draw_circle(point+Vector2(0,-20),18+progress*30,Color(1.0,0.85,0.45,strength*0.22))
				draw_arc(point+Vector2(0,-20),14+progress*35,0,TAU,32,gold,2.0,true)
				var tip := point+Vector2(direction*(25+progress*100),-18)
				draw_line(tip-Vector2(direction*65,0),tip,gold,3.0,true)
				draw_line(tip-Vector2(direction*14,9),tip,gold,3.0,true)
				draw_line(tip-Vector2(direction*14,-9),tip,gold,3.0,true)
			"harvest":
				draw_circle(point,42,Color(1.0,0.76,0.20,strength*0.22))
				draw_arc(point,27+progress*18,0,TAU,32,gold,2.5,true)
				for i: int in range(5):
					var spark := point+Vector2((i-2)*14,-12-progress*36-sin(i*2.0)*9)
					draw_line(spark-Vector2(3,0),spark+Vector2(3,0),gold,2.0,true)
					draw_line(spark-Vector2(0,5),spark+Vector2(0,5),gold,2.0,true)
			"iron":
				var frame := Rect2(point-Vector2(33,38),Vector2(66,66))
				draw_rect(frame,Color(1.0,0.86,0.48,strength*0.20))
				draw_rect(frame,gold,false,3.0)
				for i: int in range(4):
					var y := point.y+25-progress*60-i*7
					draw_line(Vector2(point.x-24,y),Vector2(point.x+24,y),Color(gold,strength*(1.0-i*0.2)),2.0,true)

func draw_hud() -> void:
	if tutorial != null:
		panel(L.HUD_FRAME)
	else:
		draw_rect(L.HUD_FRAME,Color("a6c9dc"))
		for x: int in range(48,1550,58):
			draw_polyline(PackedVector2Array([Vector2(x,24),Vector2(x+16,34),Vector2(x,44),Vector2(x-16,34),Vector2(x,24)]),Color(0.92,0.97,1,0.23),1.2,true)
		draw_texture_rect(PAPER,L.HUD_FRAME,false,Color(1,1,1,0.06))
		ink_frame(L.HUD_FRAME)
	for team: int in range(2):
		var x := 95.0 if team == 0 else 1070.0
		draw_texture_rect(art("crest",team),Rect2(x-58,21,48,50),false)
		draw_texture_rect(ART.object_icon(0),Rect2(x+238,20,28,30),false)
		var standing: int = model.gates[team].filter(func(hp: float) -> bool: return hp > 0).size()
		label_at(Vector2(x,43),("紅獅" if team == 0 else "藍旗")+"  城門 %d / 5" % standing,23,RED if team == 0 else BLUE)
		for lane: int in range(5): bar(Rect2(x+lane*70,53,62,10),model.gates[team][lane],B.GATE_HP,RED if team == 0 else BLUE)
		label_at(Vector2(x+270,43),"%d / 50" % model.ink[team],18)
	panel(Rect2(712,24,140,58),Color("f2e3c0"))
	var time := int(model.elapsed)
	label_at(Vector2(725,58),"%02d:%02d" % [time/60,time%60],30,RED if model.multiplier() > 1 else INK)
	if model.multiplier() > 1: label_at(Vector2(735,76),"金幣 ×%.1f" % model.multiplier(),13,RED)
	panel(L.PAUSE_RECT)
	label_at(L.PAUSE_RECT.position+Vector2(10,27),"Ⅱ",23)
	panel(L.COMMAND_FRAME)
	label_at(Vector2(50,723),notice,16)
	draw_texture_rect(ART.object_icon(0),Rect2(56,740,46,48),false)
	label_at(Vector2(110,780),"金幣 %d / 50" % model.ink[0],29)
	# Smooth gold bar; the selected (or hovered) card's cost is outlined: gold = affordable, red = not yet.
	var focus := selected if selected >= 0 else hover_slot
	var need: float = B.CARDS[model.kind_at(0,focus)].cost if focus >= 0 and not spectating else 0.0
	for i: int in range(10):
		var seg := Rect2(65+i*29,797,22,12)
		panel(seg,Color("b9a57e"))
		var fill: float = clampf((model.ink[0]-i*5)/5.0,0,1)
		if fill > 0: draw_rect(Rect2(seg.position+Vector2(1,1),Vector2((seg.size.x-2)*fill,seg.size.y-2)),Color("c79a2e"))
		if need > i*5: draw_rect(seg.grow(2),Color("6b4a14") if model.ink[0] >= need else RED,false,2)
	label_at(Vector2(65,840),"每秒 +%.1f · 農田 %d" % [model.production_rate(0),model.count_buildings(0)],20)
	# Permanent farmland slot: green-washed frame and a "常駐" tag so it reads apart from the hand.
	var farm_rect := card_rect(Battle.FARM_SLOT)
	panel(farm_rect.grow(6),Color("cfdcae"),Color("3f5a2c"))
	var fr := farm_rect
	if selected == Battle.FARM_SLOT: fr.position.y -= 16
	elif hover_slot == Battle.FARM_SLOT: fr.position.y -= 8
	draw_card("farm",fr,Battle.FARM_SLOT)
	var tag := Rect2(farm_rect.position.x+farm_rect.size.x/2-24,farm_rect.end.y-22,48,18)
	draw_rect(tag,Color("3f5a2c"))
	draw_string(font,tag.position+Vector2(0,14),"常駐",HORIZONTAL_ALIGNMENT_CENTER,tag.size.x,13,Color("efdfb9"))
	draw_line(Vector2(551,728),Vector2(551,888),Color(INK,0.35),2)
	for i: int in range(4):
		var r := card_rect(i)
		if i == selected: r.position.y -= 16
		elif i == hover_slot: r.position.y -= 8
		draw_card(model.decks[0][i],r,i)
	# Next card: smaller, faded, labelled.
	draw_line(Vector2(1093,728),Vector2(1093,888),Color(INK,0.35),2)
	draw_string(font,Vector2(NEXT_RECT.position.x,742),"下一張",HORIZONTAL_ALIGNMENT_CENTER,NEXT_RECT.size.x,14,Color("6f5a3e"))
	draw_card(model.decks[0][4],NEXT_RECT)
	draw_rect(NEXT_RECT.grow(-4),Color(0.93,0.87,0.72,0.35))
	if spectating:
		for i: int in range(SPEEDS.size()):
			panel(SPEED_RECTS[i],Color("c9a96a") if speed == SPEEDS[i] else Color("e8d5ab"))
			draw_string(font,SPEED_RECTS[i].position+Vector2(0,25),"×%d" % SPEEDS[i],HORIZONTAL_ALIGNMENT_CENTER,SPEED_RECTS[i].size.x,18,INK)
	var mouse := get_global_mouse_position()
	if dragging and selected >= 0 and card_at(mouse) < 0 and model.cell_at(mouse).x < 0:
		draw_card_art(model.kind_at(0,selected),Rect2(mouse-Vector2(40,36),Vector2(80,72)),0,Color(1,1,1,0.7))
	if spectating: label_at(Vector2(1220,766),"雙方領主",20)
	else: draw_skill_button()
	for lord: Dictionary in model.lords:
		var y: float = 814+lord.team*42
		var info: Dictionary = B.LORDS[lord.lord]
		var color: Color = RED if lord.team == 0 else BLUE
		label_at(Vector2(1220,y),"%s · %s" % ["紅" if lord.team == 0 else "藍",info.name],16,color)
		bar(Rect2(1220,y+8,170,6),lord.hp,lord.max_hp,color)
		label_at(Vector2(1400,y+14),"%d / %d" % [maxi(0,int(lord.hp)),int(lord.max_hp)],14)
		var cd: float = model.skill_cd[lord.team]
		label_at(Vector2(1490,y+14),"技能 %ds" % ceili(cd) if cd > 0 else "技能就緒",13,Color("6f5a3e") if cd > 0 else color)

# Our lord's skill: Q or click. Lit when it can be cast; shows the cooldown otherwise.
func draw_skill_button() -> void:
	var info: Dictionary = B.LORDS[model.lords[0].lord]
	var ready: bool = model.skill_error(0).is_empty()
	panel(SKILL_RECT,Color("f2e3c0") if ready else Color("e3d2aa"),RED if ready else INK)
	if ready: draw_rect(SKILL_RECT.grow(2),RED,false,3)
	draw_rect(Rect2(SKILL_RECT.position+Vector2(8,10),Vector2(24,24)),Color("725138"))
	draw_string(font,SKILL_RECT.position+Vector2(8,28),"Q",HORIZONTAL_ALIGNMENT_CENTER,24,15,Color("efdfb9"))
	label_at(SKILL_RECT.position+Vector2(42,24),"領主技能：%s" % info.skill,17,RED if ready else INK)
	var cd: float = model.skill_cd[0]
	var state: String = "冷卻 %d 秒" % ceili(cd) if cd > 0 else ("可發動" if ready else "還差 %d 金幣" % ceili(B.SKILL_COST-model.ink[0]) if model.ink[0] < B.SKILL_COST else "領主倒下中")
	label_at(SKILL_RECT.position+Vector2(42,44),"%d 金幣 · %s" % [int(B.SKILL_COST),state],13,Color("6f5a3e"))

func try_skill() -> bool:
	var reason: String = model.skill_error(0)
	if reason.is_empty() and model.cast_skill(0): return true
	notice = reason
	if sound != null: sound.cue("fail")
	return false


func show_title() -> void:
	screen = "title"
	clear_ui()
	var items: Array = [["開始對戰",func(): spectating = false; start_battle()],["新手教學",start_tutorial],["觀戰模式",show_watch],["牌組編成",show_deck],["操作說明",show_help],["難度："+["簡單","普通","困難"][difficulty],func(): difficulty = (difficulty+1)%3; show_title()],["設定",show_settings],["離開",func(): get_tree().quit()]]
	for i: int in range(items.size()): button(Rect2(650,292+i*56,300,48),items[i][0],items[i][1])
	queue_redraw()

# The blue castle faces the red one: draw it flipped left-right inside the same rect.
func draw_mirrored(tex: Texture2D, r: Rect2) -> void:
	draw_set_transform(Vector2(2*r.position.x+r.size.x,0),0,Vector2(-1,1))
	draw_texture_rect(tex,r,false)
	draw_set_transform(Vector2.ZERO)

func draw_title() -> void:
	draw_texture_rect(textures.castle_red,Rect2(100,290,350,480),false)
	draw_mirrored(art("castle_blue",1),Rect2(1150,290,350,480))
	draw_string(font,Vector2(0,190),"羊皮紙戰記",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,76,INK)
	draw_string(font,Vector2(0,240),"種下村莊，寫下你的戰史。",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,28,INK)
	draw_string(font,Vector2(0,808),"農田＋領主＋八張村莊牌 · 五路戰線 · 城門一破，敵兵進家就輸",HORIZONTAL_ALIGNMENT_CENTER,L.VIEWPORT_SIZE.x,23,INK)

func show_deck() -> void:
	screen = "deck"
	clear_ui()
	for i: int in range(3):
		var index := i
		button(Rect2(120+i*300,155,270,45),B.PRESET_NAMES[i],func(): player_deck = B.PRESETS[index].duplicate(); player_lord = B.PRESET_LORDS[index]; save_choice(); show_deck())
	for i: int in range(3):
		var tab: String = ["unit","building","spell"][i]
		button(Rect2(120+i*210,235,190,44),["部隊","建築","法術"][i],func(): deck_tab = tab; show_deck())
	var lord_index := 0
	for lord_kind: String in B.LORDS:
		var choice := lord_kind
		var b := button(lord_rect(lord_index),"",func(): player_lord = choice; save_choice(); show_deck())
		b.tooltip_text = lord_tooltip(lord_kind)
		b.modulate = Color(1,1,1,0.01)
		lord_index += 1
	var index := 0
	for kind: String in B.CARDS:
		if B.CARDS[kind].type != deck_tab or kind == "farm": continue
		var card_kind := kind
		var rect := pool_rect(index,tab_size())
		var b := button(rect,"",func(): toggle_deck_card(card_kind))
		b.tooltip_text = card_description(kind)
		b.modulate = Color(1,1,1,0.01)
		index += 1
	button(Rect2(120,805,220,50),"回到標題",show_title)
	start_button = button(Rect2(1220,805,240,50),"儲存並開戰",func(): spectating = false; start_battle())
	start_button.disabled = not DeckStore.valid(player_deck)
	queue_redraw()

func tab_size() -> int:
	var n := 0
	for kind: String in B.CARDS:
		if B.CARDS[kind].type == deck_tab and kind != "farm": n += 1
	return n

func lord_tooltip(kind: String) -> String:
	var info: Dictionary = B.LORDS[kind]
	return "%s（%s）\n%d 血 · 普攻 %d\n%s" % [info.name,info.role,int(info.hp),int(info.damage),B.skill_text(kind)]

func lord_rect(index: int) -> Rect2:
	return Rect2(1010+index*190,150,180,90)

func save_choice() -> void:
	if DeckStore.valid(player_deck): DeckStore.save_deck(player_deck,deck_path,player_lord)

# Card pool layout: up to eight full-size cards in a row, narrower when a tab holds more.
func pool_rect(index: int, count: int) -> Rect2:
	var step := minf(170.0,1380.0/maxi(1,count))
	var width := minf(150.0,step-12)
	return Rect2(120+index*step,310,width,width*190.0/150.0)

func toggle_deck_card(kind: String) -> void:
	if kind in player_deck: player_deck.erase(kind)
	elif player_deck.size() < 8: player_deck.append(kind)
	else: menu_notice = "先取消一張已選卡牌，再加入新卡。"
	save_choice()
	show_deck()

func draw_deck() -> void:
	label_at(Vector2(120,100),"村莊牌組",48)
	label_at(Vector2(560,100),"農田＋領主固定，再選 8 張：%d / 8 · 平均 %.1f 金幣" % [player_deck.size(),DeckStore.average(player_deck)],22)
	label_at(Vector2(1010,140),"選擇領主",18)
	var lord_index := 0
	for lord_kind: String in B.LORDS:
		var r := lord_rect(lord_index)
		var info: Dictionary = B.LORDS[lord_kind]
		panel(r,Color("f2e3c0") if lord_kind == player_lord else Color("e3d2aa"),RED if lord_kind == player_lord else INK)
		if lord_kind == player_lord: draw_rect(r.grow(2),RED,false,3)
		draw_fitted(lord_art(lord_kind),Rect2(r.position+Vector2(6,6),Vector2(64,78)))
		label_at(r.position+Vector2(76,32),info.name,18)
		label_at(r.position+Vector2(76,56),"%s · %d 血" % [info.role,int(info.hp)],12,Color("6f5a3e"))
		label_at(r.position+Vector2(76,78),"技能：%s" % info.skill,12,RED)
		lord_index += 1
	var index := 0
	for kind: String in B.CARDS:
		if B.CARDS[kind].type != deck_tab or kind == "farm": continue
		var rect := pool_rect(index,tab_size())
		draw_card(kind,rect)
		if kind in player_deck: draw_rect(rect,Color("9b3d2c"),false,4)
		index += 1
	label_at(Vector2(120,555),"牌組（農田固定在常駐格；點上方卡牌加入或移除）",22)
	var fixed := Rect2(120,585,128,162)
	panel(fixed.grow(4),Color("cfdcae"),Color("3f5a2c"))
	draw_card("farm",fixed)
	for i: int in range(player_deck.size()): draw_card(player_deck[i],Rect2(268+i*146,585,128,162))
	label_at(Vector2(400,790),"需選滿 8 張不同卡牌（農田不用選）。" if not DeckStore.valid(player_deck) else menu_notice,20,RED)

# Random spectate deck (rules live in DeckStore so the balance tools share them).
static func random_deck(rng: RandomNumberGenerator) -> Array:
	return DeckStore.random_deck(rng)

func set_watch_source(team: int, source: int) -> void:
	watch_source[team] = source
	if source == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		watch_decks[team] = random_deck(rng)
		watch_lords[team] = B.LORDS.keys()[rng.randi_range(0,B.LORDS.size()-1)]
	elif source <= B.PRESETS.size():
		watch_decks[team] = B.PRESETS[source-1].duplicate()
		watch_lords[team] = B.PRESET_LORDS[source-1]
	else:
		watch_decks[team] = player_deck.duplicate() if DeckStore.valid(player_deck) else B.PRESETS[0].duplicate()
		watch_lords[team] = player_lord

# Clicking a card swaps it for the next card (in pool order) that this side doesn't hold yet.
func cycle_watch_card(team: int, index: int) -> void:
	var pool: Array = B.CARDS.keys().filter(func(k: String) -> bool: return k != "farm")
	var at: int = pool.find(watch_decks[team][index])
	for step: int in range(1,pool.size()):
		var next: String = pool[(at+step)%pool.size()]
		if not next in watch_decks[team]:
			watch_decks[team][index] = next
			break
	watch_source[team] = -1
	show_watch()

func watch_card_rect(team: int, index: int) -> Rect2:
	return Rect2(120+team*760+(index%4)*150,330+(index/4)*190,136,172)

func watch_lord_rect(team: int, index: int) -> Rect2:
	return Rect2(120+team*760+index*196,236,186,52)

func show_watch() -> void:
	screen = "watch"
	clear_ui()
	for team: int in range(2):
		if watch_decks[team].is_empty(): set_watch_source(team,0)
		var side := team
		var x := 120+team*760
		var source: int = watch_source[team]
		button(Rect2(x,170,290,48),"牌組：%s ▸" % ("自訂" if source < 0 else WATCH_SOURCES[source]),func(): set_watch_source(side,(maxi(source,0)+1)%WATCH_SOURCES.size()); show_watch())
		button(Rect2(x+306,170,180,48),"重新隨機",func(): set_watch_source(side,0); show_watch())
		var index := 0
		for lord_kind: String in B.LORDS:
			var choice := lord_kind
			var b := button(watch_lord_rect(team,index),"",func(): watch_lords[side] = choice; show_watch())
			b.tooltip_text = lord_tooltip(lord_kind)
			b.modulate = Color(1,1,1,0.01)
			index += 1
		for i: int in range(8):
			var slot := i
			var b := button(watch_card_rect(team,i),"",func(): cycle_watch_card(side,slot))
			b.tooltip_text = card_description(watch_decks[team][i])+"
（點一下換成下一張）"
			b.modulate = Color(1,1,1,0.01)
	button(Rect2(120,805,220,50),"回到標題",show_title)
	button(Rect2(690,805,220,50),"互換雙方",swap_watch)
	button(Rect2(1260,805,220,50),"開始觀戰",func(): spectating = true; start_battle())
	queue_redraw()

func swap_watch() -> void:
	watch_decks.reverse()
	watch_lords.reverse()
	watch_source.reverse()
	show_watch()

func draw_watch() -> void:
	label_at(Vector2(120,100),"觀戰設定",48)
	label_at(Vector2(420,100),"每邊預設隨機牌組與領主；點卡牌可換成下一張",20,Color("6f5a3e"))
	for team: int in range(2):
		var x := 120+team*760
		label_at(Vector2(x,150),"%s · 平均 %.1f 金幣" % ["紅獅" if team == 0 else "藍旗",DeckStore.average(watch_decks[team])],22,RED if team == 0 else BLUE)
		var index := 0
		for lord_kind: String in B.LORDS:
			var r := watch_lord_rect(team,index)
			var chosen: bool = watch_lords[team] == lord_kind
			panel(r,Color("f2e3c0") if chosen else Color("e3d2aa"),RED if chosen else INK)
			if chosen: draw_rect(r.grow(2),RED if team == 0 else BLUE,false,3)
			draw_fitted(lord_art(lord_kind,team),Rect2(r.position+Vector2(4,3),Vector2(40,46)))
			label_at(r.position+Vector2(50,22),B.LORDS[lord_kind].name,16)
			label_at(r.position+Vector2(50,42),B.LORDS[lord_kind].role,12,Color("6f5a3e"))
			index += 1
		for i: int in range(8): draw_card(watch_decks[team][i],watch_card_rect(team,i))
	draw_line(Vector2(800,150),Vector2(800,710),Color(INK,0.3),2)

func card_description(kind: String) -> String:
	return B.card_description(kind)

func help_columns() -> Array[String]:
	return [
		"[b]選牌與放置[/b]\n1–4 選手牌，F 選常駐農田；點卡再點戰場，或拖曳放置。右鍵取消選牌。Esc 有選牌時取消，沒選牌時切換暫停。\n空白鍵暫停；暫停或結束後按 R 重玩，戰鬥中按 R 不重開。\n\n[b]牌組與領主[/b]\n農田固定＋領主三選一＋自選 8 張輪轉牌。農田不輪轉、不佔 8 張名額。領主由 AI 移動，只在農田後方防守；按 Q 花 %s 金幣發動領主技能，冷卻 %s 秒。\n\n[b]金幣與冷卻[/b]\n金幣上限 %s。開局手牌無冷卻，後續每張牌各自冷卻。\n%s 分鐘後回復與冷卻速度 ×1.5；%s 分鐘後 ×2，等待時間會縮短。" % [B.number(B.SKILL_COST),B.number(B.SKILL_COOLDOWN),B.number(B.MAX_INK),B.number(B.RAMP_1/60),B.number(B.RAMP_2/60)],
		"[b]種田與防守[/b]\n農田自己產金幣；農民從田後方出發，順路耕田加速並回血。相同建築覆蓋自己的舊建築可補滿生命。\n部隊只往前走，不追身後範圍外的敵人；城門不反擊，靠領主、部隊與建築防守。\n\n[b]破門與勝負[/b]\n破門後該路部隊可部署到第六欄，建築仍限原始三欄。敵兵破門後需停下拆殘垣 %s 秒，再向家門前進。\n任何敵兵走進家門就輸，沒有時間限制。\n\n[b]觀戰模式[/b]\n開戰前調整雙方牌組與領主（預設隨機），AI 出牌；1–4 切換 ×1／×2／×4／×8，＋／－ 逐級調速。空白鍵暫停。" % B.number(B.RUBBLE_TIME)
	]

func show_help() -> void:
	screen = "help"
	clear_ui()
	var columns := help_columns()
	for i: int in range(columns.size()):
		var text := RichTextLabel.new()
		text.name = "HelpColumn%d" % i
		text.position = L.HELP_TEXT_RECTS[i].position
		text.size = L.HELP_TEXT_RECTS[i].size
		text.bbcode_enabled = true
		text.text = columns[i]
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_override("normal_font",font)
		text.add_theme_font_override("bold_font",font)
		text.add_theme_font_size_override("normal_font_size",L.HELP_FONT_SIZE)
		text.add_theme_font_size_override("bold_font_size",L.HELP_FONT_SIZE)
		text.add_theme_color_override("default_color",INK)
		add_child(text)
		ui.append(text)
	button(L.HELP_BACK,"回到標題",show_title)
	queue_redraw()

func draw_help() -> void:
	panel(L.HELP_PANEL)
	label_at(L.HELP_TITLE,"操作與勝負",44)

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
