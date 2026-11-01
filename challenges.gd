extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Battle = preload("res://battle.gd")
const DATA := [
 {"name":"第五聲鼓","story":"箭樓的燈還亮著。這次，你要等到所有人回來。","goal":"守住 90 秒，不讓敵兵入城。","lord":"iron","limit":90.0,"deck":["shieldguard","hunter","tower","healer","militia","rain","farmer","drummer"],"waves":[[10,0,"militia",2],[25,2,"militia",3],[40,4,"hunter",2],[55,0,"knight",1],[65,2,"militia",3]]},
 {"name":"故鄉木橋","story":"攻城槌上的刻痕還在。城門另一邊，也有人認得。","goal":"180 秒內從第 III 路入城；敵軍入城則失敗。","lord":"lion","limit":180.0,"deck":["ram","shieldguard","healer","hunter","farmer","rain","drummer","militia"],"waves":[[15,2,"militia",2],[45,2,"shieldguard",2],[75,2,"hunter",2],[105,2,"militia",3]]},
 {"name":"名冊錯字","story":"墓園開始收帳了。先備好金幣，再核對回來的是誰。","goal":"180 秒內累計產出 60 金幣，施放亡者大軍一次。","lord":"underworld","limit":180.0,"deck":["skeleton","bonewall","necromancer","curse","hunter","plague","shieldguard","drummer"],"waves":[[20,1,"militia",2],[45,3,"militia",2],[80,2,"hunter",2],[115,1,"knight",1]]}
]
var index := -1
var next_wave := 0
var outcome := ""
func start(game, choice: int) -> void:
	index = choice
	next_wave = 0
	outcome = ""
	var d: Dictionary = DATA[index]
	game.spectating = false
	game.tutorial = null
	game.model = Battle.new(7300+choice,d.deck.duplicate(),B.PRESETS[0].duplicate(),d.lord,"iron")
	game.model.ai_enabled = [false,false]
	game.model.difficulty = 0
	game.model.lord_active[1] = false
	game.model.invasion_victory[0] = index == 1
	if index == 1:
		game.model.add_building(1,Vector2i(7,2),"tower")
	game.enter_battle(d.goal)
func update(game) -> void:
	if index < 0 or game.model.paused or not outcome.is_empty(): return
	var m = game.model
	var d: Dictionary = DATA[index]
	if m.ended:
		var correct: bool = m.winner == 0
		if index == 1: correct = correct and game.review.break_lane == 2
		outcome = "挑戰完成" if correct else "挑戰失敗"
		if not correct: m.winner = 1
		return
	while next_wave < d.waves.size() and m.elapsed >= d.waves[next_wave][0]:
		var wave: Array = d.waves[next_wave]
		for i: int in range(wave[3]): m.spawn_unit(1,wave[1],wave[2],L.cell_center(Vector2i(6,wave[1]))+Vector2(i*18,0))
		next_wave += 1
	var complete: bool = index == 0 and m.elapsed >= d.limit
	if index == 2: complete = m.stats[0].produced >= 60 and m.stats[0].get("skills",0) >= 1
	if complete:
		outcome = "挑戰完成"
		m.finish(0)
	elif m.elapsed >= d.limit:
		outcome = "挑戰失敗：時間用盡"
		m.finish(1)
	game.notice = "%s · %s　剩餘 %d 秒" % [d.name,d.goal,maxi(0,ceili(d.limit-m.elapsed))]
