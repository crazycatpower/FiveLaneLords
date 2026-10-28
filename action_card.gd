extends Button
const ART = preload("res://manuscript_art.gd")

var artwork: Texture2D
var title_text: String
var detail_text: String
var key_text: String
var price_text: String
var card_font: Font
var cooldown: float = 0.0
var cooldown_max: float = 1.0
var chosen: bool = false
var accent := Color("cfaa60")

func _draw() -> void:
	if artwork == null:
		return
	draw_texture_rect(ART.card(chosen),Rect2(Vector2.ZERO,size),false)
	var tint := Color(0.48,0.49,0.52) if disabled else Color.WHITE
	draw_texture_rect(artwork,Rect2(size.x/2-48,24,96,100),false,tint)
	draw_string(card_font,Vector2(0,146),title_text,HORIZONTAL_ALIGNMENT_CENTER,size.x,18,Color("493321") if not disabled else Color("8a7b64"))
	# Text stays above the frame's bottom corner flowers (they start ~83% down); long text shrinks rather than overflow.
	var detail_width := size.x-30
	var detail_size := 13
	while detail_size > 10 and card_font.get_string_size(detail_text,HORIZONTAL_ALIGNMENT_LEFT,-1,detail_size).x > detail_width:
		detail_size -= 1
	draw_string(card_font,Vector2(15,165),detail_text,HORIZONTAL_ALIGNMENT_CENTER,detail_width,detail_size,Color("725c40"))
	# The key badge grows with its label, so "SPACE" stays inside it.
	var key_width := card_font.get_string_size(key_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+12
	draw_style_box(chip(Color("725138")),Rect2(8,8,key_width,22))
	draw_string(card_font,Vector2(14,24),key_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("efdfb9"))
	draw_circle(Vector2(size.x-23,22),17,Color("765436"))
	draw_arc(Vector2(size.x-23,22),16,0,TAU,24,accent,2)
	draw_string(card_font,Vector2(size.x-36,28),price_text,HORIZONTAL_ALIGNMENT_CENTER,26,14,Color("f1cc70"))
	if cooldown > 0:
		draw_rect(Rect2(3,3,size.x-6,(size.y-6)*clampf(cooldown/cooldown_max,0,1)),Color(0.05,0.08,0.12,0.58))
		draw_string(card_font,Vector2(0,65),"%.1fs" % cooldown,HORIZONTAL_ALIGNMENT_CENTER,size.x,24,Color.WHITE)

func chip(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style
