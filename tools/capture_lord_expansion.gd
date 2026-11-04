extends SceneTree
var g
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	call_deferred("run")
func snap(name: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for c in g.ui:
		if c is RichTextLabel: assert(c.get_content_height() <= c.size.y,"Text overflow")
	root.get_texture().get_image().save_png("res://docs/lord-expansion-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/lord-expansion-preview")
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	for kind: String in ["rune","vampire"]:
		g.library.open("lord_"+kind)
		await snap(kind+"-codex")
	g.player_lord = "rune"
	g.player_deck = g.DeckStore.fit_to_lord(g.player_deck,"rune")
	g.show_deck()
	for i: int in range(g.B.LORDS.size()): assert(g.lord_rect(i).end.y < g.pool_rect(0,g.tab_size()).position.y,"Lord buttons overlap card pool")
	await snap("deck")
	g.watch_lords = ["rune","vampire"]
	g.show_watch()
	await snap("watch")
	g.model = g.Battle.new(92,[],[],"rune","vampire")
	g.model.ai_enabled = [false,false]
	g.model.skill_cd = [0.0,0.0]
	g.model.ink = [50.0,50.0]
	g.adventure.index = -1
	g.enter_battle("Lords preview")
	g.model.cast_skill(0)
	g.consume_events()
	for e in g.effects: e.life = e.duration*.6
	await snap("rune-skill")
	var p: Vector2 = g.L.cell_center(Vector2i(5,2))
	var u: Dictionary = g.model.spawn_unit(1,2,"skeleton",p)
	var target: Dictionary = g.model.spawn_unit(0,2,"knight",p-Vector2(40,0))
	g.model.cast_skill(1)
	g.model.attack(u,target)
	g.consume_events()
	for e in g.effects: e.life = e.duration*.6
	await snap("vampire-skill")
	g.free()
	print("PASS: lord codex, deck, watch and skills captured")
	quit()
