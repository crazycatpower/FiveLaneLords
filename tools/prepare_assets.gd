extends SceneTree
# Build-time derivatives only. Keep authoring the original single set of red/neutral artwork.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var start := Time.get_ticks_msec()
	var game = load("res://game.gd")
	game.prepare_art()
	var manifest: Dictionary = {}
	var manifest_path := "res://assets/generated-palette/manifest.json"
	if FileAccess.file_exists(manifest_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary: manifest = parsed
	DirAccess.make_dir_recursive_absolute("res://assets/generated-palette")
	var changed := 0
	for kind: String in game.prepared_art.textures:
		if kind == "castle_blue" or kind in ["farm","farmer","harvest","rain","fire"]: continue
		var source: Texture2D = game.prepared_art.textures[kind]
		var entry := {"source":source.resource_path,"sha256":FileAccess.get_sha256(source.resource_path),"revision":game.PALETTE_REVISION,"size":0 if kind in ["castle_red","castle_wall"] else 384}
		var path := "res://assets/generated-palette/"+kind+".png"
		var old: Dictionary = manifest.get(kind,{})
		if old.get("source","") == entry.source and old.get("sha256","") == entry.sha256 and old.get("revision","") == entry.revision and int(old.get("size",-1)) == entry.size and FileAccess.file_exists(path): continue
		var result: Texture2D = game.prepared_art.blue[kind]
		if result.get_image().save_png(path) != OK:
			push_error("Could not prepare "+kind)
			quit(1)
			return
		manifest[kind] = entry
		changed += 1
	var file := FileAccess.open(manifest_path,FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(manifest,"\t",true)+"\n")
	print("Prepared %d, reused %d palettes in %d ms. Import the project before running/exporting." % [changed,manifest.size()-changed,Time.get_ticks_msec()-start])
	quit()
