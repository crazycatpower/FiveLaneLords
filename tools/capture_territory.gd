extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://docs/territory-preview")
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 for first: int in range(2):
  game.start_battle()
  game.sound.enabled = false
  game.model.ai_enabled = [false,false]
  for team: int in [first,1-first]:
   for distance: int in [1,2,3]:
    var col: int = distance if team == 0 else 8-distance
    game.model.ink[team] = 50
    game.model.farm_cd[team] = 0
    if not game.model.play(team,game.Battle.FARM_SLOT,game.L.cell_center(Vector2i(col,2))):
     push_error("Frontier fixture failed")
     quit(1)
     return
  game.notice = "First claim: " + ("red" if first == 0 else "blue")
  game.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  if root.get_texture().get_image().save_png("res://docs/territory-preview/first-%d.png" % first) != OK:
   quit(1)
   return
  var frontier: Dictionary = game.model.building_at(Vector2i(3 if first == 0 else 5,2))
  game.model.damage(frontier,frontier.max_hp,1-first,"militia")
  game._physics_process(1.0/60.0)
  game.notice = "Frontier building destroyed"
  game.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  if root.get_texture().get_image().save_png("res://docs/territory-preview/lost-%d.png" % first) != OK:
   quit(1)
   return
 game.free()
 quit()

