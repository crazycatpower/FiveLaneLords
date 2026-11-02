extends SceneTree

const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const DS = preload("res://deck_store.gd")
const L = preload("res://layout.gd")

var checks := 0
var failures := 0
var finished := {}

func _initialize() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	call_deferred("run")

func bare(seed_value: int = 1, deck_a: Array = [], deck_b: Array = [], lord_a: String = "", lord_b: String = "") -> Battle:
	var m := Battle.new(seed_value, deck_a, deck_b, lord_a, lord_b)
	m.buildings.clear()
	m.serials_in_use.clear()
	for team: int in range(2):
		for lane: int in range(5):
			m.claim_around(team, Vector2i(1 if team == 0 else 7, lane))
	return m

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func tick(m: RefCounted, seconds: float) -> void:
	for i: int in range(roundi(seconds * 60)):
		m.step(1.0 / 60.0)

func offer(m: RefCounted, kind: String, team: int = 0) -> void:
	m.decks[team][0] = kind
	m.ink[team] = 50.0
	m.hand_cd[team] = [0.0, 0.0, 0.0, 0.0]

func run() -> void:
	var campaign_errors := preload("res://campaign_catalog.gd").validate()
	check(campaign_errors.is_empty(),"campaign data: "+str(campaign_errors))
	check(load("res://game.gd") != null, "game.gd loads")
	var problems := B.validate()
	check(problems.is_empty(), "balance.gd validate: " + str(problems))

	preload("res://tools/test_faction_expansion.gd").run(self)
	preload("res://tools/test_card_library.gd").run(self)
	preload("res://tools/test_attack_animation.gd").run(self)
	preload("res://tools/test_dark_age.gd").run(self)

	if failures > 0:
		printerr("FAIL: %d checks, %d failures" % [checks, failures])
		quit(1)
	else:
		print("QUICK PASS: %d checks, 0 failures (finished in < 1s)" % checks)
		quit(0)
