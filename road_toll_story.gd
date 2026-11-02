extends RefCounted
const LORD = preload("res://assets/manuscript-v1/adventure-lord.png")
const MOB = preload("res://assets/manuscript-v1/mob.png")
const GUARD = preload("res://assets/manuscript-v1/shieldguard.png")
const BANDIT = preload("res://assets/manuscript-v1/bandit.png")
const KNIGHT = preload("res://assets/manuscript-v1/knight.png")
var lines: Array = []
var step := 0
var victory := false

func begin(g, won: bool = false) -> void:
	victory = won
	step = 0
	if won:
		lines = [
			["村民","箭樓下的糧倉開了。這些糧袋……每一袋都有村子的記號。","mob","guard"],
			["村民","這袋麥穗記號，是我們的糧……\n可收糧的人，明明說是送去賑災。","mob","lord"],
			["俘虜","我們只管扣糧。每隔五天，有人在東邊的木橋接貨。","guard","lord"],
			["領主","把糧還給村民。\n下一站，木橋。","lord","mob"],
		]
	else:
		lines = [
			["村民","春天收過田稅，收成又收糧稅。\n現在走自己的路，還得再交一次錢。","mob","guard"],
			["守軍","奉東境領主之命，糧食不得出境。\n交糧，或者回去。","guard","mob"],
			["領主","回去之後，他們吃什麼？","lord","guard"],
			["守軍","那不在我的命令裡。","guard","lord"],
			["村民","大人，我們沒摸過劍。\n但這條路，我們走了一輩子。","mob","lord"],
		]
		if g.adventure.recruit == "bandit":
			lines.append_array([
				["強盜","我們當初也是在這裡，被叫回去的。","bandit","lord"],
				["領主","所以你們就去搶別人的糧？","lord","bandit"],
				["強盜","……所以這次，我們走前面。","bandit","lord"],
			])
		elif g.adventure.recruit == "knight":
			lines.append_array([
				["騎士","路稅應當有領主印令。拿出來。","knight","guard"],
				["守軍","您認得這面旗，還需要看印令？","guard","knight"],
				["騎士","……大人，讓村民退到我身後。","knight","lord"],
			])
		lines.append(["乾草叉暴民加入隊伍","村民舉起乾草叉，站到了你的旗幟下。\n從中路部署乾草叉暴民，便能同時向三路進軍。突破箭樓防線，攻入敵方底線。","mob","lord"])
	show(g)

func advance(g) -> void:
	if g.screen != "road_toll_story": return
	step += 1
	if step < lines.size(): show(g)
	elif victory: g.show_adventure()
	else: g.enter_battle(g.adventure.STAGES[1].goal)

func show(g) -> void:
	g.screen = "road_toll_story"
	g.clear_ui()
	var line: Array = lines[step]
	g.library.text_box(Rect2(115,610,1370,48),line[0],30)
	var text = g.library.text_box(Rect2(115,666,1370,100),line[1],26)
	text.scroll_active = false
	var caption := "繼續"
	if step == lines.size()-1: caption = "前往木橋" if victory else "開始戰鬥"
	g.title_button(Rect2(1200,784,280,54),caption,func(): advance(g),true).grab_focus()
	g.queue_redraw()

func texture(kind: String) -> Texture2D:
	return {"mob":MOB,"guard":GUARD,"lord":LORD,"bandit":BANDIT,"knight":KNIGHT}[kind]

func paint(g) -> void:
	g.draw_rect(Rect2(28,28,1544,844),Color(0.18,0.15,0.10,0.18))
	g.label_at(Vector2(80,85),"1-2 · 東邊的路稅",36)
	g.label_at(Vector2(80,123),"糧袋上的記號" if victory else "三條農路，三座箭樓。",22)
	var line: Array = lines[step]
	var actor: Texture2D = texture(line[2])
	var other: Texture2D = texture(line[3])
	var rect: Rect2 = g.fitted_rect(actor.get_size(),Rect2(125,150,600,430),true)
	if line[2] == "bandit": g.draw_mirrored(actor,rect)
	else: g.draw_texture_rect(actor,rect,false)
	var right: Rect2 = g.fitted_rect(other.get_size(),Rect2(875,135,600,445),true)
	if line[3] != "bandit": g.draw_set_transform(Vector2(right.position.x*2+right.size.x,0),0,Vector2(-1,1))
	g.draw_texture_rect(other,right,false,Color(0.65,0.62,0.56,0.8))
	g.draw_set_transform(Vector2.ZERO)
	g.panel(Rect2(80,590,1440,270),Color("eddfbc"))
	g.draw_line(Vector2(110,655),Vector2(1490,655),Color("ad8b50"),2)
	g.label_at(Vector2(115,819),"%d / %d" % [step+1,lines.size()],20)
