extends RefCounted
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
var log: Array[String] = []
var breakthrough := ""
var break_lane := -1
func clear() -> void:
	log.clear()
	breakthrough = ""
	break_lane = -1
func observe(model) -> void:
	for e: Dictionary in model.events:
		var message := ""
		var side: String = ["紅方","藍方"][e.team] if e.team in [0,1] else ""
		if e.kind == "breach": message = "%s打破第 %d 路城門" % [side,e.lane+1]
		if e.kind == "skill": message = "%s施放%s" % [side,B.LORDS[e.lord].skill]
		if e.kind == "invaded":
			message = "%s的%s從第 %d 路突破" % [side,B.CARDS.get(e.get("unit_kind",""),{}).get("name","部隊"),e.lane+1]
			breakthrough = message
			break_lane = e.lane
		if not message.is_empty():
			log.append("%02d:%02d　%s" % [int(model.elapsed)/60,int(model.elapsed)%60,message])
			if log.size() > 200: log.pop_front()
static func pressure(model, team: int, lane: int) -> int:
	var nearby := false
	for u: Dictionary in model.units:
		if u.hp <= 0 or u.team == team or u.lane != lane or u.get("spawn_delay",0) > 0: continue
		if (u.pos.x < L.GRID_ORIGIN.x+L.CELL_SIZE.x*2 if team == 0 else u.pos.x > L.GRID_ORIGIN.x+L.GRID_SIZE.x-L.CELL_SIZE.x*2): nearby = true
	if nearby: return 2 if model.gates[team][lane] <= 0 else 1
	return 0
func draw_pressure(game) -> void:
	for lane: int in range(5):
		var counts := [0,0]
		for u: Dictionary in game.model.units:
			if u.hp > 0 and u.lane == lane and u.get("spawn_delay",0) <= 0: counts[u.team] += 1
		if counts[0]+counts[1] >= 8:
			var y: float = L.GRID_ORIGIN.y+lane*L.CELL_SIZE.y+22
			game.label_at(Vector2(690,y),"紅 %d · 藍 %d" % [counts[0],counts[1]],15,Color("463529"))
	for team: int in range(2):
		for lane: int in range(5):
			var level := pressure(game.model,team,lane)
			if level == 0: continue
			var y: float = L.GRID_ORIGIN.y+lane*L.CELL_SIZE.y
			var x := L.GRID_ORIGIN.x+6 if team == 0 else L.GRID_ORIGIN.x+L.GRID_SIZE.x-84
			var color := Color("a73b2d") if level == 2 else Color("936b25")
			game.panel(Rect2(x,y+5,78,24),Color("f3dfaf"),color)
			game.draw_string(game.font,Vector2(x,y+22),"即將突破" if level == 2 else "敵軍逼近",HORIZONTAL_ALIGNMENT_CENTER,78,15,color)
func report(model) -> String:
	var result := "突破紀錄："+(breakthrough if not breakthrough.is_empty() else "本局沒有部隊入城紀錄。")+"\n\n"
	for team: int in range(2):
		var s: Dictionary = model.stats[team]
		result += "%s：產出 %d 金幣 · 滿額溢出 %d · 出牌 %d 次 · 技能 %d 次\n" % [["紅方","藍方"][team],s.produced,s.wasted,s.plays,s.get("skills",0)]
	result += "\n下局可嘗試："
	if model.stats[0].wasted >= 10: result += "金幣接近上限時提早部署，減少產出溢出。"
	elif model.winner == 1: result += "先查看突破路線，在敵兵抵達殘垣前補兵；破門後仍有回防機會。"
	else: result += "比較兩軍技能時機，看看能否在進攻前保留足夠金幣。"
	result += "\n\n關鍵事件（依時間，最多保留最近 200 筆）\n"
	return result+("\n".join(log) if not log.is_empty() else "沒有記錄到破門、技能或突破事件。")
