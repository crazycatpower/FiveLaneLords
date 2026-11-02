extends RefCounted
# First victory recruitment scene. Decisions are saved before leaving the scene.
const BANDIT = preload("res://assets/manuscript-v1/bandit.png")
const KNIGHT = preload("res://assets/manuscript-v1/knight.png")
var step := 0
var error := ""

func begin(g) -> void:
	step = 0
	error = ""
	show(g)

func show(g) -> void:
	g.screen = "adventure_ending"
	g.clear_ui()
	var speaker := "強盜頭目"
	var words := "東邊在打仗，領主為了養兵，一次次加重田稅。我們連種糧都交光了。\n可搶你們的糧，是我們的錯。領主大人，若肯收留，我們願為您效力。"
	if step == 1:
		speaker = "騎士"
		words = "不要相信盜賊的話！東邊的重稅是真的，叛逃民兵沿路搶糧也是真的。\n可他們剛傷了您的村民。請讓我為您效力，別把百姓交給他們。"
	elif step == 2:
		speaker = "領主的抉擇"
		words = "收留強盜，讓他們以效力贖罪；或接受騎士效忠。\n只能招募其中一方。"
	elif step == 3:
		var bandit: bool = g.adventure.recruit == "bandit"
		speaker = "強盜歸順" if bandit else "騎士宣誓"
		words = ("領主：欠村民的，用往後的日子償還。再搶百姓的糧，我絕不寬恕。\n強盜：記住了，大人。我帶您走東邊的路。" if bandit else "領主：留下吧。跟我去東邊，看清這場戰亂把人逼成了什麼。\n騎士：以我的劍起誓，我會護住村民。")
	g.library.text_box(Rect2(115,610,1370,48),speaker,30)
	var dialogue = g.library.text_box(Rect2(115,666,1370,100),words,26)
	dialogue.scroll_active = false
	if step < 2:
		g.title_button(Rect2(1200,784,280,54),"繼續",func(): step += 1; show(g),true).grab_focus()
	elif step == 2:
		g.title_button(Rect2(130,782,620,58),"留活口 盜賊加入",func(): choose(g,"bandit"))
		g.title_button(Rect2(850,782,620,58),"一個不留 騎士加入",func(): choose(g,"knight"))
	else:
		g.title_button(Rect2(1200,784,280,54),"前往冒險地圖",g.show_adventure,true).grab_focus()
	if not error.is_empty(): g.library.text_box(Rect2(115,852,1370,30),error,18)
	g.queue_redraw()

func choose(g, kind: String) -> void:
	if step != 2 or not kind in ["bandit","knight"]: return
	if not g.adventure.recruit.is_empty(): return
	var was_cleared: bool = g.adventure.is_cleared(g.adventure.index)
	g.adventure.recruit = kind
	g.adventure.cleared[g.adventure.STAGES[g.adventure.index].id] = true
	if not g.adventure.save_progress():
		g.adventure.recruit = ""
		if not was_cleared: g.adventure.cleared.erase(g.adventure.STAGES[g.adventure.index].id)
		error = "進度儲存失敗，請再試一次。"
		show(g)
		return
	g.adventure.outcome = "第一關通過！獲得："+g.B.CARDS[kind].name
	g.adventure.selected = mini(g.adventure.index+1,g.adventure.STAGES.size()-1)
	step = 3
	error = ""
	show(g)

func portrait(g, texture: Texture2D, box: Rect2, dim: bool) -> void:
	var rect: Rect2 = g.fitted_rect(texture.get_size(),box,true)
	g.draw_set_transform(Vector2(rect.position.x*2+rect.size.x,0),0,Vector2(-1,1))
	g.draw_texture_rect(texture,rect,false,Color(0.60,0.57,0.51,0.75) if dim else Color.WHITE)
	g.draw_set_transform(Vector2.ZERO)

func paint(g) -> void:
	g.draw_rect(Rect2(28,28,1544,844),Color(0.18,0.15,0.10,0.18))
	g.label_at(Vector2(80,85),"第一章 · 戰後抉擇",36)
	g.label_at(Vector2(80,123),"抓到了俘虜，還有個路過的騎士。",22)
	portrait(g,BANDIT,Rect2(125,150,600,430),step == 1 or (step == 3 and g.adventure.recruit == "knight"))
	if step >= 1:
		portrait(g,KNIGHT,Rect2(875,135,600,445),step == 0 or (step == 3 and g.adventure.recruit == "bandit"))
	g.panel(Rect2(80,590,1440,270),Color("eddfbc"))
	g.draw_line(Vector2(110,655),Vector2(1490,655),Color("ad8b50"),2)
