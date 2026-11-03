extends RefCounted
const ROLES := {
 "economy":["crystal","farm","grave","farmer","mill","harvest"],
 "melee":["militia","mob","knight","shieldguard","corpse_giant","skeleton","ghoul","reaper","ox","ram","spearbow","raven"],
 "ranged":["arcane_tower","hunter","catapult","tower","rain","fire"],
 "support":["artificer","healer","drummer","necromancer","guard"],
 "control":["teleport_trap","blast_trap","barricade","curse","plague","bonewall","scarecrow"]
}
static func card_tint(kind: String) -> Color:
	for role: String in ROLES:
		if kind in ROLES[role]: return {"economy":Color("f3d079"),"melee":Color("e7ac9b"),"ranged":Color("a9cbe6"),"support":Color("b2d5a2"),"control":Color("cbb0df")}[role]
	return Color.WHITE
static func type_frame(g, r: Rect2, type: String) -> void:
	var box := Rect2(r.position+r.size*Vector2(0.09,0.17),r.size*Vector2(0.82,0.48))
	var p := box.position
	var s := box.size
	var ink := Color(0.30,0.25,0.18,0.62)
	if type == "unit":
		# Shield silhouette and diagonal heraldic hatching.
		var points := PackedVector2Array([p,p+Vector2(s.x,0),p+Vector2(s.x,s.y*0.72),p+Vector2(s.x*0.5,s.y),p+Vector2(0,s.y*0.72),p])
		g.draw_polyline(points,ink,1.5,true)
		for i: int in range(4):
			g.draw_line(p+Vector2(3+i*5,3),p+Vector2(3,3+i*5),Color(ink,0.35),1)
	elif type == "building":
		# Square masonry with a crenellated top.
		g.draw_rect(box,ink,false,1.5)
		for i: int in range(5):
			g.draw_rect(Rect2(p+Vector2(i*s.x/5,-5),Vector2(s.x/10,5)),ink,false,1.2)
		for i: int in range(3):
			g.draw_line(p+Vector2(0,12+i*13),p+Vector2(9,12+i*13),Color(ink,0.45),1)
	else:
		# Oval seal with orbiting diamond marks.
		g.draw_set_transform(box.get_center(),0,Vector2(1,s.y/s.x))
		g.draw_arc(Vector2.ZERO,s.x*0.5,0,TAU,48,ink,1.5,true)
		g.draw_set_transform(Vector2.ZERO)
		for side: int in [-1,1]:
			var c := box.get_center()+Vector2(side*s.x*0.5,0)
			g.draw_polyline(PackedVector2Array([c+Vector2(0,-5),c+Vector2(4,0),c+Vector2(0,5),c-Vector2(4,0),c+Vector2(0,-5)]),ink,1,true)
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
