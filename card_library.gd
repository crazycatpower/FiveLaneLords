extends RefCounted
const B = preload("res://balance.gd")
const Lore = preload("res://card_lore.gd")
const INFO_RECT := Rect2(464,28,230,48)
var game
var category := "all"
var page := 0
var selected := "farm"
var return_screen := "title"
var was_paused := false

func _init(owner_game) -> void:
	game = owner_game

func entries() -> Array[String]:
	var result: Array[String] = []
	for kind: String in B.CARDS:
		if category == "all" or B.CARDS[kind].type == category: result.append(kind)
	if category in ["all","lord"]:
		for kind: String in B.LORDS: result.append("lord_"+kind)
	return result

func open(kind: String = "", origin: String = "title") -> void:
	return_screen = origin
	if not kind.is_empty():
		selected = kind
		category = "lord" if kind.begins_with("lord_") else B.CARDS[kind].type
		page = entries().find(kind)/12
	show_catalog()

func text_box(rect: Rect2, text: String, size: int = 20) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.add_theme_font_override("normal_font",game.font)
	label.add_theme_font_size_override("normal_font_size",size)
	label.add_theme_color_override("default_color",game.INK)
	game.add_child(label)
	game.ui.append(label)
	return label

func show_catalog() -> void:
	game.screen = "codex"
	game.clear_ui()
	var tabs := [["all","全部"],["unit","部隊"],["building","建築"],["spell","法術"],["lord","領主"]]
	for i: int in range(tabs.size()):
		var filter: String = tabs[i][0]
		game.title_button(Rect2(80+i*146,120,132,42),tabs[i][1],func(): category = filter; page = 0; show_catalog(),category == filter)
	var list := entries()
	page = clampi(page,0,maxi(0,(list.size()-1)/12))
	if not selected in list: selected = list[0]
	for i: int in range(page*12,mini((page+1)*12,list.size())):
		var kind := list[i]
		var r := catalog_rect(i%12)
		var hit = game.button(r,"",func(): selected = kind; show_catalog())
		hit.modulate.a = 0.01
		hit.tooltip_text = entry_name(kind)
	game.title_button(Rect2(80,802,170,46),"返回",back)
	game.title_button(Rect2(420,802,140,46),"上一頁",func(): page -= 1; show_catalog()).disabled = page == 0
	game.title_button(Rect2(670,802,140,46),"下一頁",func(): page += 1; show_catalog()).disabled = (page+1)*12 >= list.size()
	var lord := selected.begins_with("lord_")
	var rules: String = B.skill_text(selected.trim_prefix("lord_")) if lord else B.card_description(selected)
	text_box(Rect2(955,429,535,162),rules,20)
	text_box(Rect2(955,645,535,130),Lore.TEXT.get(selected,""),23)
	game.queue_redraw()

func back() -> void:
	if return_screen == "battle_info": show_battle_info(false)
	else: game.show_title()

static func catalog_rect(index: int) -> Rect2:
	return Rect2(86+(index%4)*184,188+(index/4)*196,158,179)

static func entry_name(kind: String) -> String:
	return B.LORDS[kind.trim_prefix("lord_")].name if kind.begins_with("lord_") else B.CARDS[kind].name

func draw_catalog() -> void:
	game.panel(Rect2(62,62,790,724))
	game.label_at(Vector2(86,102),"卡牌圖鑑",32)
	for i: int in range(page*12,mini((page+1)*12,entries().size())):
		var kind: String = entries()[i]
		var r := catalog_rect(i%12)
		if kind == selected: game.panel(r.grow(4),Color("b8c594"),Color("52633c"))
		if kind.begins_with("lord_"):
			game.panel(r)
			game.draw_fitted(game.art(kind),Rect2(r.position+Vector2(15,6),Vector2(128,132)))
			game.draw_string(game.font,r.position+Vector2(0,163),entry_name(kind),HORIZONTAL_ALIGNMENT_CENTER,r.size.x,19,game.INK)
		else: game.draw_card(kind,r)
	game.label_at(Vector2(578,832),"%d / %d" % [page+1,ceili(entries().size()/12.0)],19)
	game.panel(Rect2(914,62,624,786))
	game.draw_string(game.font,Vector2(934,114),entry_name(selected),HORIZONTAL_ALIGNMENT_CENTER,584,34,game.INK)
	if selected.begins_with("lord_"): game.draw_fitted(game.art(selected),Rect2(1050,137,350,233))
	else: game.draw_card_art(selected,Rect2(1050,137,350,233))
	game.label_at(Vector2(955,411),"卡牌說明",22)
	game.ink_line(Vector2(955,611),Vector2(1490,611),3)
	game.label_at(Vector2(955,637),"卡牌趣聞",22)

func show_battle_info(entering: bool = true) -> void:
	if entering:
		was_paused = game.model.paused
		game.model.paused = true
		game.dragging = false
	game.screen = "battle_info"
	game.clear_ui()
	game.title_button(Rect2(90,804,220,48),"返回對戰",close_battle_info)
	game.title_button(Rect2(1270,804,230,48),"完整圖鑑",func(): open("","battle_info"))
	for team: int in range(2):
		var kinds: Array = [game.model.home_cards[team]]+game.model.decks[team].duplicate()
		for i: int in range(kinds.size()):
			var kind: String = kinds[i]
			var hit = game.button(deck_rect(team,i),"",func(): open(kind,"battle_info"))
			hit.modulate.a = 0.01
			hit.tooltip_text = entry_name(kind)+" · 查看圖鑑"
		var lord: String = "lord_"+game.model.lords[team].lord
		var hit = game.button(Rect2(95,215+team*285,132,170),"",func(): open(lord,"battle_info"))
		hit.modulate.a = 0.01
	game.queue_redraw()

func close_battle_info() -> void:
	game.clear_ui()
	game.screen = "battle"
	game.model.paused = was_paused
	game.queue_redraw()

static func deck_rect(team: int, index: int) -> Rect2:
	return Rect2(248+index*139,215+team*285,122,174)

func composition(team: int) -> String:
	var counts := {"unit":0,"building":0,"spell":0}
	for kind: String in game.model.decks[team]: counts[B.CARDS[kind].type] += 1
	return "八張輪轉牌：部隊 %d · 建築 %d · 法術 %d" % [counts.unit,counts.building,counts.spell]

func draw_battle_info() -> void:
	game.panel(Rect2(62,62,1476,712))
	game.label_at(Vector2(90,111),"戰局資料",38)
	game.label_at(Vector2(385,107),"難度："+["簡單","普通","困難"][game.model.difficulty],24)
	game.label_at(Vector2(1120,107),"閱讀中暫停 · 點卡牌查看趣聞",19)
	for team: int in range(2):
		var y := 175+team*285
		var lord: String = game.model.lords[team].lord
		game.label_at(Vector2(95,y),["紅方","藍方"][team]+" · "+B.LORDS[lord].name,24,game.RED if team == 0 else game.BLUE)
		game.label_at(Vector2(600,y),composition(team),22)
		game.draw_fitted(game.lord_art(lord,team),Rect2(95,y+40,132,170))
		var kinds: Array = [game.model.home_cards[team]]+game.model.decks[team].duplicate()
		for i: int in range(kinds.size()): game.draw_card(kinds[i],deck_rect(team,i))
		game.label_at(Vector2(275,y+241),"常駐牌",16)
	game.label_at(Vector2(95,750),"牌組構成依本局實際配置顯示；輪轉順序會隨出牌改變。",19)
