extends RefCounted
# Adventure mode: a chain of stages on one campaign map. Each stage is one entry in STAGES; to add a
# stage, append a dictionary (and a map point) and it is drawn, unlocked and saved automatically.
#   kind     survive: hold until `limit` · breach: break in (lane = required lane, -1 any) before `limit`
#            economy: produce `gold` coins (and cast `skills` lord skills) before `limit`
#            conquer: beat the AI (`ai` = difficulty) with no time limit
#   deck     eight cards, or "player" for the player's own deck and lord
# All opponents use the normal card-playing AI; stage 1 opens with scheduled legal card plays.
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")
const DeckStore = preload("res://deck_store.gd")
const CHAPTERS := [
	{"name":"第一章　邊境農莊","color":Color("6f8a45")},
	{"name":"第二章　墓園之夜","color":Color("6a5277")},
	{"name":"第三章　五路決戰","color":Color("963f30")},
]
const KIND_NAMES := {"survive":"守城","breach":"破城","economy":"經營","conquer":"決戰"}
const DARK_DECK := ["skeleton","ghoul","necromancer","reaper","plague","bonewall","hunter","militia"]
const STAGES := [
	{"id":"first_farm","chapter":0,"map":Vector2(175,650),"name":"第一塊農田","lord":"harvest","kind":"conquer","ai":0,"enemy_lord":"iron",
	 "story":"農民聊著今年的收成，沒有注意到麥田另一頭的腳步聲。",
	 "goal":"守住唯一的農路，反攻並摧毀強盜帳篷。",
	 "deck":["farmer","hunter","farmer","hunter","militia","farmer","hunter","militia"],
	 "allow_duplicates":true,
	 },
	{"id":"fifth_drum","chapter":0,"map":Vector2(275,470),"name":"第五聲鼓","lord":"iron","kind":"survive","limit":90.0,
	 "story":"箭樓的燈還亮著。這次，你要等到所有人回來。",
	 "goal":"守住 90 秒，不讓敵兵入城。",
	 "deck":["shieldguard","hunter","tower","healer","militia","rain","farmer","drummer"],
	 },
	{"id":"old_bridge","chapter":0,"map":Vector2(400,615),"name":"故鄉木橋","lord":"lion","kind":"breach","lane":2,"limit":180.0,
	 "story":"攻城槌上的刻痕還在。城門另一邊，也有人認得。",
	 "goal":"180 秒內從第 III 路入城；敵軍入城則失敗。",
	 "deck":["ram","shieldguard","healer","hunter","farmer","rain","drummer","militia"],
	 "buildings":[[7,2,"tower"]],
	 },
	{"id":"roll_call","chapter":1,"map":Vector2(505,420),"name":"名冊錯字","lord":"underworld","kind":"economy","gold":60,"skills":1,"limit":180.0,
	 "story":"墓園開始收帳了。先備好金幣，再核對回來的是誰。",
	 "goal":"180 秒內累計產出 60 金幣，施放亡者大軍一次。",
	 "deck":["skeleton","bonewall","necromancer","curse","hunter","plague","shieldguard","drummer"],
	 },
	{"id":"night_watch","chapter":1,"map":Vector2(615,615),"name":"守夜人","lord":"underworld","kind":"survive","limit":120.0,
	 "story":"火把從五條路一起亮起來。骨牆擋得住一時，擋不住整夜。",
	 "goal":"守住 120 秒，不讓敵兵入城。",
	 "deck":["skeleton","bonewall","reaper","ghoul","plague","tower","rain","hunter"],
	 },
	{"id":"raven_road","chapter":1,"map":Vector2(725,410),"name":"烏鴉之路","lord":"underworld","kind":"breach","lane":-1,"limit":180.0,
	 "story":"對面的箭樓整夜沒熄。讓烏鴉先去，骨頭隨後就到。",
	 "goal":"180 秒內從任一路入城；敵軍入城則失敗。",
	 "deck":["raven","skeleton","ghoul","reaper","corpse_giant","curse","plague","ram"],
	 "buildings":[[7,1,"tower"],[7,3,"tower"]],
	 },
	{"id":"iron_gate","chapter":2,"map":Vector2(810,600),"name":"鐵壁之前","lord":"iron","kind":"conquer","ai":0,"enemy_lord":"harvest",
	 "story":"豐收領主的糧倉堆得比城牆還高。對手正不斷集結兵力。",
	 "goal":"擊敗簡單難度的豐收領主。",
	 "deck":["shieldguard","militia","hunter","tower","knight","rain","ram","drummer"]},
	{"id":"ash_harvest","chapter":2,"map":Vector2(880,430),"name":"豐收與骨灰","lord":"lion","kind":"conquer","ai":1,"enemy_lord":"underworld","enemy_deck":DARK_DECK,
	 "story":"墓碑立到了麥田邊上。紅獅要在收成之前，把它們推回去。",
	 "goal":"擊敗普通難度的冥府領主。",
	 "deck":["militia","knight","mob","ox","hunter","rain","fire","healer"]},
	{"id":"last_page","chapter":2,"map":Vector2(925,255),"name":"最後一頁","lord":"","kind":"conquer","ai":2,"enemy_lord":"lion",
	 "story":"戰史只剩最後一頁。帶上你自己編的牌組，寫下結局。",
	 "goal":"用你的牌組與領主，擊敗困難難度的紅獅領主。",
	 "deck":"player"},
]

var index := -1 # the stage being played, -1 outside adventure battles
var selected := 0 # the stage shown on the map panel
var opening := preload("res://farm_opening.gd").new()
var ending := preload("res://adventure_ending.gd").new()
var recruit := ""
var outcome := ""
var cleared: Dictionary = {}
var progress_path := "user://adventure.json"

func load_progress() -> void:
	cleared = {}
	recruit = ""
	if not FileAccess.file_exists(progress_path): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if parsed is Dictionary and parsed.get("cleared") is Array:
		for id in parsed.cleared: cleared[str(id)] = true
		if parsed.get("recruit", "") in ["bandit","knight"]: recruit = parsed.recruit

func save_progress() -> bool:
	var file := FileAccess.open(progress_path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"cleared":cleared.keys(),"recruit":recruit}))
	file.flush()
	return file.get_error() == OK

func is_cleared(i: int) -> bool:
	return cleared.has(STAGES[i].id)

func unlocked(i: int) -> bool:
	return i == 0 or is_cleared(i-1)

func cleared_count() -> int:
	return range(STAGES.size()).filter(func(i: int) -> bool: return is_cleared(i)).size()

# The first stage not yet cleared (the last one when everything is done).
func frontier() -> int:
	for i: int in range(STAGES.size()):
		if not is_cleared(i): return i
	return STAGES.size()-1

func stage_lord(game, i: int) -> String:
	return game.player_lord if STAGES[i].deck is String else STAGES[i].lord

func stage_deck(game, i: int) -> Array:
	var deck: Array = game.player_deck.duplicate() if STAGES[i].deck is String else STAGES[i].deck.duplicate()
	if i > 0 and STAGES[i].deck is Array and not recruit.is_empty() and not recruit in deck and B.card_allowed(recruit,stage_lord(game,i)):
		deck[deck.size()-1] = recruit
	return deck

func start(game, choice: int) -> void:
	index = choice
	selected = choice
	outcome = ""
	var d: Dictionary = STAGES[index]
	var lord := stage_lord(game,index)
	var deck := stage_deck(game,index)
	if not DeckStore.valid(deck,lord,d.get("allow_duplicates",false) and not d.deck is String):
		index = -1
		game.show_deck()
		return
	game.spectating = false
	var ai: int = d.get("ai",1)
	var enemy: Array = d.get("enemy_deck",B.PRESETS[ai]).duplicate()
	game.model = Battle.new(7300+index,deck,enemy,lord,d.get("enemy_lord","iron"))
	game.model.difficulty = ai
	game.model.ai_enabled = [false,true]
	game.model.invasion_victory[0] = d.kind in ["breach","conquer"]
	for b: Array in d.get("buildings",[]): game.model.add_building(1,Vector2i(b[0],b[1]),"tower")
	opening.active = false
	if index == 0: opening.start(game)
	game.enter_battle("%s · %s" % [d.name,d.goal])

func update(game) -> void:
	if index < 0 or game.model.paused or not outcome.is_empty(): return
	var m = game.model
	var d: Dictionary = STAGES[index]
	if m.ended:
		var won: bool = m.winner == 0
		if d.kind == "breach" and d.lane >= 0: won = won and game.review.break_lane == d.lane
		if won and index == 0 and recruit.is_empty():
			ending.begin(game)
			return
		settle(won,"")
		if not won: m.winner = 1
		return
	var limit: float = d.get("limit",0.0)
	var complete: bool = d.kind == "survive" and m.elapsed >= limit
	if d.kind == "economy": complete = m.stats[0].produced >= d.gold and m.stats[0].get("skills",0) >= d.skills
	if complete:
		settle(true,"")
		m.finish(0)
	elif limit > 0 and m.elapsed >= limit:
		settle(false,"：時間用盡")
		m.finish(1)
	elif limit > 0:
		game.notice = "%s · %s　剩餘 %d 秒" % [d.name,d.goal,maxi(0,ceili(limit-m.elapsed))]

func settle(won: bool, reason: String) -> void:
	outcome = ("第 %d 關通過！" % (index+1)) if won else "挑戰失敗"+reason
	if won and not is_cleared(index):
		cleared[STAGES[index].id] = true
		save_progress()
	if won and index+1 < STAGES.size(): selected = index+1

# ---- Campaign map screen ----------------------------------------------------------------------
const MAP := Rect2(70,150,960,650)
const SIDE := Rect2(1060,150,470,650)

func show(game) -> void:
	load_progress()
	index = -1
	if not unlocked(selected): selected = frontier()
	game.screen = "adventure"
	game.clear_ui()
	for i: int in range(STAGES.size()):
		var choice := i
		var b: Button = seal_button(game,Rect2(STAGES[i].map-Vector2(34,34),Vector2(68,68)),func(): selected = choice; show(game))
		b.tooltip_text = STAGES[i].name
	var d: Dictionary = STAGES[selected]
	game.library.text_box(Rect2(SIDE.position.x+30,SIDE.position.y+250,SIDE.size.x-60,120),d.story,21)
	if unlocked(selected):
		game.title_button(Rect2(SIDE.position.x+60,SIDE.end.y-78,SIDE.size.x-120,56),"再次出征" if is_cleared(selected) else "出征",func(): start(game,selected),true)
	game.title_button(Rect2(100,820,230,46),"返回標題",game.show_title)
	game.queue_redraw()

func seal_button(game, rect: Rect2, action: Callable) -> Button:
	var b: Button = game.button(rect,"",action)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1,0.9,0.6,0.18) if state == "hover" else Color.TRANSPARENT
		style.set_corner_radius_all(34)
		if state == "focus":
			style.border_color = Color("d2ad58")
			style.set_border_width_all(2)
		b.add_theme_stylebox_override(state,style)
	return b

func paint(g) -> void:
	g.label_at(Vector2(90,88),"冒險模式",44)
	g.label_at(Vector2(300,88),"已通過 %d / %d 關" % [cleared_count(),STAGES.size()],22)
	if not recruit.is_empty(): g.label_at(Vector2(650,88),"同行部隊："+B.CARDS[recruit].name,24)
	g.label_at(Vector2(90,126),"依序攻下九場戰役；每關有固定的領主與牌組，不會改動你自己的牌組。",20)
	paint_map(g)
	paint_side(g)

func paint_map(g) -> void:
	g.panel(MAP,Color(0.93,0.86,0.70,0.55))
	# Three regions left to right: farmland, the graveyard, the castles of the final war.
	g.ground_wash(Vector2(270,560),Vector2(220,200),Color("9fae62"),11,0.22)
	g.ground_wash(Vector2(615,520),Vector2(170,200),Color("7a6a86"),23,0.20)
	g.ground_wash(Vector2(880,440),Vector2(150,280),Color("b37a5c"),37,0.18)
	for i: int in range(3):
		var x: float = [100.0,450.0,770.0][i]
		g.draw_string(g.font,Vector2(x,MAP.position.y+42),CHAPTERS[i].name,HORIZONTAL_ALIGNMENT_LEFT,-1,22,CHAPTERS[i].color)
	g.draw_fitted(g.art("farm"),Rect2(100,300,120,90),Color(1,1,1,0.7),true)
	g.draw_fitted(g.art("farm"),Rect2(330,330,110,80),Color(1,1,1,0.6),true)
	g.draw_fitted(g.art("mill"),Rect2(120,420,80,80),Color(1,1,1,0.6),true)
	g.draw_fitted(g.art("grave",1),Rect2(560,250,60,80),Color(1,1,1,0.7),true)
	g.draw_fitted(g.art("grave",1),Rect2(680,680,55,75),Color(1,1,1,0.6),true)
	g.draw_fitted(g.art("bonewall",1),Rect2(470,690,70,70),Color(1,1,1,0.55),true)
	g.draw_fitted(g.art("tower",1),Rect2(950,620,70,110),Color(1,1,1,0.7),true)
	g.draw_fitted(g.art("castle_red"),Rect2(800,210,90,110),Color(1,1,1,0.55),true)
	# The road: inked solid where the army has marched, dotted ahead.
	for i: int in range(STAGES.size()-1):
		var a: Vector2 = STAGES[i].map
		var b: Vector2 = STAGES[i+1].map
		if is_cleared(i): g.ink_line(a,b,i,Color(g.RED,0.8),4.0)
		else:
			var steps := int(a.distance_to(b)/14)
			for s: int in range(1,steps):
				if s % 2 == 0: g.draw_circle(a.lerp(b,float(s)/steps),2.6,Color(g.INK,0.55))
	for i: int in range(STAGES.size()):
		paint_seal(g,i)
	# The lord marching on the map stands at the next open stage.
	var here: int = frontier()
	g.draw_fitted(g.lord_art(stage_lord(g,here)),Rect2(STAGES[here].map+Vector2(-30,-118),Vector2(60,78)),Color.WHITE,true)

func paint_seal(g, i: int) -> void:
	var p: Vector2 = STAGES[i].map
	var open := unlocked(i)
	var chapter: Color = CHAPTERS[STAGES[i].chapter].color
	if i == selected: g.draw_circle(p,38,Color("d2ad58",0.9))
	g.draw_circle(p+Vector2(3,4),30,Color(0.2,0.12,0.06,0.25))
	var fill: Color = g.RED if is_cleared(i) else (chapter if open else Color("a89a80"))
	g.draw_circle(p,30,fill)
	g.draw_arc(p,30,0,TAU,40,Color(g.INK,0.85),2.5,true)
	g.draw_arc(p,24,0,TAU,40,Color(1,0.94,0.8,0.5 if open else 0.25),1.5,true)
	var text_color := Color("fff0ca") if open else Color("6c6253")
	g.draw_string(g.font,p+Vector2(-30,10),str(i+1),HORIZONTAL_ALIGNMENT_CENTER,60,28,text_color)
	g.draw_string(g.font,p+Vector2(-80,58),STAGES[i].name,HORIZONTAL_ALIGNMENT_CENTER,160,19,g.INK if open else Color(g.INK,0.45))
	if is_cleared(i): g.draw_string(g.font,p+Vector2(-80,80),"已通過",HORIZONTAL_ALIGNMENT_CENTER,160,15,g.RED)

func paint_side(g) -> void:
	var d: Dictionary = STAGES[selected]
	var x: float = SIDE.position.x
	var w: float = SIDE.size.x
	g.panel(SIDE,Color("efe0bd"))
	g.ink_frame(SIDE.grow(-8))
	var chapter: Dictionary = CHAPTERS[d.chapter]
	g.draw_string(g.font,Vector2(x,SIDE.position.y+48),chapter.name,HORIZONTAL_ALIGNMENT_CENTER,w,20,chapter.color)
	g.draw_string(g.font,Vector2(x,SIDE.position.y+100),"第 %d 關　%s" % [selected+1,d.name],HORIZONTAL_ALIGNMENT_CENTER,w,36,g.INK)
	var lord := stage_lord(g,selected)
	g.draw_fitted(g.lord_art(lord),Rect2(x+40,SIDE.position.y+118,96,120),Color.WHITE,true)
	g.label_at(Vector2(x+160,SIDE.position.y+160),"領主　"+B.LORDS[lord].name,22)
	g.label_at(Vector2(x+160,SIDE.position.y+196),"類型　"+KIND_NAMES[d.kind],22)
	if d.kind == "conquer": g.label_at(Vector2(x+160,SIDE.position.y+232),"對手　"+B.LORDS[d.enemy_lord].name+" · "+["簡單","普通","困難"][d.ai],22)
	g.draw_string(g.font,Vector2(x+30,SIDE.position.y+400),"目標：",HORIZONTAL_ALIGNMENT_LEFT,-1,21,g.RED)
	g.draw_multiline_string(g.font,Vector2(x+95,SIDE.position.y+400),d.goal,HORIZONTAL_ALIGNMENT_LEFT,w-125,21,-1,g.RED)
	# The eight cards this stage hands the player.
	var deck := stage_deck(g,selected)
	for i: int in range(deck.size()):
		var cell := Rect2(x+30+(i%4)*104,SIDE.position.y+448+(i/4)*58,96,52)
		g.panel(cell,Color("f6ead0"))
		g.draw_fitted(g.art(deck[i]),Rect2(cell.position+Vector2(4,3),Vector2(42,46)))
		g.draw_string(g.font,cell.position+Vector2(46,32),B.CARDS[deck[i]].name,HORIZONTAL_ALIGNMENT_CENTER,48,13 if B.CARDS[deck[i]].name.length() > 3 else 15,g.INK)
	if not unlocked(selected):
		g.draw_string(g.font,Vector2(x,SIDE.end.y-40),"通過上一關後解鎖",HORIZONTAL_ALIGNMENT_CENTER,w,24,Color(g.INK,0.6))
