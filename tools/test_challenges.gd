extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	var saved: String = JSON.stringify(g.player_deck)
	for i: int in range(3):
		g.challenge.start(g,i)
		check(g.DeckStore.valid(g.model.decks[0],g.model.lords[0].lord),"valid challenge deck")
		check(g.model.ai_enabled == [false,false],"only scripted opposition")
		g.model.elapsed = 30
		g.challenge.update(g)
		var count: int = g.model.units.size()
		g.challenge.update(g)
		check(count == g.model.units.size(),"waves do not repeat at same time")
		g.model.paused = true
		g.model.elapsed = 90
		var wave: int = g.challenge.next_wave
		g.challenge.update(g)
		check(g.challenge.next_wave == wave,"paused challenges do not deploy waves")
		g.restart()
		check(g.challenge.index == i and g.model.elapsed == 0 and g.challenge.next_wave == 0,"restart resets same challenge")
	check(JSON.stringify(g.player_deck) == saved,"challenge never changes saved player deck")
	g.challenge.start(g,0)
	g.model.elapsed = 90
	g.challenge.update(g)
	check(g.model.ended and g.model.winner == 0,"survival success")
	g.challenge.start(g,1)
	g.model.elapsed = 180
	g.challenge.update(g)
	check(g.model.ended and g.model.winner == 1,"breakthrough timeout")
	g.challenge.start(g,1)
	g.model.events.append({"kind":"invaded","team":0,"lane":2,"unit_kind":"militia"})
	g.model.finish(0)
	g.consume_events()
	g.challenge.update(g)
	check(g.challenge.outcome == "挑戰完成" and g.review.break_lane == 2,"correct lane success with invader logged")
	check(g.review.breakthrough.contains(g.B.CARDS.militia.name),"report names actual breakthrough unit")
	g.challenge.start(g,2)
	check(not g.model.invasion_victory[0] and g.model.invasion_victory[1],"objective mode cannot skip economy through early invasion")
	g.model.stats[0].produced = 60
	g.challenge.update(g)
	check(not g.model.ended,"economy alone does not complete necromancy")
	g.model.stats[0].skills = 1
	g.challenge.update(g)
	check(g.model.ended and g.model.winner == 0,"economy plus skill success")
	g.challenge.start(g,0)
	var u: Dictionary = g.model.spawn_unit(1,2,"militia",g.L.cell_center(Vector2i(0,2)))
	check(g.review.pressure(g.model,0,2) == 1,"nearby enemy triggers warning")
	g.model.gates[0][2] = 0
	check(g.review.pressure(g.model,0,2) == 2,"breached gate triggers urgent warning")
	u.hp = 0
	check(g.review.pressure(g.model,0,2) == 0,"dead enemy not counted")
	g.start_tutorial()
	check(g.challenge.index == -1,"tutorial exits challenge state")
	g.free()
	print("Challenge/review checks: %d failures" % failures)
	quit(1 if failures else 0)
