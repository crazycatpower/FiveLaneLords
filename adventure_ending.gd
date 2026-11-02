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
	var words := "領主大人，我們原是東邊的村民。那裡的領主奪了田，收走糧食，還把我們趕出了家。\n我們走投無路才做了強盜……若您肯收留，我們願為領主大人效力。"
	if step == 1:
		speaker = "陌生的騎士"
		words = "領主大人，不要相信盜賊的話！\n他們才剛殺了您的農民。如今落敗，便拿一段身世換取寬恕？讓我為您效力，守住這片土地。"
	elif step == 2:
		speaker = "領主的抉擇"
		words = "東邊究竟發生了什麼，尚無人能證實。眼前的罪行，卻是真實的。\n您要給強盜一次贖罪的機會，還是接受騎士的效忠？只能招募其中一方。"
	elif step == 3:
		var bandit: bool = g.adventure.recruit == "bandit"
		speaker = "強盜歸順" if bandit else "騎士宣誓"
		words = ("領主：你們欠村民的，就用往後的日子償還。若再傷害百姓，我會親自收回這份寬恕。\n強盜：我們記住了，大人。東邊那條路……我們認得。" if bandit else "領主：留下吧。我要你守護村民，也要你查明東邊的真相。\n騎士：以我的劍起誓。只是那位領主的事，請容我日後細說。")
	g.library.text_box(Rect2(115,610,1370,48),speaker,30)
	var dialogue = g.library.text_box(Rect2(115,666,1370,100),words,26)
	dialogue.scroll_active = false
	if step < 2:
		g.title_button(Rect2(1200,784,280,54),"繼續",func(): step += 1; show(g),true).grab_focus()
	elif step == 2:
		g.title_button(Rect2(130,782,620,58),"收留強盜　獲得：強盜（潛行）",func(): choose(g,"bandit"))
		g.title_button(Rect2(850,782,620,58),"接受效忠　獲得：騎士（重裝）",func(): choose(g,"knight"))
	else:
		g.title_button(Rect2(1200,784,280,54),"前往冒險地圖",g.show_adventure,true).grab_focus()
	if not error.is_empty(): g.library.text_box(Rect2(115,852,1370,30),error,18)
	g.queue_redraw()

func choose(g, kind: String) -> void:
	if step != 2 or not kind in ["bandit","knight"]: return
	if not g.adventure.recruit.is_empty(): return
	var was_cleared: bool = g.adventure.is_cleared(0)
	g.adventure.recruit = kind
	g.adventure.cleared[g.adventure.STAGES[0].id] = true
	if not g.adventure.save_progress():
		g.adventure.recruit = ""
		if not was_cleared: g.adventure.cleared.erase(g.adventure.STAGES[0].id)
		error = "進度儲存失敗，請再試一次。"
		show(g)
		return
	g.adventure.outcome = "第一關通過！獲得："+g.B.CARDS[kind].name
	g.adventure.selected = 1
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
	g.label_at(Vector2(80,85),"第一章 · 戰火之後",36)
	g.label_at(Vector2(80,123),"一場勝利，兩份誓言。",22)
	portrait(g,BANDIT,Rect2(125,150,600,430),step == 1 or (step == 3 and g.adventure.recruit == "knight"))
	if step >= 1:
		portrait(g,KNIGHT,Rect2(875,135,600,445),step == 0 or (step == 3 and g.adventure.recruit == "bandit"))
	g.panel(Rect2(80,590,1440,270),Color("eddfbc"))
	g.draw_line(Vector2(110,655),Vector2(1490,655),Color("ad8b50"),2)
