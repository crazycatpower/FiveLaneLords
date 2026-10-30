extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://docs/background-preview")
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 for scene: String in ["title","deck","help","battle","tutorial"]:
  match scene:
   "title": game.show_title()
   "deck": game.show_deck()
   "help": game.show_help()
   "battle": game.start_battle()
   "tutorial": game.start_tutorial()
  game.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  if root.get_texture().get_image().save_png("res://docs/background-preview/%s.png" % scene) != OK:
   quit(1)
   return
 game.free()
 quit()
