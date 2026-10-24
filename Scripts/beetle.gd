extends CharacterBody2D

#---------------------------------------------------->
# Import Variables
#---------------------------------------------------->
@onready var sprite = $Sprite2D
@onready var base_scale: Vector2 = sprite.scale

#---------------------------------------------------->
# Export Variables
#---------------------------------------------------->
@export_group("General")
@export var speed: float = 160.0
@export var accel: float = 1200.0
@export var friction: float = 1400.0
@export var ball_friction: float = 50.0
@export var gravity: float = 980.0
@export var push_force: float = 35.0

@export_group("Jump")
@export var max_jump_v: float = -400.0
@export var min_jump_v: float = -180.0
@export var max_charge_time = 0.9


#---------------------------------------------------->
# Variables
#---------------------------------------------------->
var charge_time = 0.0
var charging: bool = false

#---------------------------------------------------->
# Functions
#---------------------------------------------------->

func _ready() -> void:
	floor_snap_length = 16.0
	floor_constant_speed = true

func _physics_process(delta: float) -> void:
	var direction:float = Input.get_axis("left","right")
	var on_ball: bool = is_on_floor() and get_last_slide_collision() and get_last_slide_collision().get_collider() is RigidBody2D
	var current_friction: float = ball_friction if on_ball else friction
	
		#Character Snap
	if is_on_floor():
		var target_angle = get_floor_normal().angle() + PI / 2.0
		rotation = lerp_angle(rotation, target_angle, 15.0 * delta)
	else:
		rotation = lerp_angle(rotation, 0.0, 10.0 * delta)
	
	# Gravity + Jump
	if not is_on_floor():
		velocity.y += gravity * delta
		charge_time = 0.0
	elif Input.is_action_pressed("up"):
		#Deactivate modulate after switching to acutal sprites
		sprite.modulate = Color(1.0, 0.1, 1.0, 1.0)
		charge_time = min(charge_time + delta, max_charge_time)
		direction = 0.0
		charging = true
	elif Input.is_action_just_released("up"):
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		velocity.y = lerp(min_jump_v, max_jump_v, charge_time / max_charge_time)
		charge_time = 0.0
		charging = false

	# Movement
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)
	
	#Fixing ball pushing bug, where the player was glitching.
	var pre_vel_x: float = velocity.x
	move_and_slide()
	
	# Ball Pushing
	var pushed_ball: bool = false
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() is RigidBody2D:
			var normal = col.get_normal()
			if abs(normal.x) > 0.3 and normal.y > -0.7:
				var rb = col.get_collider() as RigidBody2D
				
				# Push along the floor tangent instead of flat horiz
				var push_dir: Vector2
				if is_on_floor():
					var floor_norm = get_floor_normal()
					push_dir = Vector2(-floor_norm.y, floor_norm.x) * sign(direction)
					if push_dir.dot(Vector2(direction, 0)) < 0:
						push_dir = -push_dir
				else:
					push_dir = Vector2(direction, 0)
				
				rb.apply_central_impulse(push_dir * push_force)
				pushed_ball = true

	# Walking speed bugfix
	if pushed_ball and direction != 0:
		velocity.x = pre_vel_x
