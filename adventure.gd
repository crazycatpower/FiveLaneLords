extends RefCounted
# Adventure mode: a chain of stages on one campaign map. Each stage is one entry in STAGES; to add a
# stage, append a dictionary (and a map point) and it is drawn, unlocked and saved automatically.
#   kind     conquer: normal invasion victory, without special objectives
#   deck     eight cards, or "player" for the player's own deck and lord
# All opponents use the normal card-playing AI; stage 1 opens with scheduled legal card plays.
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")
const DeckStore = preload("res://deck_store.gd")
const CHAPTERS := [
	{"name":"第一章　戰亂與重稅","color":Color("6f8a45")},
	{"name":"第二章　亡靈的契約","color":Color("6a5277")},
	{"name":"第三章　領主同盟","color":Color("963f30")},
]
const KIND_NAMES := {"survive":"守城","breach":"破城","economy":"經營","conquer":"決戰"}
const DARK_DECK := ["skeleton","ghoul","necromancer","reaper","plague","bonewall","hunter","militia"]
const STARTER_CARDS := ["farmer","hunter","militia"]
const STAGE_UNLOCKS := {
  "first_farm": [],
  "fifth_drum": [
    "mob"
  ],
  "old_bridge": [
    "ram"
  ],
  "swamp_path": [
    "rain"
  ],
  "abandoned_mill": [
    "mill",
    "healer"
  ],
  "patrol_riders": [
    "scarecrow"
  ],
  "tavern_brawl": [
    "knight",
    "drummer",
    "fire"
  ],
  "beacon_gate": [
    "ox",
    "harvest"
  ],
  "canal_sluice": [
    "shieldguard",
    "tower",
    "catapult"
  ],
  "warlord_camp": []
}
const STAGES := [
	{"id":"first_farm","chapter":0,"name":"第一塊農田","lord":"adventure","kind":"conquer","ai":0,"enemy_lord":"iron","story":"東邊戰亂不斷，領主加徵重稅。逃荒的人與叛逃民兵流落邊境。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":["farmer","hunter","farmer","hunter","militia","farmer","hunter","militia"],"enemy_deck":["bandit","bandit","bandit","bandit","bandit","bandit","bandit","bandit"],"active_lanes":[2],"buildings":[],"allow_duplicates":true,"map":Vector2(120,630)},
	{"id":"fifth_drum","chapter":0,"name":"東邊的路稅","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"iron","story":"強盜與叛逃民兵佔住農路，打著收稅的旗號搶糧。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":["mob","farmer","hunter","militia","mob","farmer","hunter","militia"],"enemy_deck":["bandit","militia","bandit","militia","bandit","militia","bandit","militia"],"active_lanes":[1,2,3],"buildings":[[7,1,"tower"],[7,2,"tower"],[7,3,"tower"]],"allow_duplicates":true,"map":Vector2(195,490)},
	{"id":"old_bridge","chapter":0,"name":"故鄉木橋","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"iron","story":"截下木橋上的走私車隊，追查糧食與兵器的去向。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":["ram","mob","farmer","hunter","militia","ram","hunter","militia"],"enemy_deck":["bandit","militia","hunter","bandit","militia","hunter","bandit","militia"],"active_lanes":[0,1,2,3,4],"buildings":[[7,2,"tower"]],"allow_duplicates":true,"map":Vector2(285,610)},
	{"id":"swamp_path","chapter":1,"name":"泥沼亡影","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"underworld","story":"沿運貨名冊進入泥沼，第一次看見亡靈搬運人類打造的兵器。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":["rain","ram","mob","farmer","hunter","militia","hunter","rain"],"enemy_deck":["bandit","militia","hunter","skeleton","bandit","militia","hunter","skeleton"],"active_lanes":[0,1,3,4],"buildings":[],"allow_duplicates":true,"map":Vector2(370,460)},
	{"id":"abandoned_mill","chapter":1,"name":"磨坊密信","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"underworld","story":"亡靈佔據廢棄磨坊，地窖裡藏著人類管事與死靈法師的接頭信。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":["mill","healer","rain","ram","mob","farmer","hunter","militia"],"enemy_deck":["bandit","militia","hunter","skeleton","ghoul","skeleton","ghoul","skeleton"],"active_lanes":[1,2,3],"buildings":[],"map":Vector2(460,590)},
	{"id":"patrol_riders","chapter":1,"name":"墓園契約","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"underworld","story":"在墓園找到有雙方印記的契約：人類以糧食、兵器換取亡靈軍隊。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":"player","enemy_deck":["bandit","militia","hunter","skeleton","ghoul","necromancer","skeleton","ghoul"],"active_lanes":[0,1,2,3,4],"buildings":[],"map":Vector2(550,440)},
	{"id":"tavern_brawl","chapter":2,"name":"馳援紅獅","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"underworld","story":"將證據交給紅獅領主，協助他擊退亡靈先鋒。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":"player","enemy_deck":["bandit","militia","skeleton","ghoul","necromancer","reaper","bonewall","skeleton"],"active_lanes":[0,1,2,3,4],"buildings":[[7,2,"bonewall"]],"support_lord":"lion","map":Vector2(640,580)},
	{"id":"beacon_gate","chapter":2,"name":"守護豐收","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"underworld","story":"豐收領主的糧倉遭亡靈包圍，保住糧道，讓援軍繼續前進。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":"player","enemy_deck":["bandit","militia","skeleton","ghoul","necromancer","reaper","bonewall","raven"],"active_lanes":[1,2,3],"buildings":[[7,1,"grave"],[7,3,"grave"]],"support_lord":"harvest","map":Vector2(730,430)},
	{"id":"canal_sluice","chapter":2,"name":"鐵壁之圍","lord":"adventure","kind":"conquer","ai":1,"enemy_lord":"underworld","story":"鐵壁領主守住最後一道關口。打退圍城亡靈，打開進軍冥府的路。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":"player","enemy_deck":["militia","skeleton","ghoul","necromancer","reaper","bonewall","raven","corpse_giant"],"active_lanes":[0,1,2,3,4],"buildings":[[7,0,"bonewall"],[7,4,"bonewall"]],"support_lord":"iron","map":Vector2(820,570)},
	{"id":"warlord_camp","chapter":2,"name":"冥府王座","lord":"adventure","kind":"conquer","ai":2,"enemy_lord":"underworld","story":"三位領主已牽制亡靈大軍。率領集結的部隊，直取亡靈領主的王座。","goal":"攻入敵方底線獲勝；敵軍攻入我方底線則失敗。","deck":"player","enemy_deck":["skeleton","ghoul","necromancer","reaper","raven","corpse_giant","plague","curse"],"active_lanes":[0,1,2,3,4],"buildings":[[7,1,"grave"],[7,2,"bonewall"],[7,3,"grave"]],"map":Vector2(915,360)},
]
var index := -1 # the stage being played, -1 outside adventure battles
var selected := 0 # the stage shown on the map panel
var opening := preload("res://farm_opening.gd").new()
var ending := preload("res://adventure_ending.gd").new()
var road_story := preload("res://road_toll_story.gd").new()
var bridge_story := preload("res://bridge_story.gd").new()
var recruit := ""
var outcome := ""
var cleared: Dictionary = {}
var custom_deck: Array = []
var progress_path := "user://adventure.json"

func unlocked_cards() -> Array:
	var result: Array = STARTER_CARDS.duplicate()
	if not recruit.is_empty() and not recruit in result:
		result.append(recruit)
	for i: int in range(STAGES.size()):
		if is_cleared(i):
			for k: String in STAGE_UNLOCKS.get(STAGES[i].id,[]):
				if not k in result:
					result.append(k)
	return result

func custom_deck_valid() -> bool:
	if custom_deck.size() != 8: return false
	var pool: Array = unlocked_cards()
	for k in custom_deck:
		if not k is String or not k in pool: return false
	return DeckStore.valid(custom_deck,"adventure")

func load_progress() -> void:
	cleared = {}
	recruit = ""
	custom_deck = []
	if not FileAccess.file_exists(progress_path): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if parsed is Dictionary and parsed.get("cleared") is Array:
		for id in parsed.cleared: cleared[str(id)] = true
		if parsed.get("recruit", "") in ["bandit","knight"]: recruit = parsed.recruit
		if parsed.get("custom_deck") is Array:
			var valid_list: Array = []
			for c in parsed.custom_deck:
				if c is String and B.CARDS.has(c): valid_list.append(c)
			if valid_list.size() == 8: custom_deck = valid_list

func save_progress() -> bool:
	var file := FileAccess.open(progress_path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"cleared":cleared.keys(),"recruit":recruit,"custom_deck":custom_deck}))
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
	return STAGES[i].lord

func stage_deck(game, i: int) -> Array:
	if STAGES[i].deck is String:
		if custom_deck_valid(): return custom_deck.duplicate()
		var pool := unlocked_cards()
		if pool.size() >= 8: return pool.slice(0,8)
		if game.player_deck.size() == 8 and DeckStore.valid(game.player_deck,stage_lord(game,i)):
			return game.player_deck.duplicate()
		return ["farmer","hunter","militia","mob","ram","rain","mill","healer"]
	var deck: Array = STAGES[i].deck.duplicate()
	if i > 0 and not recruit.is_empty() and not recruit in deck and B.card_allowed(recruit,stage_lord(game,i)):
		deck[deck.size()-1] = recruit
	return deck

func open_adventure_deck(game) -> void:
	game.adventure_deck_mode = true
	game.player_lord = "adventure"
	if custom_deck_valid():
		game.player_deck = custom_deck.duplicate()
	else:
		var pool := unlocked_cards()
		if pool.size() >= 8: game.player_deck = pool.slice(0,8)
		else: game.player_deck = pool.duplicate()
	game.deck_tab = "unit"
	game.deck_page = 0
	game.show_deck()

func start(game, choice: int) -> void:
	index = choice
	selected = choice
	outcome = ""
	var d: Dictionary = STAGES[index]
	var lord := stage_lord(game,index)
	var deck := stage_deck(game,index)
	if not DeckStore.valid(deck,lord,d.get("allow_duplicates",false) and not d.deck is String):
		index = -1
		open_adventure_deck(game)
		return
	game.spectating = false
	var ai: int = d.get("ai",1)
	var enemy: Array = d.get("enemy_deck",B.PRESETS[ai]).duplicate()
	game.model = Battle.new(7300+index,deck,enemy,lord,d.get("enemy_lord","iron"))
	game.model.active_lanes.assign(d.get("active_lanes",[0,1,2,3,4]))
	if index < 9:
		game.model.lord_active[1] = false
		game.model.lords[1].hp = 0
	if index < 3:
		game.model.home_cards[1] = ""
		game.model.buildings = game.model.buildings.filter(func(b): return b.team == 0)
		game.model.refresh_territory()
	game.model.difficulty = ai
	game.model.ai_enabled = [false,true]
	game.model.invasion_victory.assign([true,true])
	for b: Array in d.get("buildings",[]): game.model.add_building(1,Vector2i(b[0],b[1]),b[2])
	opening.active = false
	if index == 0: opening.start(game)
	game.enter_battle("%s · %s" % [d.name,d.goal])
	if index in range(1, 10): road_story.begin(game)

func update(game) -> void:
	if index < 0 or game.model.paused or not outcome.is_empty(): return
	var m = game.model
	if not m.ended: return
	var won: bool = m.winner == 0
	if won and index == 0 and recruit.is_empty():
		ending.begin(game)
		return
	settle(won,"")
	if won and index in range(1, 10): road_story.begin(game, true)

func active_story():
	return road_story

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
	game.library.text_box(Rect2(SIDE.position.x+30,SIDE.position.y+225,SIDE.size.x-60,65),d.story,21)
	if unlocked(selected):
		if STAGES[selected].deck is String:
			game.title_button(Rect2(SIDE.position.x+60,SIDE.position.y+516,SIDE.size.x-120,44),"組牌編成",func(): open_adventure_deck(game))
			game.title_button(Rect2(SIDE.position.x+60,SIDE.end.y-72,SIDE.size.x-120,52),"再次出征" if is_cleared(selected) else "出征",func():
				if not custom_deck_valid(): open_adventure_deck(game)
				else: start(game,selected)
			,true)
		else:
			game.title_button(Rect2(SIDE.position.x+60,SIDE.end.y-72,SIDE.size.x-120,52),"再次出征" if is_cleared(selected) else "出征",func(): start(game,selected),true)
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
	g.label_at(Vector2(290,88),"已通過 %d / %d 關" % [cleared_count(),STAGES.size()],22)
	g.label_at(Vector2(500,88),"已解鎖卡牌：%d" % unlocked_cards().size(),22)
	if not recruit.is_empty(): g.label_at(Vector2(730,88),"同行部隊："+B.CARDS[recruit].name,22)
	g.label_at(Vector2(90,126),"戰亂與重稅 → 亡靈勾結 → 支援三位領主 → 決戰亡靈領主。",20)
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
	g.draw_fitted(g.lord_art(lord),Rect2(x+40,SIDE.position.y+110,96,100),Color.WHITE,true)
	g.label_at(Vector2(x+160,SIDE.position.y+140),"領主　"+B.LORDS[lord].name,22)
	g.label_at(Vector2(x+160,SIDE.position.y+170),"類型　"+KIND_NAMES[d.kind],22)
	if d.kind == "conquer":
		var opponent: String = "強盜與叛逃民兵" if selected < 3 else B.LORDS[d.enemy_lord].name+" · "+["簡單","普通","困難"][d.ai]
		g.label_at(Vector2(x+160,SIDE.position.y+200),"對手　"+opponent,18)
	g.draw_string(g.font,Vector2(x+30,SIDE.position.y+305),"目標：",HORIZONTAL_ALIGNMENT_LEFT,-1,20,g.RED)
	g.draw_multiline_string(g.font,Vector2(x+95,SIDE.position.y+305),"攻入敵方底線即獲勝。\n敵軍攻入我方底線則失敗。",HORIZONTAL_ALIGNMENT_LEFT,w-125,18,-1,g.RED)
	g.draw_string(g.font,Vector2(x+30,SIDE.position.y+348),"已解鎖卡牌：%d" % unlocked_cards().size(),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("6f5a3e"))
	var is_custom: bool = d.deck is String
	var header_text: String = "出征牌組（自選 8 張）：" if is_custom else "關卡固定部隊："
	g.draw_string(g.font,Vector2(x+30,SIDE.position.y+375),header_text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,g.INK)
	# The eight cards this stage hands the player.
	var deck := stage_deck(g,selected)
	for i: int in range(deck.size()):
		var cell := Rect2(x+30+(i%4)*104,SIDE.position.y+395+(i/4)*56,96,50)
		g.panel(cell,Color("f6ead0"))
		g.draw_fitted(g.art(deck[i]),Rect2(cell.position+Vector2(4,2),Vector2(42,46)))
		g.draw_string(g.font,cell.position+Vector2(46,31),B.CARDS[deck[i]].name,HORIZONTAL_ALIGNMENT_CENTER,48,13 if B.CARDS[deck[i]].name.length() > 3 else 15,g.INK)
	if not unlocked(selected):
		g.draw_string(g.font,Vector2(x,SIDE.end.y-40),"通過上一關後解鎖",HORIZONTAL_ALIGNMENT_CENTER,w,24,Color(g.INK,0.6))
