extends SceneTree
const Battle = preload("res://tools/economy_experiment_battle.gd")
const B = preload("res://balance.gd")
const DS = preload("res://deck_store.gd")
const LORDS = ["lion","iron","harvest","adventure","underworld","vampire","mage","rune"]
func _initialize() -> void:
	var options := {"lord":"lion","goal":2,"repeat":0,"out":"","opponents":8,"opponent-picks":""}
	for arg: String in OS.get_cmdline_user_args():
		var key := arg.get_slice("=",0).trim_prefix("--")
		var value := arg.get_slice("=",1)
		if key in ["goal","repeat","opponents"]: options[key] = int(value)
		elif key in ["lord","out","opponent-picks"]: options[key] = value
	var out := FileAccess.open(options.out,FileAccess.WRITE)
	if out == null: quit(2); return
	var own_index: int = LORDS.find(options.lord)
	for opponent_index: int in range(options.opponents):
		var opponent: String = LORDS[opponent_index] if options["opponent-picks"].is_empty() else options["opponent-picks"].split(",")[opponent_index]
		var actual_opponent_index: int = LORDS.find(opponent)
		var seed_value: int = 860000+options.repeat*10000+own_index*100+actual_opponent_index
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var own_deck := DS.random_deck(rng,options.lord)
		var opponent_deck := DS.random_deck(rng,opponent)
		for side: int in [0,1]:
			var picks: Array = [options.lord,opponent] if side == 0 else [opponent,options.lord]
			var decks: Array = [own_deck,opponent_deck] if side == 0 else [opponent_deck,own_deck]
			var m := Battle.new(seed_value,decks[0].duplicate(),decks[1].duplicate(),picks[0],picks[1])
			m.ai_enabled = [true,true]
			m.record_events = false
			m.difficulty = 1
			m.economy_goals = [options.goal,6] if side == 0 else [6,options.goal]
			m.ai_params = [{"farm_goal":m.economy_goals[0]},{"farm_goal":m.economy_goals[1]}]
			var home: String = B.home_card(options.lord)
			var peak := m.count_buildings(side,home)
			var sum_count := 0.0
			var count_samples := 0
			var checkpoints := {}
			var next_sample := 1.0
			var reached := -1.0
			while not m.ended and m.elapsed < 600:
				m.step(1.0/60)
				if m.elapsed >= next_sample:
					var count := m.count_buildings(side,home)
					peak = maxi(peak,count)
					sum_count += count
					count_samples += 1
					if count >= options.goal and reached < 0: reached = m.elapsed
					for t: int in [60,120,180]:
						if m.elapsed >= t and not checkpoints.has(str(t)): checkpoints[str(t)] = count
					next_sample += 1.0
				m.events.clear()
			var result := {"seed":seed_value,"repeat":options.repeat,"faction":B.lord_faction(options.lord),"lord":options.lord,"opponent":opponent,"side":side,"goal":options.goal,"opponent_goal":6,"deck":own_deck,"opponent_deck":opponent_deck,"score":(1.0 if m.winner == side else 0.0) if m.ended else 0.5,"draw":not m.ended,"seconds":snappedf(m.elapsed,.01),"produced":m.stats[side].produced,"wasted":m.stats[side].wasted,"economy_spent":m.stats[side].spent.get(home,0),"economy_plays":m.stats[side].used.get(home,0),"peak":peak,"mean_count":sum_count/maxi(1,count_samples),"reached_seconds":reached,"checkpoints":checkpoints}
			out.store_line(JSON.stringify(result))
			out.flush()
	out.close()
	quit()
