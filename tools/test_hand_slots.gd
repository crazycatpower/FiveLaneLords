extends SceneTree
const B = preload("res://balance.gd")
const M = preload("res://battle.gd")
const L = preload("res://layout.gd")
func _initialize():
	for team in range(2):
		for slot in range(4):
			var m = M.new(3)
			m.decks[team] = ["militia","hunter","shieldguard","skeleton","knight","farmer","rain","tower"]
			m.hand_cd[team] = [1.0,2.0,3.0,4.0]
			m.hand_cd[team][slot] = 0
			m.ink[team] = 50
			var before = m.decks[team].duplicate()
			var cds = m.hand_cd[team].duplicate()
			assert(m.play(team,slot,L.cell_center(Vector2i(0 if team == 0 else 8,2))))
			for other in range(4):
				if other == slot: continue
				assert(m.decks[team][other] == before[other])
				assert(m.hand_cd[team][other] == cds[other])
			assert(m.decks[team][slot] == before[4])
			assert(m.hand_cd[team][slot] == B.CARDS[before[4]].cooldown)
			assert(m.decks[team].slice(4) == [before[5],before[6],before[7],before[slot]])
	var style = preload("res://command_style.gd")
	for kind in B.CARDS: assert(style.TINTS.has(B.card_faction(kind)),"card background by faction: "+kind)
	print("Fixed slots, cooldowns, queue order and faction card colours: PASS")
	quit()
