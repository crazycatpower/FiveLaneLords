extends RefCounted
# T10 first-match tutorial. Each step waits for one battle event; the enemy AI stays idle until the
# last step. The game makes sure the card a step needs is in the player's hand.
const DECK := ["farmer","militia","tower","fire","rain","knight","scarecrow","hunter"]
const STEPS := [
	{"card":"farm","text":"把常駐的「農田」拖到我方左側三欄的空格，等它產出第一筆金幣。","done":"ink"},
	{"card":"farmer","text":"在農田的「後方」（同一路更左邊）派出農民，看他停下來耕地。","done":"cultivate"},
	{"card":"militia","text":"派出民兵隊：部隊只會往前走，一路打到敵方城門。","done":"play_militia"},
	{"card":"tower","text":"在我方部署區蓋一座箭樓，守住城門。部隊不會回頭，防守靠建築和領主。","done":"play_tower"},
	{"card":"fire","text":"對準右側藍方的練習農田丟出火罐，燒掉它。","done":"burn"},
	{"card":"","text":"按 Q 或點右下方技能按鈕，發動領主技能。已備好金幣，看看五路出現的援軍！","done":"skill"},
	{"card":"knight","text":"第 III 路的藍方城門快倒了：派騎士去打破它，破門後那一路部署區會往前延伸。","done":"breach"},
]
var stage := 0
var complete := false

func current() -> Dictionary:
	return {} if complete else STEPS[stage]

func caption() -> String:
	if complete: return "教學完成！藍方開始認真進攻了。記住：城門破了，敵兵走進家就輸。"
	return "教學 %d / %d：%s" % [stage+1,STEPS.size(),STEPS[stage].text]

# Returns true when this batch of events finished the current step.
func observe(events: Array) -> bool:
	if complete: return false
	var goal: String = STEPS[stage].done
	for e: Dictionary in events:
		if e.team != 0 and goal != "burn": continue
		var hit := false
		match goal:
			"ink": hit = e.kind == "ink"
			"cultivate": hit = e.kind == "cultivate"
			"play_militia": hit = e.kind == "play" and e.get("card","") == "militia"
			"play_tower": hit = e.kind == "play" and e.get("card","") == "tower"
			"burn": hit = e.kind == "burn" and e.team == 1
			"skill": hit = e.kind == "skill"
			"breach": hit = e.kind == "breach" and e.team == 0
		if hit:
			stage += 1
			complete = stage >= STEPS.size()
			return true
	return false
