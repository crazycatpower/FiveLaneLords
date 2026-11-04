extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.sound_enabled = false
	g.adventure.progress_path = "user://chapter1-full-test.json"
	
	print("--- Testing Chapter 1 (1-1 to 1-10) Progressive Unlocks & Deck Building ---")
	
	for recruit in ["bandit", "knight"]:
		print("\n=== Testing Route with Recruit: %s ===" % recruit)
		g.adventure.recruit = ""
		g.adventure.cleared = {}
		g.adventure.custom_deck = []
		
		# Initial starter pool should be 3 units
		assert(g.adventure.unlocked_cards().size() == 3, "Initial starter units should be 3")
		assert(g.adventure.unlocked_cards() == ["farmer", "hunter", "militia"], "Starter units should be farmer, hunter, militia")
		
		for stage_idx in range(10):
			var stage = g.adventure.STAGES[stage_idx]
			print("  Testing Stage %d (%s)..." % [stage_idx + 1, stage.name])
			
			# Check deck requirement behavior for stages 1-6 ~ 1-10 (stage_idx >= 5)
			if stage_idx >= 5 and not g.adventure.custom_deck_valid():
				print("    Attempting to embark on Stage %d without custom deck..." % (stage_idx + 1))
				# Map UI button redirects to deck builder when custom_deck is not valid
				g.adventure.open_adventure_deck(g)
				assert(g.screen == "deck", "Stage %d without custom deck should open deck builder" % (stage_idx + 1))
				assert(g.adventure_deck_mode, "Should be in adventure deck mode")
				print("    Successfully opened deck builder before stage %d!" % (stage_idx + 1))
				
				# Check unlocked pool in deck builder
				var pool = g.adventure.unlocked_cards()
				assert(pool.size() >= 8, "Unlocked pool must have at least 8 cards by stage 1-6")
				
				# Construct valid 8-card custom deck from unlocked pool
				g.player_deck = pool.slice(0, 8)
				assert(g.DeckStore.valid(g.player_deck, "adventure"), "Constructed deck must be valid")
				g.adventure.custom_deck = g.player_deck.duplicate()
				g.adventure.save_progress()
				g.adventure_deck_mode = false
			
			g.adventure.start(g, stage_idx)
			
			# Story intro for stages 1..9
			if stage_idx > 0:
				assert(g.screen == "road_toll_story", "Stage %d should start with story screen" % (stage_idx + 1))
				assert(g.adventure.road_story.lines.size() > 0, "Stage %d should have story lines" % (stage_idx + 1))
				var intro_steps = 0
				while g.screen == "road_toll_story":
					for c in g.ui:
						if c is RichTextLabel:
							assert(c.get_content_height() <= c.size.y + 10, "Text overflow in stage %d step %d: %s" % [stage_idx + 1, intro_steps, c.text])
					intro_steps += 1
					g.adventure.road_story.advance(g)
				assert(intro_steps > 0, "Stage %d intro should advance" % (stage_idx + 1))
			
			# Now in battle
			assert(g.screen == "battle", "Stage %d should be in battle screen" % (stage_idx + 1))
			assert(g.model.decks[0].size() == 8, "Player deck should have 8 cards in stage %d" % (stage_idx + 1))
			
			# Check recruit card in fixed deck for stages 1-2 through 1-5
			if stage_idx in range(1, 5) and stage.deck is Array:
				assert(recruit in g.model.decks[0], "Recruit %s should be in deck for stage %d" % [recruit, stage_idx + 1])
			
			# Check custom deck is used for stages 1-6 through 1-10 (Battle shuffles deck order into draw pile)
			if stage_idx >= 5:
				var actual = g.model.decks[0].duplicate()
				actual.sort()
				var expected = g.adventure.custom_deck.duplicate()
				expected.sort()
				assert(actual == expected, "Stage %d should use player custom deck (sorted cards mismatch)" % (stage_idx + 1))
			
			# Simulate victory
			g.model.finish(0)
			g.adventure.update(g)
			
			# Settle stage 0 recruit
			if stage_idx == 0:
				g.adventure.recruit = recruit
				g.adventure.settle(true, "")
			else:
				# Outro story
				assert(g.screen == "road_toll_story", "Stage %d should show outro story on victory" % (stage_idx + 1))
				assert(g.adventure.road_story.victory, "Road story should be in victory state")
				
				# Check unlock announcement in outro lines
				var last_line = g.adventure.road_story.lines[-1]
				print("    Stage %d unlock notice: [%s] %s" % [stage_idx + 1, last_line[0], last_line[1].replace("\n", " ")])
				assert(not "（" in last_line[1] and not "）" in last_line[1], "No parentheses allowed in unlock notice")
				
				var outro_steps = 0
				while g.screen == "road_toll_story":
					for c in g.ui:
						if c is RichTextLabel:
							assert(c.get_content_height() <= c.size.y + 10, "Outro text overflow in stage %d step %d: %s" % [stage_idx + 1, outro_steps, c.text])
					outro_steps += 1
					g.adventure.road_story.advance(g)
				assert(outro_steps > 0, "Stage %d outro should advance" % (stage_idx + 1))
			
			# Verify cleared status and progressive unlock count
			assert(g.adventure.is_cleared(stage_idx), "Stage %d should be marked cleared" % (stage_idx + 1))
			var expected_counts = [4, 5, 6, 7, 9, 10, 12, 14, 16, 16]
			var actual_count = g.adventure.unlocked_cards().size()
			print("    Unlocked units so far: %d (expected %d)" % [actual_count, expected_counts[stage_idx]])
			assert(actual_count == expected_counts[stage_idx], "Stage %d unlocked count mismatch: got %d, expected %d" % [stage_idx + 1, actual_count, expected_counts[stage_idx]])
		
		print("Route %s passed all 10 stages with proper deck building and unlocks!" % recruit)
	
	DirAccess.remove_absolute(g.adventure.progress_path)
	g.free()
	print("\nALL CHAPTER 1 PROGRESSIVE UNLOCKS & DECK BUILDING TESTS PASSED!")
	quit()
