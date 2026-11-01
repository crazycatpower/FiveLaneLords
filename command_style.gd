extends RefCounted
static func card_tint(type: String) -> Color:
	return {"unit":Color("efbd9d"),"building":Color("b7d3aa"),"spell":Color("b5bfec")}.get(type,Color.WHITE)
static func stone(g, r: Rect2) -> void:
	g.draw_rect(r,Color("8c785c"))
	var inner := r.grow(-5)
	for row: int in range(4):
		var y := inner.position.y+row*45
		for col: int in range(12):
			var x := inner.position.x+col*149-(74 if row%2 else 0)
			var tile := Rect2(x+2,y+2,145,41).intersection(inner)
			if not tile.has_area(): continue
			var variation := float((row*7+col*3)%5)*0.012
			g.draw_rect(tile,Color(0.73+variation,0.66+variation,0.53+variation))
			g.draw_line(tile.position,tile.position+Vector2(tile.size.x,0),Color(0.91,0.83,0.67,0.5),1)
			g.draw_line(tile.position,tile.position+Vector2(0,tile.size.y),Color(0.91,0.83,0.67,0.4),1)
	# A quiet wash keeps small HUD text readable over mortar joints.
	g.draw_rect(inner,Color(0.80,0.73,0.60,0.58))
	for i: int in range(180):
		var point := inner.position+Vector2(fmod(i*83.7,inner.size.x),fmod(i*31.3,inner.size.y))
		g.draw_line(point,point+Vector2(2+(i%3),0.5),Color(0.38,0.30,0.21,0.10),1)
	g.draw_rect(r,Color("756247"),false,3)
	g.draw_rect(r.grow(-3),Color("d9c6a0"),false,1)
