extends SceneTree
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")
const Anim = preload("res://attack_animation.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/attack-animation-preview")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.deck_path = "user://attack-animation-capture.json"
	game.sound_enabled = false
	game.start_battle()
	game.set_physics_process(false)
	game.set_process(false)
	game.model.ai_enabled = [false,false]
	game.model.lord_active = [false,false]
	var kinds: Array[String] = []
	for kind: String in B.CARDS:
		if B.CARDS[kind].type in ["unit","building"] and (B.CARDS[kind].has("damage") or B.CARDS[kind].has("area_damage")): kinds.append(kind)
	var pages: Array = []
	for start: int in range(0,kinds.size(),5): pages.append(kinds.slice(start,start+5))
	for lord: String in B.LORDS: pages.append(["lord_"+lord])
	for page: int in range(pages.size()):
		game.model.units.clear()
		game.model.buildings.clear()
		game.model.lords.clear()
		for team: int in range(2):
			var hidden: Dictionary = preload("res://lord.gd").create(team)
			hidden.hp = 0
			game.model.lords.append(hidden)
		game.effects.clear()
		game.attack_animation.clear()
		var actors: Array = []
		for row: int in range(5):
			if row >= pages[page].size(): break
			var kind: String = pages[page][row]
			for team: int in range(2):
				var pos := L.cell_center(Vector2i(3 if team == 0 else 5,row))
				var actor: Dictionary
				if kind.begins_with("lord_"):
					actor = preload("res://lord.gd").create(team,kind.trim_prefix("lord_"))
					actor.pos = pos
					game.model.lords[team] = actor
				elif B.CARDS[kind].type == "building": actor = game.model.add_building(team,Vector2i(3 if team == 0 else 5,row),kind)
				else: actor = game.model.spawn_unit(team,row,kind,pos)
				actors.append([actor,kind])
		for phase: int in range(3):
			game.model.elapsed = phase*0.15
			for pair: Array in actors:
				game.attack_animation.clips[Anim.key(pair[0])] = {"start":0.0,"duration":0.3,"style":Anim.style(pair[1])}
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/attack-animation-preview/page-%d-phase-%d.png" % [page,phase])
	game.free()
	quit()
