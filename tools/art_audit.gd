extends SceneTree
# Review-only renderer: uses the game's actual palette conversion and atlas regions.
class AuditBoard extends Node2D:
 var game: Node2D
 var entries: Array = []
 var page := 0
 func _draw() -> void:
  draw_rect(Rect2(0,0,1600,900),Color("ddd2b8"))
  draw_string(game.font,Vector2(20,30),"Art audit | light / dark source | bottom: red / blue; castle/cards thumbnails | page %d" % (page+1),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.BLACK)
  for i: int in range(8):
   var index := page*8+i
   if index >= entries.size(): break
   var e: Array = entries[index]
   var origin := Vector2((i%4)*400,50+(i/4)*420)
   draw_string(game.font,origin+Vector2(10,22),e[0],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.BLACK)
   var tex: Texture2D = e[1]
   for side: int in range(2):
    var box := Rect2(origin+Vector2(10+side*195,32),Vector2(185,245))
    draw_rect(box,Color.WHITE if side == 0 else Color("18202a"))
    var size := tex.get_size()*minf(box.size.x/tex.get_width(),box.size.y/tex.get_height())
    draw_texture_rect(tex,Rect2(box.get_center()-size/2,size),false)
   var band := Rect2(origin+Vector2(10,285),Vector2(380,125))
   draw_texture_rect(game.PAPER,band,false)
   var size: Vector2 = e[3]
   draw_texture_rect(tex,Rect2(origin+Vector2(90,350)-size/2,size),false)
   draw_texture_rect(e[2],Rect2(origin+Vector2(280,350)-size/2,size),false)
   draw_string(game.font,origin+Vector2(12,404),"%d x %d px" % [int(size.x),int(size.y)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.BLACK)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://docs/art-audit")
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 game.fx_enabled = true
 game.sound.enabled = false
 game.hide()
 var board := AuditBoard.new()
 board.game = game
 for kind: String in game.textures:
  if kind == "castle_blue": continue
  var size: Vector2 = game.actor_rect(kind).size
  if kind.begins_with("lord_"): size = game.actor_rect(kind).size
  elif kind == "castle_red": size = Vector2(70,110) # actual castles inspected in the scene screenshots
  elif kind in ["farm","mill","tower","scarecrow"]: size = game.actor_rect(kind).size
  elif kind == "gate": size = Vector2(54,50)
  elif kind == "crest": size = Vector2(48,50)
  elif kind in ["fire","rain","harvest"]: size = Vector2(44,60)
  board.entries.append([kind,game.textures[kind],game.art(kind,1),size])
 board.entries.append(["card / selected",game.ART.card(false),game.ART.card(true),Vector2(75,107)])
 for i: int in range(4): board.entries.append(["ornament %d" % i,game.ART.ornament(i),game.ART.ornament(i),Vector2(96,86)])
 board.entries.append(["coin bag",game.ART.object_icon(0),game.ART.object_icon(0),Vector2(46,48)])
 root.add_child(board)
 for page: int in range(ceili(board.entries.size()/8.0)):
  board.page = page
  board.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  await save_shot("sheet-%d" % (page+1))
 print("Art audit: %d entries" % board.entries.size())
 board.free()
 game.show()
 game.player_deck = game.B.PRESETS[0].duplicate()
 game.player_lord = "lion"
 game.seed_value = 3
 game.deck_path = "user://audit-deck.json"
 game.show_title()
 await shot("title")
 for tab: String in ["unit","building","spell"]:
  game.deck_tab = tab
  game.show_deck()
  await shot("deck-"+tab)
 game.show_help()
 await shot("help")
 game.show_settings()
 await shot("settings")
 game.start_battle()
 game.model.ai_enabled = [false,false]
 game.model.lords[1].pos = game.model.lords[0].pos+Vector2(0,35)
 for i: int in range(5):
  var k: String = ["militia","ox","ram","healer","hunter"][i]
  for team: int in range(2):
   game.model.spawn_unit(team,i,k,Vector2(650+team*260,game.L.cell_center(Vector2i(0,i)).y))
 game.model.add_building(0,Vector2i(1,0),"tower")
 game.model.add_building(1,Vector2i(7,2),"mill")
 await shot("battle")
 game.model.paused = true
 await shot("pause")
 game.model.paused = false
 game.model.damage(game.model.lords[0],9999,1,"militia")
 var lord_death: Dictionary = game.model.events.filter(func(e: Dictionary) -> bool: return e.kind == "death").back()
 game.consume_events()
 await shot("lord-death")
 game.model.finish(0)
 await shot("result")
 game.adventure.progress_path = "user://audit-adventure.json"
 game.show_adventure()
 await shot("adventure")
 game.start_battle()
 game.model.ai_enabled = [false,false]
 game.model.events.clear()
 for i: int in range(8):
  var kind: String = ["ink","spell","cultivate","burn","breach","heal","fail","death"][i]
  var pos := Vector2(450+(i%4)*220,250+(i/4)*280)
  game.model.event(kind,pos,i%2,{"card":"hunter","radius":90.0,"lane":2})
 game.consume_events()
 for stage: float in [0.1,0.5,0.9]:
  for e: Dictionary in game.effects: e.life = e.duration*(1.0-stage)
  await shot("effects-"+str(roundi(stage*100)))
 game.effects.clear()
 game.model.event("play",Vector2(800,450),1,{"card":"guard","slot":0})
 game.consume_events()
 for e: Dictionary in game.effects: e.life = e.duration*0.7
 await shot("guard-play")
 var findings := {"guard_art":game.card_art_kinds("guard"),"spearbow_art":game.card_art_kinds("spearbow"),"lord_death_art":game.art(lord_death.art_kind).resource_path,"castle_source":game.textures.castle_red.get_size(),"castle_blue":game.blue_art.castle_red.get_size()}
 var data := FileAccess.open("res://docs/art-audit/runtime-mapping.json",FileAccess.WRITE)
 data.store_string(JSON.stringify(findings,"  "))
 data.close()
 DirAccess.remove_absolute("user://audit-deck.json")
 game.free()
 quit()

func shot(name: String) -> void:
 root.get_child(root.get_child_count()-1).queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 await save_shot(name)


func save_shot(name: String) -> void:
 var captured := root.get_texture().get_image()
 var path := "res://docs/art-audit/"+name+".png"
 for attempt: int in range(3):
  if captured.save_png(path) == OK: return
  await create_timer(0.3).timeout
 push_error("Cannot save audit evidence: "+path)
 quit(1)
