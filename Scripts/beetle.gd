extends CharacterBody2D

#---------------------------------------------------->
# Import Variables
#---------------------------------------------------->
@onready var sprite = $Sprite2D
#Squishing animation variables
@onready var base_scale: Vector2 = sprite.scale
var sprite_squash: Vector2 = Vector2.ONE
var was_on_floor_last_frame: bool = true
const FEET_OFFSET: float = 15.0

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
@export var max_charge_time: float = 0.9

@export_group("Ball Boosts")
@export var min_ball_boost: float = 300.0
@export var max_ball_boost: float = 650.0

#---------------------------------------------------->
# Variables
#---------------------------------------------------->
var charge_time: float = 0.0
var charging: bool = false
var ball_in_contact: RigidBody2D = null

#---------------------------------------------------->
# Functions
#---------------------------------------------------->

func _ready() -> void:
	floor_snap_length = 16.0
	floor_constant_speed = true

func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("left", "right")
	var on_ball: bool = is_on_floor() and get_last_slide_collision() and get_last_slide_collision().get_collider() is RigidBody2D
	var current_friction: float = ball_friction if on_ball else friction

	_handle_ground_snap(delta)
	_handle_jump(delta)
	
	# Prevent walking while charging a jump
	if charging:
		direction = 0.0
		
	_handle_movement(direction, current_friction, delta)
	_handle_squash_animation(delta)
	
	# Motion & Ball Pushing
	var pre_vel_x: float = velocity.x
	move_and_slide()
	_handle_ball_pushing(direction, pre_vel_x)
	
#---------------------------------------------------->
# Jump + Gravity Logic
#---------------------------------------------------->
func _handle_jump(delta: float) -> void:
	# Fall / Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		charge_time = 0.0
	# Charge Jump
	elif Input.is_action_pressed("up"):
		charge_time = min(charge_time + delta, max_charge_time)
		charging = true
		
		# Squish animation while charging
		var charge_pct: float = charge_time / max_charge_time
		sprite_squash = Vector2(1.0 + 0.35 * charge_pct, 1.0 - 0.35 * charge_pct)
	# Release Jump
	elif Input.is_action_just_released("up"):
		if is_instance_valid(ball_in_contact) and global_position.distance_to(ball_in_contact.global_position) < 60.0:
			velocity = Vector2.ZERO
			
			# Jump calculations
			var launch_x: float = sign(ball_in_contact.global_position.x - global_position.x)
			if launch_x == 0:
				launch_x = 1.0
			var launch_dir: Vector2 = Vector2(launch_x, -1.0).normalized()
			
			# Apply the jump
			var boost_impulse: float = lerp(min_ball_boost, max_ball_boost, charge_time / max_charge_time)
			ball_in_contact.apply_central_impulse(launch_dir * boost_impulse)
			
			# Recoil animations
			sprite_squash = Vector2(1.25, 0.75)
			ball_in_contact = null
		else:
			# Regular jumping
			velocity.y = lerp(min_jump_v, max_jump_v, charge_time / max_charge_time)
			sprite_squash = Vector2(0.7, 1.35)
		
		charge_time = 0.0
		charging = false

#---------------------------------------------------->
# Horizontal Movement
#---------------------------------------------------->
func _handle_movement(direction: float, current_friction: float, delta: float) -> void:
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)

#---------------------------------------------------->
# Ground Snap + Visual Rotation
#---------------------------------------------------->
func _handle_ground_snap(delta: float) -> void:
	if is_on_floor():
		var target_angle: float = get_floor_normal().angle() + PI / 2.0
		rotation = lerp_angle(rotation, target_angle, 15.0 * delta)
	else:
		rotation = lerp_angle(rotation, 0.0, 10.0 * delta)

#---------------------------------------------------->
# Squash + Stretch Animation
#---------------------------------------------------->
func _handle_squash_animation(delta: float) -> void:
	# Impact squish on landing
	if is_on_floor() and not was_on_floor_last_frame and velocity.y >= 0:
		sprite_squash = Vector2(1.3, 0.7)
	was_on_floor_last_frame = is_on_floor()
	
	# Smoothly spring back to normal when not actively holding jump
	if not charging:
		sprite_squash = sprite_squash.lerp(Vector2.ONE, 12.0 * delta)
	
	# Apply scale & keep feet planted on floor
	sprite.scale = base_scale * sprite_squash
	sprite.position.y = FEET_OFFSET * (1.0 - sprite_squash.y)

#---------------------------------------------------->
# Ball Push Handling
#---------------------------------------------------->
func _handle_ball_pushing(direction: float, pre_vel_x: float) -> void:
	var pushed_ball: bool = false
	
	if not charging:
		ball_in_contact = null
	
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() is RigidBody2D:
			var rb = col.get_collider() as RigidBody2D
			
			var normal = col.get_normal()
			if abs(normal.x) > 0.3 and normal.y > -0.7:
				ball_in_contact = rb
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
