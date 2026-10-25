extends CharacterBody2D

#---------------------------------------------------->
# Import Variables
#---------------------------------------------------->
@onready var sprite_regular: Sprite2D = $BeetleRegular
@onready var sprite_handstand: Sprite2D = $BeetleHandstand
@onready var regular_hitbox: CollisionShape2D = $RegularHitbox
@onready var handstand_hitbox: CollisionShape2D = $HandstandHitbox

@onready var sprite: Sprite2D = $BeetleRegular
@onready var base_scale_regular: Vector2 = $BeetleRegular.scale
@onready var base_scale_handstand: Vector2 = $BeetleHandstand.scale
@onready var base_pos_regular: Vector2 = $BeetleRegular.position
@onready var base_pos_handstand: Vector2 = $BeetleHandstand.position
@onready var handstand_hitbox_base_pos: Vector2 = $HandstandHitbox.position

var is_handstand: bool = false
var handstand_timer: float = 0.0

# Squishing animation variables
var sprite_squash: Vector2 = Vector2.ONE
var was_on_floor_last_frame: bool = true
const FEET_OFFSET: float = 14.0

# Phantom Camera Shenanigans lol
@onready var pcam_group: PhantomCamera2D = get_parent().get_node_or_null("PcamGroup")
@onready var pcam_player: PhantomCamera2D = get_parent().get_node_or_null("PcamPlayer")
@onready var pcam_ball: PhantomCamera2D = get_parent().get_node_or_null("PcamBall")
@onready var ball: RigidBody2D = get_parent().get_node_or_null("DungBall")
var trauma: float = 0.0
var input_enabled: bool = true

# Ball Kicking
@onready var kick_particles: CPUParticles2D = $KickParticles

const SFX_JUMP = preload("res://Assets/sfx/jump.tres")
const SFX_KICK = preload("res://Assets/sfx/kick.tres")
const SFX_CHARGE = preload("res://Assets/sfx/charge.tres")
const SFX_LAND = preload("res://Assets/sfx/land.tres")

var sfx_player: AudioStreamPlayer2D
var charge_sfx_player: AudioStreamPlayer2D

#---------------------------------------------------->
# Export Variables
#---------------------------------------------------->
@export_group("General")
@export var speed: float = 160.0
@export var accel: float = 1200.0
@export var friction: float = 1400.0
@export var ball_friction: float = 1400.0
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
	_set_handstand_mode(false)
	
	sfx_player = AudioStreamPlayer2D.new()
	sfx_player.name = "BeetleSfxPlayer"
	add_child(sfx_player)
	
	charge_sfx_player = AudioStreamPlayer2D.new()
	charge_sfx_player.name = "BeetleChargeSfxPlayer"
	charge_sfx_player.stream = SFX_CHARGE
	add_child(charge_sfx_player)

func play_sfx(stream: AudioStream, vol: float = 0.0, pitch: float = 1.0) -> void:
	if stream and is_instance_valid(sfx_player):
		sfx_player.stream = stream
		sfx_player.volume_db = vol
		sfx_player.pitch_scale = pitch
		sfx_player.play()

func _set_handstand_mode(active: bool) -> void:
	if is_handstand == active:
		return
	is_handstand = active
	
	if is_handstand:
		sprite_regular.visible = false
		sprite_regular.rotation = 0.0
		sprite_regular.offset = Vector2.ZERO
		sprite_regular.position = base_pos_regular
		sprite_regular.scale = base_scale_regular
		
		sprite_handstand.visible = true
		sprite_handstand.rotation = 0.0
		sprite_handstand.offset = Vector2.ZERO
		sprite_handstand.position = base_pos_handstand
		sprite_handstand.scale = base_scale_handstand
		
		regular_hitbox.disabled = true
		handstand_hitbox.disabled = false
		sprite = sprite_handstand
	else:
		sprite_handstand.visible = false
		sprite_handstand.rotation = 0.0
		sprite_handstand.offset = Vector2.ZERO
		sprite_handstand.position = base_pos_handstand
		sprite_handstand.scale = base_scale_handstand
		
		sprite_regular.visible = true
		sprite_regular.rotation = 0.0
		sprite_regular.offset = Vector2.ZERO
		sprite_regular.position = base_pos_regular
		sprite_regular.scale = base_scale_regular
		
		regular_hitbox.disabled = false
		handstand_hitbox.disabled = true
		sprite = sprite_regular

func _physics_process(delta: float) -> void:
	if handstand_timer > 0.0:
		handstand_timer = max(0.0, handstand_timer - delta)
		
	var direction: float = Input.get_axis("left", "right")
	var on_ball: bool = is_on_floor() and get_last_slide_collision() and get_last_slide_collision().get_collider() is RigidBody2D
	var current_friction: float = ball_friction if on_ball else friction
	
	if not input_enabled:
		if charging:
			charging = false
			charge_time = 0.0
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
	
	if not charging:
		_handle_sprite_facing(direction)
	_handle_movement(direction, current_friction, delta)
	_handle_squash_animation(delta)
	_handle_walk_waddle(delta)
	
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
	var b_radius: float = 29.0
	var b_col = target_ball.get_node_or_null("CollisionShape2D")
	if is_instance_valid(b_col) and b_col.shape is CircleShape2D:
		b_radius = b_col.shape.radius
	
	var dx: float = abs(global_position.x - target_ball.global_position.x)
	var dy: float = target_ball.global_position.y - global_position.y
	
	# Horizontal check: must be within the top dome of the ball
	if dx > b_radius + 6.0:
		return false
	
	# Vertical check: beetle center must be above ball center and within standing range
	if dy < b_radius * 0.3 or dy > b_radius + 60.0:
		return false
	
	# Check slide collisions: if actively colliding with ball with upward normal
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() == target_ball and col.get_normal().y < -0.3:
			return true
	
	# If resting or falling onto the ball (not standing on an independent floor/ledge below ball top)
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() != target_ball and col.get_normal().y < -0.7:
			if global_position.y > target_ball.global_position.y - b_radius:
				return false
	
	return true

func is_in_zone(target_ball: RigidBody2D) -> bool:
	if not is_instance_valid(target_ball):
		handstand_timer = 0.0
		return false
	if is_on_top_of_ball(target_ball):
		handstand_timer = 0.0
		return false
	
	var space_state = get_world_2d().direct_space_state
	var ray_query = PhysicsRayQueryParameters2D.create(global_position, target_ball.global_position, 1)
	if not space_state.intersect_ray(ray_query).is_empty():
		handstand_timer = 0.0
		return false
	
	var b_radius: float = 29.0
	var b_col = target_ball.get_node_or_null("CollisionShape2D")
	if is_instance_valid(b_col) and b_col.shape is CircleShape2D:
		b_radius = b_col.shape.radius
	
	var closest_pt = Vector2(
		clamp(target_ball.global_position.x, global_position.x - 22.0, global_position.x + 22.0),
		clamp(target_ball.global_position.y, global_position.y - 15.0, global_position.y + 15.0)
	)
	var surface_gap: float = closest_pt.distance_to(target_ball.global_position) - b_radius
	var is_touching: bool = (ball_in_contact == target_ball)
	
	var enter_threshold: float = boost_leniency * 1.5 if charging else boost_leniency
	var exit_threshold: float = boost_leniency * 1.5 if charging else boost_leniency
	
	if is_handstand:
		if charging or is_touching or surface_gap <= exit_threshold or handstand_timer > 0.0:
			if is_touching or surface_gap <= enter_threshold:
				handstand_timer = 0.2
			return true
		return false
	else:
		if is_touching or surface_gap <= enter_threshold:
			handstand_timer = 0.2
			return true
		return false

func _handle_sprite_facing(direction: float) -> void:
	var target_ball: RigidBody2D = ball if is_instance_valid(ball) else ball_in_contact
	var in_zone: bool = is_in_zone(target_ball)
	
	if in_zone:
		_set_handstand_mode(true)
		var ball_is_to_right: bool = target_ball.global_position.x > global_position.x
		sprite_handstand.flip_h = ball_is_to_right
		sprite_handstand.position.x = -base_pos_handstand.x if ball_is_to_right else base_pos_handstand.x
		handstand_hitbox.position.x = -handstand_hitbox_base_pos.x if ball_is_to_right else handstand_hitbox_base_pos.x
		handstand_hitbox.position.y = handstand_hitbox_base_pos.y
	else:
		_set_handstand_mode(false)
		if direction != 0.0:
			var facing_left: bool = (direction < 0.0)
			sprite_regular.flip_h = facing_left

#---------------------------------------------------->
# Jump + Gravity Logic
#---------------------------------------------------->
func _handle_jump(delta: float) -> void:
	var target_ball: RigidBody2D = ball if is_instance_valid(ball) else ball_in_contact

	# Fall / Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		charge_time = 0.0
		if charging:
			charging = false
			if is_instance_valid(charge_sfx_player):
				charge_sfx_player.stop()
	# Charge Jump
	elif Input.is_action_pressed("up"):
		if not charging:
			if is_instance_valid(charge_sfx_player):
				charge_sfx_player.pitch_scale = 0.95
				charge_sfx_player.play()
		charge_time = min(charge_time + delta, max_charge_time)
		charging = true
		if is_instance_valid(charge_sfx_player):
			charge_sfx_player.pitch_scale = 0.95 + 0.35 * (charge_time / max_charge_time)
		
		# Squish animation while charging
		var charge_pct: float = charge_time / max_charge_time
		sprite_squash = Vector2(1.0 + 0.35 * charge_pct, 1.0 - 0.35 * charge_pct)
	# Release Jump
	elif Input.is_action_just_released("up") or charging:
		if is_instance_valid(charge_sfx_player):
			charge_sfx_player.stop()
		var can_boost: bool = is_in_zone(target_ball)
		
		if can_boost:
			velocity = Vector2.ZERO
			play_sfx(SFX_KICK, 1.5, randf_range(0.95, 1.05))
			
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
			handstand_timer = 0.0
		else:
			# Regular jumping
			velocity.y = lerp(min_jump_v, max_jump_v, charge_time / max_charge_time)
			sprite_squash = Vector2(0.7, 1.35)
			play_sfx(SFX_JUMP, -1.0, randf_range(0.95, 1.05))
		
		charge_time = 0.0
		charging = false

#---------------------------------------------------->
# Horizontal Movement
#---------------------------------------------------->
func _handle_movement(direction: float, current_friction: float, delta: float) -> void:
	if charging:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	elif direction != 0.0:
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
		play_sfx(SFX_LAND, -6.0, randf_range(1.2, 1.4))
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
	
	# Apply scale & keep feet planted on floor relative to base position
	var current_base_scale: Vector2 = base_scale_handstand if is_handstand else base_scale_regular
	var current_base_pos: Vector2 = base_pos_handstand if is_handstand else base_pos_regular
	var current_feet_offset: float = 18.0 if is_handstand else FEET_OFFSET
	
	sprite.scale = current_base_scale * sprite_squash
	sprite.position.y = current_base_pos.y + current_feet_offset * (1.0 - sprite_squash.y)

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
	ball_in_contact = null
	
	# Cannot push the ball while on top of it
	var target_ball: RigidBody2D = ball if is_instance_valid(ball) else null
	if is_instance_valid(target_ball) and is_on_top_of_ball(target_ball):
		return
	
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() is RigidBody2D:
			var rb = col.get_collider() as RigidBody2D
			if is_on_top_of_ball(rb):
				continue
			
			var normal = col.get_normal()
			# Pushing must be horizontal from the side; upward contact normals mean standing on top
			if abs(normal.x) > 0.4 and normal.y > -0.3:
				ball_in_contact = rb
				var push_dir: Vector2
				var floor_norm = get_floor_normal()
				if is_on_floor() and floor_norm.length_squared() > 0.5:
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
