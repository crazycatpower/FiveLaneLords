extends RefCounted
# Presentation-only attack clips, sampled in simulation time so pause and fast-forward agree.
var previous: Dictionary = {}
var clips: Dictionary = {}

static func key(actor: Dictionary) -> String:
	return "lord:%d" % actor.team if actor.kind == "lord" else "actor:%d" % actor.id

static func style(kind: String) -> String:
	match kind:
		"hunter": return "bow"
		"tower": return "tower"
		"catapult": return "siege"
		"necromancer", "healer", "lord_underworld", "lord_harvest": return "cast"
		"corpse_giant", "knight", "reaper", "lord_lion", "lord_iron": return "heavy"
		"ram", "ox": return "ram"
		"raven": return "peck"
		"drummer": return "drum"
	return "thrust"

func clear() -> void:
	previous.clear()
	clips.clear()

func observe(model: RefCounted) -> void:
	var alive: Dictionary = {}
	for actor: Dictionary in model.units+model.buildings+model.lords:
		if actor.hp <= 0: continue
		var id := key(actor)
		alive[id] = true
		var timers := [float(actor.get("cd",0)),float(actor.get("heal_cd",0)),float(actor.get("summon_left",0)),float(actor.get("drum_cd",0))]
		if not previous.has(id): previous[id] = [0.0,0.0,0.0,0.0]
		for i: int in range(timers.size()):
			if timers[i] > previous[id][i]+0.0001:
				var kind: String = "lord_"+actor.lord if actor.kind == "lord" else actor.kind
				var mode := style(kind) if i == 0 else ("drum" if i == 3 else "cast")
				clips[id] = {"start":model.elapsed,"duration":clampf(timers[i]*0.7,0.16,0.42),"style":mode}
				break
		previous[id] = timers
	for id: String in previous.keys():
		if not alive.has(id):
			previous.erase(id)
			clips.erase(id)
	for id: String in clips.keys():
		if model.elapsed-clips[id].start >= clips[id].duration: clips.erase(id)

func pose(actor: Dictionary, now: float) -> Dictionary:
	var clip: Dictionary = clips.get(key(actor),{})
	if clip.is_empty(): return {}
	return sample(clip.style,clampf((now-clip.start)/clip.duration,0,1))

static func sample(mode: String, progress: float) -> Dictionary:
	# Impact is immediate: displacement and ink stroke decay through a short recovery.
	var hit := pow(1.0-progress,2.0)
	var settle := sin(progress*PI)*hit
	var offset := Vector2.ZERO
	var angle := 0.0
	var scale := Vector2.ONE
	match mode:
		"bow":
			offset.x = -6*hit
			angle = -0.07*hit
		"tower": scale = Vector2(1+0.04*hit,1-0.04*hit)
		"siege":
			offset.x = -8*hit
			angle = -0.09*hit
		"cast":
			offset.y = -4*settle
			angle = 0.07*hit
		"heavy":
			offset.x = 12*hit
			angle = 0.15*hit
		"ram":
			offset.x = 14*hit
			scale = Vector2(1+0.05*hit,1-0.04*hit)
		"peck":
			offset = Vector2(10*hit,8*hit)
			angle = 0.23*hit
		"drum":
			offset.y = 3*hit
			angle = -0.09*hit
		_:
			offset.x = 9*hit
			angle = 0.08*hit
	return {"offset":offset,"angle":angle,"scale":scale,"strength":hit,"style":mode,"progress":progress}
