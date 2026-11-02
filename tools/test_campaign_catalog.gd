extends SceneTree
const Catalog = preload("res://campaign_catalog.gd")
const Story = preload("res://campaign_story_data.gd")
func _initialize() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	assert(Catalog.validate().is_empty(),str(Catalog.validate()))
	for stage: Dictionary in Catalog.STAGES:
		assert(stage.dialogue == Story.SCENES.has(stage.id))
		if not stage.dialogue: continue
		for recruit: String in ["bandit","knight"]:
			for won: bool in [false,true]:
				var lines: Array = Story.dialogue(stage.id,recruit,won)
				assert(not lines.is_empty())
				for line: Array in lines: assert(line.size() == 4 and line.all(func(v): return v is String and not v.is_empty()))
				lines[0][1] = "mutation must not reach source"
				assert(Story.dialogue(stage.id,recruit,won)[0][1] != lines[0][1])
	var bad: Array = Catalog.STAGES.duplicate(true)
	bad[1].id = bad[0].id
	assert(not Catalog.validate(bad).is_empty())
	for key: String in ["enemy_deck","rewards","active_lanes","buildings","lord","kind"]:
		bad = Catalog.STAGES.duplicate(true)
		bad[0][key] = {"enemy_deck":["missing"],"rewards":["missing"],"active_lanes":[2,2],"buildings":[[1,0,"militia"]],"lord":"missing","kind":"survive"}[key]
		assert(not Catalog.validate(bad).is_empty(),key)
	# One-off migration evidence captured BEFORE the refactor, never a replacement fixture.
	if "--compare-before" in OS.get_cmdline_user_args():
		var f := FileAccess.open("res://.runtime/campaign-before.bin",FileAccess.READ)
		var before: Dictionary = f.get_var()
		assert(before.stages.size() == Catalog.STAGES.size())
		for i: int in range(Catalog.STAGES.size()):
			var stage: Dictionary = Catalog.STAGES[i]
			for key: String in before.stages[i]: assert(stage[key] == before.stages[i][key],stage.id+" "+key)
			assert(stage.rewards == before.rewards[stage.id])
			if i == 0: continue
			for recruit: String in ["bandit","knight"]:
				for won: bool in [false,true]: assert(Story.dialogue(stage.id,recruit,won) == before.dialogues[str(i)+recruit+str(won)])
	print("PASS: campaign schema, references, mutation isolation and optional pre-refactor equality")
	quit()
