extends Node
const CUES := {"play":"bookFlip1","ink":"dropLeather","hoe":"chop","cultivate":"chop","hit":"chop","death":"dropLeather","burn":"creak1","spell":"bookPlace1","breach":"doorClose_1","arrow":"drawKnife1","heal":"handleCoins","overflow":"metalPot1","finish":"metalPot1","ramp":"metalPot1","invaded":"doorClose_1","fail":"dropLeather","skill":"doorClose_1"}
var enabled := true
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last: Dictionary = {}
var cursor := 0
func _ready() -> void:
	for name: String in CUES.values():
		if not streams.has(name): streams[name] = load("res://assets/audio/"+name+".ogg")
	for i: int in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -13
		add_child(player)
		players.append(player)
func cue(kind: String) -> void:
	if not enabled or not CUES.has(kind) or DisplayServer.get_name() == "headless": return
	var now := Time.get_ticks_msec()
	if now-int(last.get(kind,-1000)) < 70: return
	last[kind] = now
	var player := players[cursor]
	cursor = (cursor+1)%players.size()
	player.stream = streams[CUES[kind]]
	player.play()
