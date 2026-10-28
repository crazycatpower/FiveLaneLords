extends CharacterBody2D

var game: Node2D
var hp: float = 260.0
var respawn: float = 0.0
var attack_timer: float = 0.0
var facing_left: bool = false
var bob: float = 0.0 # Walking bounce. game.gd draws the lord so he depth-sorts with the soldiers.

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	if game.ended or game.paused:
		return
	if respawn > 0.0:
		respawn -= delta
		if respawn <= 0.0:
			hp = 260.0
			position = Vector2(300, 390)
			show()
		return
	var direction := Input.get_vector("left", "right", "up", "down")
	velocity = direction * 205.0
	move_and_slide()
	position = position.clamp(Vector2(205, 155), Vector2(1090, 640))
	if direction.x != 0:
		facing_left = direction.x < 0
	bob = sin(game.elapsed * 13.0) * minf(velocity.length() / 70.0, 2.7)
	attack_timer -= delta
	if attack_timer <= 0:
		var enemy: Dictionary = game.nearest_enemy(position, 88.0)
		if not enemy.is_empty():
			enemy.hp -= 30.0
			game.burst(game.shown_at(enemy) + Vector2(0, -25), "−30", Color("922f25"))
			attack_timer = 0.65

func damage(amount: float) -> void:
	if respawn > 0:
		return
	hp -= amount
	if hp <= 0:
		respawn = 9.0
		hide()
		game.notice = "領主倒下！9 秒後從後方重返戰場"
