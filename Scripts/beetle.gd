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

# Phantom Camera Shenanigans lol
@onready var pcam_group: PhantomCamera2D = get_parent().get_node_or_null("PcamGroup")
@onready var pcam_player: PhantomCamera2D = get_parent().get_node_or_null("PcamPlayer")
@onready var pcam_ball: PhantomCamera2D = get_parent().get_node_or_null("PcamBall")
@onready var ball: RigidBody2D = get_parent().get_node_or_null("DungBall")
var trauma: float = 0.0
var input_enabled: bool = true

# Ball Kicking
@onready var kick_particles: CPUParticles2D = $KickParticles

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
@export var boost_leniency: float = 8.0

@export_group("Camera Tracking")
@export var detach_distance: float = 380.0
@export var reattach_distance: float = 270.0

#---------------------------------------------------->
# Variables
#---------------------------------------------------->
var charge_time: float = 0.0
var charging: bool = false
var ball_in_contact: RigidBody2D = null
var walk_cycle: float = 0.0

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
	
	if not input_enabled:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.y += gravity * delta
		move_and_slide()
		return
	
	# Camera noise decay
	if trauma > 0.0:
		trauma = max(0.0, trauma - delta * 3.0)
		var shake: float = pow(trauma, 2) * 12.0
		var offset: Vector2 = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		var active_pcam: PhantomCamera2D = pcam_group
		if is_instance_valid(pcam_ball) and pcam_ball.priority > 20:
			active_pcam = pcam_ball
		elif is_instance_valid(pcam_player) and is_instance_valid(pcam_group) and pcam_group.priority < 10:
			active_pcam = pcam_player
		if is_instance_valid(active_pcam):
			active_pcam.emit_noise(Transform2D(0.0, offset))
	
	_handle_camera_tracking()
	_handle_ground_snap(delta)
	_handle_jump(delta)
	
	# Prevent walking while charging a jump
	if charging:
		direction = 0.0
		
	_handle_movement(direction, current_friction, delta)
	_handle_squash_animation(delta)
	_handle_walk_waddle(delta)
	_handle_sprite_facing(direction)
	
	# Motion & Ball Pushing
	var pre_vel_x: float = velocity.x
	move_and_slide()
	_handle_ball_pushing(direction, pre_vel_x)

#---------------------------------------------------->
# Camera Detach & Pan Tracking
#---------------------------------------------------->
func _handle_camera_tracking() -> void:
	if not is_instance_valid(ball) or not is_instance_valid(pcam_group):
		return
	
	var dist: float = global_position.distance_to(ball.global_position)
	
	# SHIFT: Pan across map to inspect where the ball is
	if Input.is_key_pressed(KEY_SHIFT):
		if is_instance_valid(pcam_ball):
			pcam_ball.priority = 25
	else:
		if is_instance_valid(pcam_ball):
			pcam_ball.priority = 0
		
		# Detach if ball rolled down a hill or was kicked too far away
		if dist > detach_distance:
			pcam_group.priority = 5   # Drops below PcamPlayer (priority 10)
		elif dist < reattach_distance:
			pcam_group.priority = 15  # Re-attaches to frame both

#---------------------------------------------------->
# Ball Interaction & Detection Helpers
#---------------------------------------------------->
func is_on_top_of_ball(target_ball: RigidBody2D) -> bool:
	if not is_instance_valid(target_ball):
		return false
	var dx: float = abs(global_position.x - target_ball.global_position.x)
	var is_above: bool = global_position.y < target_ball.global_position.y - 10.0
	if dx < 28.0 and is_above:
		return true
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() == target_ball and col.get_normal().y < -0.5:
			return true
	return false

func is_in_zone(target_ball: RigidBody2D) -> bool:
	if not is_instance_valid(target_ball):
		return false
	if is_on_top_of_ball(target_ball):
		return false
	
	var b_radius: float = 29.0
	var b_col = target_ball.get_node_or_null("CollisionShape2D")
	if is_instance_valid(b_col) and b_col.shape is CircleShape2D:
		b_radius = b_col.shape.radius
	
	var closest_pt = Vector2(
		clamp(target_ball.global_position.x, global_position.x - 10.0, global_position.x + 10.0),
		clamp(target_ball.global_position.y, global_position.y - 15.0, global_position.y + 15.0)
	)
	var surface_gap: float = closest_pt.distance_to(target_ball.global_position) - b_radius
	
	var space_state = get_world_2d().direct_space_state
	var ray_query = PhysicsRayQueryParameters2D.create(global_position, target_ball.global_position, 1)
	var terrain_blocking = not space_state.intersect_ray(ray_query).is_empty()
	
	return (surface_gap <= boost_leniency or ball_in_contact == target_ball) and not terrain_blocking

func _handle_sprite_facing(direction: float) -> void:
	var target_ball: RigidBody2D = ball if is_instance_valid(ball) else ball_in_contact
	var in_zone: bool = is_in_zone(target_ball)
	
	if in_zone:
		# Dung beetle in real life: flips upside down on its head, back legs against the ball
		sprite.flip_v = true
		sprite.flip_h = target_ball.global_position.x > global_position.x
	else:
		sprite.flip_v = false
		if direction != 0.0:
			sprite.flip_h = direction < 0.0

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
		var target_ball: RigidBody2D = ball if is_instance_valid(ball) else ball_in_contact
		var can_boost: bool = is_in_zone(target_ball)
		
		if can_boost:
			velocity = Vector2.ZERO
			
			# Jump calculations
			var launch_x: float = sign(target_ball.global_position.x - global_position.x)
			if launch_x == 0:
				launch_x = 1.0
			var launch_dir: Vector2 = Vector2(launch_x, -1.0).normalized()
			
			# Apply the jump
			var boost_impulse: float = lerp(min_ball_boost, max_ball_boost, charge_time / max_charge_time)
			target_ball.apply_central_impulse(launch_dir * boost_impulse)
			add_shake(lerp(0.35, 0.85, charge_time / max_charge_time))
			
			# Apply particles at exact contact interface relative to beetle
			var b_radius_pt: float = 31.0
			var b_shape_pt = target_ball.get_node_or_null("CollisionShape2D")
			if is_instance_valid(b_shape_pt) and b_shape_pt.shape is CircleShape2D:
				b_radius_pt = b_shape_pt.shape.radius
			var dir_from_ball: Vector2 = (global_position - target_ball.global_position).normalized()
			var ball_surface_pt: Vector2 = target_ball.global_position + dir_from_ball * b_radius_pt
			kick_particles.position = to_local(ball_surface_pt)
			kick_particles.direction = Vector2(-launch_x * 0.4, -1.0).normalized()
			kick_particles.restart()
			kick_particles.emitting = true
			
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
	
	# Jitter at max charge
	if charging and charge_time >= max_charge_time:
		var jitter_amount: float = 1.8
		sprite.offset = Vector2(
			randf_range(-jitter_amount, jitter_amount),
			randf_range(-jitter_amount, jitter_amount)
		)
	else:
		sprite.offset = Vector2.ZERO
	
	# Apply scale & keep feet planted on floor
	sprite.scale = base_scale * sprite_squash
	sprite.position.y = FEET_OFFSET * (1.0 - sprite_squash.y)

#---------------------------------------------------->
# Walking Tilt / Waddle Animation
#---------------------------------------------------->
func _handle_walk_waddle(delta: float) -> void:
	var is_walking: bool = is_on_floor() and abs(velocity.x) > 15.0 and not charging
	if is_walking:
		var speed_factor: float = clamp(abs(velocity.x) / speed, 0.6, 1.4)
		walk_cycle += delta * 18.0 * speed_factor
		var target_tilt: float = sin(walk_cycle) * deg_to_rad(9.0)
		sprite.rotation = lerp_angle(sprite.rotation, target_tilt, 18.0 * delta)
	else:
		walk_cycle = 0.0
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, 14.0 * delta)

#---------------------------------------------------->
# Ball Push Handling
#---------------------------------------------------->
func _handle_ball_pushing(direction: float, pre_vel_x: float) -> void:
	var pushed_ball: bool = false
	
	if not charging:
		ball_in_contact = null
	
	# Cannot push the ball while on top of it
	if is_on_top_of_ball(ball):
		return
	
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

func add_shake(amount: float) -> void:
	trauma = min(trauma + amount, 1.0)
