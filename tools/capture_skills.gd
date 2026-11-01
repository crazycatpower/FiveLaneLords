extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://docs/skill-preview")
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 game.sound.enabled = false
 game.fx_enabled = true
 for kind: String in game.B.LORDS:
  for team: int in range(2):
   game.model = game.Battle.new(3,[],[],kind,kind)
   game.enter_battle("Skill preview")
   game.model.ink[team] = game.B.SKILL_COST
   game.model.cast_skill(team)
   game.consume_events()
   for e: Dictionary in game.effects:
    e.life = e.duration*0.65
   game.queue_redraw()
   await process_frame
   await RenderingServer.frame_post_draw
   var err := root.get_texture().get_image().save_png("res://docs/skill-preview/%s-%d.png" % [kind,team])
   if err != OK:
    push_error("Skill preview save failed")
    quit(1)
    return
 game.free()
 quit()
