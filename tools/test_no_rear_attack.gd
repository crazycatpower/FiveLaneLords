extends SceneTree

const Battle = preload("res://battle.gd")
const B = preload("res://balance.gd")
const L = preload("res://layout.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_standalone")

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + msg)

func run_standalone() -> void:
	run(self)
	if failures > 0:
		printerr("TEST FAIL: %d checks, %d failures" % [checks, failures])
		quit(1)
	else:
		print("NO REAR ATTACK PASS: %d checks, 0 failures" % checks)
		quit(0)

static func bare(seed_value: int = 1) -> Battle:
	var m := Battle.new(seed_value, [], [], "", "")
	m.buildings.clear()
	m.serials_in_use.clear()
	for team: int in range(2):
		for lane: int in range(5):
			m.claim_around(team, Vector2i(1 if team == 0 else 7, lane))
	return m

static func run(t) -> void:
	var y: float = L.cell_center(Vector2i(0, 2)).y

	# Test 1: Team 0 melee unit does not attack rear enemy
	var m := bare(1)
	var red_melee := m.spawn_unit(0, 2, "militia", Vector2(700, y))
	var blue_rear := m.spawn_unit(1, 2, "militia", Vector2(680, y)) # 20px behind red (melee range 40)
	m.build_lookups()
	t.check(m.choose_target(red_melee, B.CARDS.militia).is_empty(), "team 0 melee unit ignores enemy behind it")

	# Test 2: Team 0 melee unit prefers front enemy over rear enemy
	var blue_front := m.spawn_unit(1, 2, "militia", Vector2(730, y)) # 30px in front
	m.build_lookups()
	t.check(m.choose_target(red_melee, B.CARDS.militia) == blue_front, "team 0 melee unit targets front enemy when rear also present")

	# Test 3: Team 0 unit marches forward instead of stopping for rear enemy
	blue_front.hp = 0
	m.build_lookups()
	var start_x: float = red_melee.pos.x
	m.step(1.0 / 60.0)
	t.check(red_melee.pos.x > start_x, "team 0 unit continues marching forward when enemy is behind")

	# Test 4: Team 1 melee unit does not attack rear enemy
	m = bare(2)
	var blue_melee := m.spawn_unit(1, 2, "militia", Vector2(800, y)) # faces -1.0
	var red_rear := m.spawn_unit(0, 2, "militia", Vector2(820, y)) # 20px behind blue (to the right)
	m.build_lookups()
	t.check(m.choose_target(blue_melee, B.CARDS.militia).is_empty(), "team 1 melee unit ignores enemy behind it")

	var red_front := m.spawn_unit(0, 2, "militia", Vector2(770, y)) # 30px in front (to the left)
	m.build_lookups()
	t.check(m.choose_target(blue_melee, B.CARDS.militia) == red_front, "team 1 melee unit targets front enemy")

	# Test 5: Ranged unit does not shoot rear enemy
	m = bare(3)
	var archer := m.spawn_unit(0, 2, "arcane_archer", Vector2(700, y)) # range 230
	var foe_rear := m.spawn_unit(1, 2, "militia", Vector2(600, y)) # 100px behind
	m.build_lookups()
	t.check(m.choose_target(archer, B.CARDS.arcane_archer).is_empty(), "ranged unit does not target enemy behind within attack range")

	# Test 6: Catapult does not target rear enemy
	m = bare(4)
	var cata := m.spawn_unit(0, 2, "catapult", Vector2(600, y))
	var foe_behind_cata := m.spawn_unit(1, 2, "militia", Vector2(500, y))
	m.build_lookups()
	t.check(m.catapult_target(cata).is_empty(), "catapult does not target enemy behind")

	# Test 7: Reaper does not target rear enemy even with lower serial
	m = bare(5)
	var reaper := m.spawn_unit(0, 2, "reaper", Vector2(700, y))
	var foe_low_serial_rear := m.spawn_unit(1, 2, "militia", Vector2(680, y))
	var foe_high_serial_front := m.spawn_unit(1, 2, "militia", Vector2(720, y))
	m.build_lookups()
	t.check(m.reaper_target(reaper) == foe_high_serial_front, "reaper targets front enemy even if rear enemy has lower serial")
