extends RefCounted
const B = preload("res://balance.gd")
static func draw(g) -> void:
	var m = g.model
	var muted := Color("414b48")
	if g.adventure.index >= 0:
		var d: Dictionary = g.adventure.STAGES[g.adventure.index]
		g.label_at(Vector2(50,727),d.name,20,g.INK)
		var limit: float = d.get("limit",0.0)
		if limit > 0:
			var left := maxi(0,ceili(limit-m.elapsed))
			g.panel(Rect2(289,708,103,27),Color("e4d2ab"))
			g.draw_string(g.font,Vector2(289,728),"%02d:%02d" % [left/60,left%60],HORIZONTAL_ALIGNMENT_CENTER,103,20,g.RED if left <= 20 else g.INK)
		var objective: String = d.goal
		if d.kind == "economy":
			objective = "累計產出 %d / %d 金幣" % [mini(int(m.stats[0].produced),int(d.gold)),d.gold]
			if d.skills > 0: objective += " · 技能 %d / %d" % [mini(m.stats[0].get("skills",0),d.skills),d.skills]
		wrapped(g,objective,Vector2(50,752),342,16,muted)
	else:
		wrapped(g,g.notice,Vector2(50,725),342,16,muted)
	g.draw_line(Vector2(50,773),Vector2(392,773),Color("b69b6f"),1)
	g.draw_texture_rect(g.ART.object_icon(0),Rect2(51,784,31,34),false)
	g.label_at(Vector2(91,811),"金幣",20,muted)
	g.label_at(Vector2(144,812),str(int(m.ink[0])),32,g.INK)
	g.label_at(Vector2(207,810),"/ %d" % B.MAX_INK,20,muted)
	var focus: int = g.selected if g.selected >= 0 else g.hover_slot
	var need: float = B.CARDS[m.kind_at(0,focus)].cost if focus >= 0 and not g.spectating else 0.0
	for i: int in range(10):
		var seg := Rect2(52+i*34,827,28,9)
		g.draw_rect(seg,Color("baa780"))
		var fill := clampf((m.ink[0]-i*5)/5.0,0,1)
		if fill > 0: g.draw_rect(Rect2(seg.position,Vector2(seg.size.x*fill,seg.size.y)),Color("b58b2e"))
		if need > i*5: g.draw_rect(seg.grow(2),Color("6b4a14") if m.ink[0] >= need else g.RED,false,1.5)
	var home: String = m.home_cards[0]
	g.label_at(Vector2(52,865),"每秒 +%.1f" % m.production_rate(0),19,muted)
	g.draw_string(g.font,Vector2(232,865),"%s %d" % [B.CARDS[home].name,m.count_buildings(0,home)],HORIZONTAL_ALIGNMENT_RIGHT,156,19,muted)
static func wrapped(g, text: String, at: Vector2, width: float, size: int, color: Color) -> void:
	var line := ""
	var row := 0
	for ch: String in text:
		if g.font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width:
			g.label_at(at+Vector2(0,row*19),line,size,color)
			row += 1
			line = ""
			if row >= 2: return
		line += ch
	g.label_at(at+Vector2(0,row*19),line,size,color)
