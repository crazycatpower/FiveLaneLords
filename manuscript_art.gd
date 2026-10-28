extends RefCounted
static var cache: Dictionary = {}

static func region(sheet: String, rect: Rect2) -> AtlasTexture:
	var key := sheet + str(rect)
	if cache.has(key):
		return cache[key]
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/manuscript-v1/" + sheet + ".png")
	texture.region = rect
	texture.filter_clip = true
	cache[key] = texture
	return texture

static func card(selected: bool = false) -> AtlasTexture:
	return region("ui-kit",Rect2(410 if selected else 44,35,322,460))

static func health_frame() -> AtlasTexture:
	return region("ui-kit",Rect2(18,562,463,111))

static func portrait_frame(blue: bool) -> AtlasTexture:
	return region("ui-kit",Rect2(1160 if blue else 779,49,360,416))

static func ornament(index: int) -> AtlasTexture:
	if index == 4:
		return region("ornament-kit",Rect2(20,470,415,125))
	if index == 5:
		return region("ornament-kit",Rect2(450,470,350,125))
	return region("ornament-kit",Rect2((index % 4)*384,(index / 4)*341,384,341))

static func object_icon(index: int) -> AtlasTexture:
	return region("small-objects",Rect2((index % 4)*313.5,(index / 4)*313.5,313.5,313.5))
