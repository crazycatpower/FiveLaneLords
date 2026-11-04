extends RefCounted
const B = preload("res://balance.gd")
static func draw(g) -> void:
	var m = g.model
	var muted := Color("5a5040")
	# A parchment plate under the purse and its text, so the stone joints never run through letters.
	g.panel(PLATE,Color(0.92,0.86,0.72,0.92),Color("8a6f4a"))
	# No help or notice text here any more (producer 2026-11-03): the panel is the purse.
	var focus: int = g.selected if g.selected >= 0 else g.hover_slot
	var need: float = B.CARDS[m.kind_at(0,focus)].cost if focus >= 0 and not g.spectating else 0.0
	if not g.spectating and focus < 0 and g.SKILL_RECT.has_point(g.get_global_mouse_position()): need = B.skill_cost(m.lords[0].lord)
	if g.purse_alarm > 0: need = maxf(need,g.purse_need) # a refused play shows what it wanted
	draw_purse(g,m.ink[0],need,m.get_instance_id(),g.purse_alarm,m.ink[0] >= B.MAX_INK-0.01)
	var home: String = m.home_cards[0]
	g.label_at(Vector2(232,756),"金幣",18,muted)
	g.label_at(Vector2(230,806),str(int(m.ink[0])),50,g.INK)
	g.label_at(Vector2(232+g.font.get_string_size(str(int(m.ink[0])),HORIZONTAL_ALIGNMENT_LEFT,-1,50).x+6,805),"/ %d" % B.MAX_INK,20,muted)
	g.draw_line(Vector2(232,818),Vector2(388,818),Color("b69b6f"),1)
	g.label_at(Vector2(232,842),"每秒 +%.1f" % m.production_rate(0),18,muted)
	g.label_at(Vector2(232,866),"%s %d" % [B.CARDS[home].name,m.count_buildings(0,home)],18,muted)

# Gold purse (producer 2026-11-03): every 2 gold is one coin that drops onto the heap in front of the
# money bag. Hovering or selecting a card whitens the coins it would spend (the top of the heap);
# coins it still lacks show as pale outlines. No numbers on the purse itself.
const ART = preload("res://manuscript_art.gd")
const PLATE := Rect2(40,712,362,166)
const COIN_GOLD := 2.0
const COIN := 24.0 # drawn coin size
const ROWS := [7,6,5,4,3] # bottom row first: a pyramid of 25 coins = 50 gold
const PURSE := Rect2(48,706,166,166) # money bag art
const HEAP_X := 131.0
const HEAP_BOTTOM := 872.0
const DROP_MS := 420.0
static var shown := 0 # coins already landed or falling
static var drops := {} # coin index -> start time (ms) of its fall
static var model_id := 0

static func coin_texture() -> AtlasTexture:
	return ART.region("small-objects",Rect2(360,182,114,114))

static func coin_slot(i: int) -> Vector2:
	var row := 0
	var first := 0
	while row < ROWS.size()-1 and i >= first+ROWS[row]:
		first += ROWS[row]
		row += 1
	var n: int = ROWS[row]
	# A row fills from the middle outwards, so a part-filled row still sits centred on the heap.
	var mid := (n-1)/2.0
	var cols: Array = range(n)
	cols.sort_custom(func(a: int, b: int) -> bool: return absf(a-mid) < absf(b-mid) or (is_equal_approx(absf(a-mid),absf(b-mid)) and a < b))
	return Vector2(HEAP_X+(cols[i-first]-mid)*COIN*0.86,HEAP_BOTTOM-COIN*0.5-row*COIN*0.5)

# alarm > 0: a refused play — the missing coins flash red and the heap shakes.
# full: the purse is at the cap — it glows and the top coin keeps hopping (gold is going to waste).
static func draw_purse(g, ink: float, need: float, id: int, alarm: float = 0.0, full: bool = false) -> void:
	var total := 0
	for n: int in ROWS: total += n
	var coins := clampi(floori(ink/COIN_GOLD),0,total)
	var now := float(Time.get_ticks_msec())
	if id != model_id:
		model_id = id
		shown = 0
		drops.clear()
	if coins > shown:
		for i: int in range(shown,coins): drops[i] = now+(i-shown)*70.0
	elif coins < shown:
		for i: int in drops.keys():
			if i >= coins: drops.erase(i)
	shown = coins
	var shadow := PackedVector2Array()
	for i: int in range(24): shadow.append(Vector2(HEAP_X+cos(i*TAU/24)*82,HEAP_BOTTOM-3+sin(i*TAU/24)*7))
	g.draw_colored_polygon(shadow,Color(0.25,0.18,0.08,0.22)) # ground shadow under bag and heap
	var t := now/1000.0
	var shake := Vector2(sin(alarm*60)*4*clampf(alarm/0.9,0,1),0)
	if full:
		var glow := 0.5+0.5*sin(t*5)
		g.draw_set_transform(Vector2(HEAP_X,HEAP_BOTTOM-40),0,Vector2(1,0.8))
		g.draw_circle(Vector2.ZERO,92+glow*8,Color(1.0,0.82,0.30,0.18+0.14*glow))
		g.draw_set_transform(Vector2.ZERO)
	g.draw_texture_rect(ART.object_icon(0),PURSE,false)
	var tex := coin_texture()
	var spend := ceili(need/COIN_GOLD)
	for i: int in range(maxi(coins,mini(spend,total))):
		var slot := coin_slot(i)+shake
		var lit := spend > 0 and i >= coins-spend
		if i >= coins:
			var missing := Color(0.85,0.15,0.10,0.6+0.4*sin(alarm*30)) if alarm > 0 else Color(1,0.98,0.9,0.85)
			g.draw_arc(slot,COIN*0.45,0,TAU,18,missing,2.0 if alarm > 0 else 1.6,true) # still missing
			continue
		if full and i == coins-1: slot.y -= absf(sin(t*6))*9 # the top coin hops: the purse is full
		if drops.has(i):
			var k: float = (now-drops[i])/DROP_MS
			if k < 0: continue
			if k < 1: slot = Vector2(HEAP_X+10,PURSE.position.y-6).lerp(slot,k*k) # falls in from above
			else: drops.erase(i)
		if lit: g.draw_circle(slot,COIN*0.62,Color(1,1,0.94,0.5))
		g.draw_texture_rect(tex,Rect2(slot-Vector2(COIN,COIN)/2,Vector2(COIN,COIN)),false)
		if lit: g.draw_circle(slot,COIN*0.42,Color(1,1,0.97,0.72))
