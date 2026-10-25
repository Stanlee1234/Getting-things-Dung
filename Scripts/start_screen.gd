extends Control

@onready var ball: RigidBody2D = $BouncingBall
@onready var ball_sprite: Sprite2D = $BouncingBall/Sprite2D
@onready var bounce_particles: CPUParticles2D = $BouncingBall/BounceParticles
@onready var play_button: Button = $UI/VBoxContainer/PlayButton
@onready var quit_button: Button = $UI/VBoxContainer/QuitButton

# Screen boundary colliders
@onready var wall_left: CollisionShape2D = $Walls/Left/CollisionShape2D
@onready var wall_right: CollisionShape2D = $Walls/Right/CollisionShape2D
@onready var wall_top: CollisionShape2D = $Walls/Top/CollisionShape2D
@onready var wall_bottom: CollisionShape2D = $Walls/Bottom/CollisionShape2D

var base_ball_scale: Vector2 = Vector2(0.2, 0.2)
var min_speed: float = 380.0
var max_speed: float = 620.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_walls()
	get_viewport().size_changed.connect(_update_walls)
	
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Initial kick for the ball
	if is_instance_valid(ball):
		ball.linear_velocity = Vector2(400.0, -280.0)
		ball.angular_velocity = 6.0
		ball.body_entered.connect(_on_ball_collided)

func _update_walls() -> void:
	var vp_size = get_viewport_rect().size
	var thickness = 64.0
	
	if is_instance_valid(wall_left):
		wall_left.shape.size = Vector2(thickness, vp_size.y * 2)
		wall_left.position = Vector2(-thickness * 0.5, vp_size.y * 0.5)
		
	if is_instance_valid(wall_right):
		wall_right.shape.size = Vector2(thickness, vp_size.y * 2)
		wall_right.position = Vector2(vp_size.x + thickness * 0.5, vp_size.y * 0.5)
		
	if is_instance_valid(wall_top):
		wall_top.shape.size = Vector2(vp_size.x * 2, thickness)
		wall_top.position = Vector2(vp_size.x * 0.5, -thickness * 0.5)
		
	if is_instance_valid(wall_bottom):
		wall_bottom.shape.size = Vector2(vp_size.x * 2, thickness)
		wall_bottom.position = Vector2(vp_size.x * 0.5, vp_size.y + thickness * 0.5)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(ball):
		return
		
	# Keep ball moving with lively action
	var vel = ball.linear_velocity
	var speed = vel.length()
	
	if speed < min_speed:
		if vel == Vector2.ZERO:
			vel = Vector2(1, -1).normalized() * min_speed
		else:
			vel = vel.normalized() * min_speed
		ball.linear_velocity = vel
	elif speed > max_speed:
		ball.linear_velocity = vel.normalized() * max_speed

	# Ensure ball stays within screen bounds (safety wrap)
	var vp_size = get_viewport_rect().size
	if ball.global_position.x < -80 or ball.global_position.x > vp_size.x + 80 or ball.global_position.y < -80 or ball.global_position.y > vp_size.y + 80:
		ball.global_position = vp_size * 0.5
		ball.linear_velocity = Vector2(randf_range(-350, 350), randf_range(-350, 350))

func _unhandled_input(event: InputEvent) -> void:
	# Clicking or tapping gives the ball a fun interactive boost!
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(ball):
			var dir = (ball.global_position - event.position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			var dist = event.position.distance_to(ball.global_position)
			var force = clamp(600.0 - dist * 0.5, 250.0, 750.0)
			ball.apply_central_impulse(dir * force)
			ball.angular_velocity += randf_range(-12.0, 12.0)
			_play_bounce_feedback()

func _on_ball_collided(_body: Node) -> void:
	_play_bounce_feedback()

func _play_bounce_feedback() -> void:
	if is_instance_valid(bounce_particles):
		bounce_particles.restart()
		bounce_particles.emitting = true
		
	if is_instance_valid(ball_sprite):
		var tween = create_tween()
		tween.tween_property(ball_sprite, "scale", base_ball_scale * Vector2(1.22, 0.8), 0.08)
		tween.tween_property(ball_sprite, "scale", base_ball_scale, 0.12)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
