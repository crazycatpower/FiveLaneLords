extends RefCounted
# Every generated blue sprite must match its current source: same file hash in the manifest and the
# same silhouette the same way round (not mirrored). Catches stale derivatives after art edits.
# Fix a failure with: godot_console --headless --path . -s tools/prepare_assets.gd, then --import.
const SIZE := 48

static func mask(path: String) -> PackedByteArray:
	var img := Image.load_from_file(path)
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SIZE,SIZE,Image.INTERPOLATE_BILINEAR)
	var out := PackedByteArray()
	out.resize(SIZE*SIZE)
	for y: int in range(SIZE):
		for x: int in range(SIZE): out[y*SIZE+x] = 1 if img.get_pixel(x,y).a > 0.3 else 0
	return out

static func run(t) -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated-palette/manifest.json"))
	t.check(manifest is Dictionary and not manifest.is_empty(),"palette manifest exists")
	if not manifest is Dictionary: return
	for kind: String in manifest:
		var entry: Dictionary = manifest[kind]
		var generated := "res://assets/generated-palette/"+kind+".png"
		t.check(FileAccess.get_sha256(entry.source) == entry.sha256,"blue art for %s was made from the current source (rerun tools/prepare_assets.gd)" % kind)
		var a := mask(entry.source)
		var b := mask(generated)
		var same := 0
		var mirrored := 0
		for y: int in range(SIZE):
			for x: int in range(SIZE):
				if a[y*SIZE+x] == b[y*SIZE+x]: same += 1
				if a[y*SIZE+x] == b[y*SIZE+SIZE-1-x]: mirrored += 1
		t.check(same >= SIZE*SIZE*0.97 and same >= mirrored,"blue art for %s has the source's silhouette, not mirrored (%d vs mirrored %d)" % [kind,same,mirrored])
