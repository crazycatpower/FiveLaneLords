extends RefCounted
# Scene-shaped controls reuse manuscript art; all labels remain real, focusable UI.
static func build(g) -> void:
	g.adventure.load_progress()
	entry(g,Rect2(955,250,480,96),"冒險模式",g.show_adventure,36)
	entry(g,Rect2(955,416,480,82),"自由對戰",func(): g.spectating = false; g.start_battle(),29)
	entry(g,Rect2(955,545,480,82),"觀戰模式",g.show_watch,29)
	entry(g,Rect2(100,720,280,85),"牌組編成",g.show_deck,28)
	entry(g,Rect2(448,720,280,85),"卡牌圖鑑",func(): g.library.open(),28)
	g.title_button(Rect2(1085,190,230,42),"對戰難度："+["簡單","普通","困難"][g.difficulty],func(): g.difficulty = (g.difficulty+1)%3; g.show_title())
	g.title_button(Rect2(941,757,170,48),"操作說明",g.show_help)
	g.title_button(Rect2(1127,757,150,48),"設定",g.show_settings)
	g.title_button(Rect2(1293,757,150,48),"離開",func(): g.get_tree().quit())
static func entry(g, r: Rect2, caption: String, action: Callable, size: int) -> void:
	var b: Button = g.title_button(r,caption,action)
	b.add_theme_font_size_override("font_size",size)
	for state: String in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1,0.88,0.57,0.14) if state == "hover" else Color(0,0,0,0.12) if state == "pressed" else Color.TRANSPARENT
		if state == "focus":
			style.border_color = Color("f4d78c")
			style.set_border_width_all(2)
		b.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		b.add_theme_color_override(state,Color("fff0ca"))
static func polygon(g, points: PackedVector2Array, color: Color) -> void:
	g.draw_colored_polygon(points,color)
	var edge := points.duplicate()
	edge.append(points[0])
	g.draw_polyline(edge,Color("5e4932"),2.5,true)
static func banner(g, y: float, height: float, color: Color, subtitle: String) -> void:
	polygon(g,PackedVector2Array([Vector2(927,y+9),Vector2(1480,y+9),Vector2(1461,y+height/2),Vector2(1480,y+height),Vector2(927,y+height),Vector2(946,y+height/2)]),Color(0.15,0.12,0.08,0.2))
	polygon(g,PackedVector2Array([Vector2(917,y),Vector2(1470,y),Vector2(1451,y+height/2),Vector2(1470,y+height),Vector2(917,y+height),Vector2(936,y+height/2)]),color)
	g.draw_texture_rect(g.PAPER,Rect2(940,y+3,500,height-6),false,Color(1,1,1,0.09))
	g.draw_line(Vector2(950,y+8),Vector2(1434,y+8),Color("d5b16e"),1.5)
	g.draw_line(Vector2(950,y+height-8),Vector2(1434,y+height-8),Color("d5b16e"),1.5)
	g.draw_string(g.font,Vector2(955,y+height-24),subtitle,HORIZONTAL_ALIGNMENT_CENTER,480,18,Color("e5cda1"))
# Nine wax seals across the adventure banner: red for cleared, gold ring on the next stage.
static func adventure_progress(g, y: float) -> void:
	var a = g.adventure
	var count: int = a.STAGES.size()
	var next: int = a.frontier()
	var done: int = a.cleared_count()
	var line := "全部通過！可以再次挑戰" if done == count else "下一關：第 %d 關「%s」" % [next+1,a.STAGES[next].name]
	g.draw_string(g.font,Vector2(955,y+106),line,HORIZONTAL_ALIGNMENT_CENTER,480,18,Color("f1dcb0"))
	for i: int in range(count):
		var p := Vector2(1195+(i-(count-1)/2.0)*40,y+131)
		if i == next and done < count: g.draw_circle(p,13,Color("f4d78c"))
		g.draw_circle(p,10,Color("6e2a20") if a.is_cleared(i) else Color(0.95,0.88,0.7,0.35))
		g.draw_arc(p,10,0,TAU,20,Color("e5cda1"),1.5,true)
static func book(g, x: float, caption: String) -> void:
	polygon(g,PackedVector2Array([Vector2(x,700),Vector2(x+286,689),Vector2(x+308,814),Vector2(x+14,828)]),Color("694535"))
	polygon(g,PackedVector2Array([Vector2(x+10,695),Vector2(x+282,685),Vector2(x+299,804),Vector2(x+21,817)]),Color("c5ad7a"))
	polygon(g,PackedVector2Array([Vector2(x,681),Vector2(x+286,674),Vector2(x+302,793),Vector2(x+14,808)]),Color("714838") if x < 300 else Color("39565a"))
	g.draw_line(Vector2(x+29,686),Vector2(x+43,800),Color("d4b36f"),3)
	g.draw_fitted(g.ART.ornament(4),Rect2(x+72,775,160,20),Color(1,0.88,0.62,0.6))
	g.draw_string(g.font,Vector2(x+42,714),caption,HORIZONTAL_ALIGNMENT_CENTER,225,16,Color("dec79b"))
static func paint(g) -> void:
	g.draw_fitted(g.ART.ornament(4),Rect2(90,48,660,55))
	g.draw_string(g.font,Vector2(85,184),"羊皮紙戰記",HORIZONTAL_ALIGNMENT_CENTER,680,78,g.INK)
	g.draw_string(g.font,Vector2(85,232),"種下村莊，寫下你的戰史。",HORIZONTAL_ALIGNMENT_CENTER,680,24,g.INK)
	# A dirt track separates the living fields from the graveyard.
	g.draw_colored_polygon(PackedVector2Array([Vector2(465,410),Vector2(505,410),Vector2(541,452),Vector2(568,496),Vector2(618,549),Vector2(670,604),Vector2(751,681),Vector2(605,681),Vector2(577,613),Vector2(543,550),Vector2(517,501),Vector2(493,451)]),Color(0.76,0.68,0.46,0.30))
	g.ground_wash(Vector2(240,501),Vector2(180,135),Color("b5b66f"),72,0.13)
	g.ground_wash(Vector2(730,501),Vector2(130,135),Color("655a70"),81,0.16)
	for row: int in range(2):
		var y := 398.0+row*119
		g.draw_fitted(g.art("farm"),Rect2(72,y-32,146,103),Color.WHITE,true)
		g.draw_fitted(g.art("grave",1),Rect2(758,y-32,89,106),Color.WHITE,true)
		g.title_soldier("hunter",Vector2(262,y+38),0,1.12)
		g.title_soldier("militia",Vector2(366,y+56),0,1.32)
		g.title_soldier("skeleton",Vector2(690,y+38),1,1.22)
		g.title_soldier("ghoul",Vector2(579,y+56),1,1.38)
	g.title_soldier("lord_"+g.player_lord,Vector2(409,649),0,1.55)
	g.title_soldier("reaper",Vector2(596,649),1,1.55)
	# Banners hang from one campaign standard, rather than a panel of identical buttons.
	g.draw_line(Vector2(914,151),Vector2(914,705),Color("604831"),9,true)
	g.draw_line(Vector2(914,154),Vector2(1487,154),Color("604831"),8,true)
	g.draw_circle(Vector2(914,143),13,Color("b58a43"))
	g.draw_circle(Vector2(1487,154),7,Color("b58a43"))
	g.draw_string(g.font,Vector2(964,125),"五路戰線 · 一卷戰史",HORIZONTAL_ALIGNMENT_CENTER,480,27,g.INK)
	banner(g,240,160,Color("963f30"),"")
	adventure_progress(g,240)
	banner(g,412,118,Color("3b5662"),"用你的牌組對戰 AI")
	banner(g,542,118,Color("696845"),"兩邊都交給 AI，看牌組怎麼打")
	g.draw_string(g.font,Vector2(951,694),"出征領主 · "+g.B.LORDS[g.player_lord].name,HORIZONTAL_ALIGNMENT_CENTER,490,21,g.INK)
	book(g,88,"軍備名冊")
	book(g,436,"萬物與軼聞")
	g.draw_string(g.font,Vector2(90,860),"農田與墓碑之間，戰線已然展開。",HORIZONTAL_ALIGNMENT_CENTER,660,19,g.INK)
