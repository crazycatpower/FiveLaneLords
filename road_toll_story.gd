extends RefCounted
const LORD = preload("res://assets/manuscript-v1/adventure-lord.png")
const MOB = preload("res://assets/manuscript-v1/mob.png")
const GUARD = preload("res://assets/manuscript-v1/militia-red.png")
const BANDIT = preload("res://assets/manuscript-v1/bandit.png")
const KNIGHT = preload("res://assets/manuscript-v1/knight.png")
const HUNTER = preload("res://assets/manuscript-v1/hunter.png")
const LION = preload("res://assets/manuscript-v1/lord-lion.png")

const HARVEST = preload("res://assets/manuscript-v1/lord-harvest.png")
const IRON = preload("res://assets/manuscript-v1/lord-iron.png")
const UNDERWORLD = preload("res://assets/manuscript-v1/lord-underworld.png")
const SKELETON = preload("res://assets/manuscript-v1/skeleton.png")
const NECROMANCER = preload("res://assets/manuscript-v1/necromancer.png")

var lines: Array = []
var step := 0
var victory := false
var heading := ""
var opening_caption := ""
var victory_caption := ""
var next_caption := ""

func begin(g, won: bool = false) -> void:
	victory = won
	step = 0
	var idx: int = g.adventure.index
	var recruit: String = g.adventure.recruit
	setup_stage_story(idx, recruit, won)
	show(g)

func setup_stage_story(idx: int, recruit: String, won: bool) -> void:
	var adventure_data = preload("res://campaign_catalog.gd")
	var stage: Dictionary = adventure_data.STAGES[idx]
	heading = "第 %d 關 · %s" % [idx+1,stage.name]
	opening_caption = "決戰亡靈領主" if idx == adventure_data.STAGES.size()-1 else ["戰亂與重稅","亡靈與勾結","三位領主的援軍"][stage.chapter]
	victory_caption = "戰後 · "+stage.name
	next_caption = "返回冒險地圖" if idx == adventure_data.STAGES.size()-1 else "前往下一關"
	lines = preload("res://campaign_story_data.gd").dialogue(stage.id,recruit,won)
	if won:
		var rewards: Array = stage.rewards
		if not rewards.is_empty():
			var names: Array = rewards.map(func(k): return preload("res://balance.gd").CARDS[k].name)
			lines.append(["卡牌解鎖","已解鎖："+"、".join(names)+"。\n可在冒險牌組中選用。",stage.get("support_lord","lord"),"lord"])

func advance(g) -> void:
	if g.screen != "road_toll_story": return
	step += 1
	if step < lines.size(): show(g)
	elif victory: g.show_adventure()
	else: g.enter_battle(g.adventure.STAGES[g.adventure.index].goal)

func show(g) -> void:
	g.screen = "road_toll_story"
	g.clear_ui()
	var line: Array = lines[step]
	g.library.text_box(Rect2(115,610,1370,48),line[0],30)
	var text = g.library.text_box(Rect2(115,666,1370,100),line[1],26)
	text.scroll_active = false
	var caption := "繼續"
	if step == lines.size()-1: caption = next_caption if victory else "開始戰鬥"
	g.title_button(Rect2(1200,784,280,54),caption,func(): advance(g),true).grab_focus()
	g.queue_redraw()

func texture(kind: String) -> Texture2D:
	return {"mob":MOB,"guard":GUARD,"lord":LORD,"bandit":BANDIT,"knight":KNIGHT,"hunter":HUNTER,"lion":LION,"harvest":HARVEST,"iron":IRON,"underworld":UNDERWORLD,"skeleton":SKELETON,"necromancer":NECROMANCER}.get(kind, GUARD)

func paint(g) -> void:
	g.draw_rect(Rect2(28,28,1544,844),Color(0.18,0.15,0.10,0.18))
	g.label_at(Vector2(80,85),heading,36)
	g.label_at(Vector2(80,123),victory_caption if victory else opening_caption,22)
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
