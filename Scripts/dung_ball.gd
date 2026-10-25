extends RigidBody2D

#---------------------------------------------------->
# Height Tiers & Office Milestones
#---------------------------------------------------->
const TIERS = [
	{ # Tier 1: Floor 2 (First climb right)
		"threshold_up": 180.0,
		"threshold_down": 270.0,
		"scale": 0.17,
		"radius": 33.0
	},
	{ # Tier 2: Floor 3 (Wind back left)
		"threshold_up": 40.0,
		"threshold_down": 130.0,
		"scale": 0.19,
		"radius": 36.5
	},
	{ # Tier 3: Floor 4 (Climbing upper left)
		"threshold_up": -180.0,
		"threshold_down": -50.0,
		"scale": 0.21,
		"radius": 40.5
	},
	{ # Tier 4: Floor 5 (Climbing the Big Ramp)
		"threshold_up": -450.0,
		"threshold_down": -300.0,
		"scale": 0.23,
		"radius": 44.5
	},
	{ # Tier 5: Floor 6 (CEO Summit Roof)
		"threshold_up": -700.0,
		"threshold_down": -550.0,
		"scale": 0.26,
		"radius": 50.0
	}
]

const BASE_SCALE: Vector2 = Vector2(0.15, 0.15)
const BASE_RADIUS: float = 29.0
var current_tier: int = 0
const BALL_RADIUS: float = 29.0
var prev_velocity: Vector2 = Vector2.ZERO
var last_contact_pos: Vector2 = Vector2.ZERO
var last_contact_normal: Vector2 = Vector2.UP
var pending_demote: bool = false
var coworker_event_triggered: bool = false
var highest_y_since_ground: float = 9999.0
var spawn_settled: bool = false
var size_tween: Tween = null
var lock_platform_pos: Vector2 = Vector2.ZERO

const SFX_LAND = preload("res://Assets/sfx/land.tres")
const SFX_TIER_UP = preload("res://Assets/sfx/tier_up.tres")

@onready var sprite: Sprite2D = $Sprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var land_particles: CPUParticles2D = $LandParticles
@onready var paper_drop_particles: CPUParticles2D = $PaperDropParticles
@onready var paper_burst_particles: CPUParticles2D = $PaperBurstParticles

@onready var beetle = get_parent().get_node_or_null("Beetle")
var sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	sfx_player = AudioStreamPlayer2D.new()
	sfx_player.name = "BallSfxPlayer"
	add_child(sfx_player)
	body_entered.connect(_on_body_entered)
	highest_y_since_ground = global_position.y

func play_sfx(stream: AudioStream, vol: float = 0.0, pitch: float = 1.0) -> void:
	if stream and is_instance_valid(sfx_player):
		sfx_player.stream = stream
		sfx_player.volume_db = vol
		sfx_player.pitch_scale = pitch
		sfx_player.play()

func set_held(_held: bool) -> void:
	pass

func is_player_standing_on() -> bool:
	if not is_instance_valid(beetle):
		return false
	if beetle.has_method("is_on_top_of_ball"):
		return beetle.is_on_top_of_ball(self)
	var b_radius: float = col_shape.shape.radius if (is_instance_valid(col_shape) and col_shape.shape is CircleShape2D) else BASE_RADIUS
	var dx: float = abs(beetle.global_position.x - global_position.x)
	var dy: float = global_position.y - beetle.global_position.y
	return dx <= b_radius + 6.0 and dy >= b_radius * 0.3 and dy <= b_radius + 60.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() > 0:
		last_contact_pos = state.get_contact_collider_position(0)
		last_contact_normal = state.get_contact_local_normal(0)
	else:
		last_contact_pos = Vector2.ZERO

	# Stable platform: when beetle stands on top of the ball, freeze ball so it doesn't roll or slide
	if is_player_standing_on():
		var b_radius: float = col_shape.shape.radius if (is_instance_valid(col_shape) and col_shape.shape is CircleShape2D) else BASE_RADIUS
		var space_state = get_world_2d().direct_space_state
		var b_pos: Vector2 = state.transform.origin
		
		var ray_down = PhysicsRayQueryParameters2D.create(b_pos, b_pos + Vector2(0, b_radius + 8.0), 1)
		var ray_dl = PhysicsRayQueryParameters2D.create(b_pos, b_pos + Vector2(-b_radius * 0.7, b_radius * 0.7 + 6.0), 1)
		var ray_dr = PhysicsRayQueryParameters2D.create(b_pos, b_pos + Vector2(b_radius * 0.7, b_radius * 0.7 + 6.0), 1)
		
		var is_grounded: bool = not space_state.intersect_ray(ray_down).is_empty() \
			or not space_state.intersect_ray(ray_dl).is_empty() \
			or not space_state.intersect_ray(ray_dr).is_empty()
		
		if is_grounded:
			if lock_platform_pos == Vector2.ZERO:
				lock_platform_pos = b_pos
			state.transform = Transform2D(state.transform.get_rotation(), lock_platform_pos)
			state.linear_velocity = Vector2.ZERO
			state.angular_velocity = 0.0
		else:
			lock_platform_pos = Vector2.ZERO
			state.linear_velocity.x = 0.0
			state.angular_velocity = 0.0
	else:
		lock_platform_pos = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	prev_velocity = linear_velocity
	_check_height_tiers()
	_check_coworker_zone()
	if spawn_settled:
		highest_y_since_ground = min(highest_y_since_ground, global_position.y)

func _check_coworker_zone() -> void:
	if coworker_event_triggered:
		return
	var game = get_parent()
	if not is_instance_valid(game):
		return
	var cw_area = game.get_node_or_null("NarrationArea/CoworkerArea")
	if not is_instance_valid(cw_area):
		cw_area = game.get_node_or_null("CoworkerArea/Area2D")
	if not is_instance_valid(cw_area):
		cw_area = game.find_child("CoworkerArea", true, false)
	if is_instance_valid(cw_area):
		var cw_col = cw_area.get_node_or_null("CollisionShape2D")
		if is_instance_valid(cw_col) and cw_col.shape is RectangleShape2D:
			var half_size: Vector2 = cw_col.shape.size * 0.5
			var center: Vector2 = cw_col.global_position
			if abs(global_position.x - center.x) <= (half_size.x + BALL_RADIUS) and abs(global_position.y - center.y) <= (half_size.y + BALL_RADIUS):
				trigger_coworker_event()

#---------------------------------------------------->
# Height Tracking & Ball Evolution
#---------------------------------------------------->
func _check_height_tiers() -> void:
	if not spawn_settled:
		return
		
	# 1. Check for Climbing / Advancing Tiers (moving up in negative Y)
	if current_tier < TIERS.size():
		var next_tier = TIERS[current_tier]
		if global_position.y <= next_tier.threshold_up:
			_advance_tier()
			return
			
	# 2. Check for Falling Down (plummeting past lower floor thresholds)
	if current_tier > 0:
		var current_tier_data = TIERS[current_tier - 1]
		if global_position.y > current_tier_data.threshold_down:
			pending_demote = true
	
	# Trigger demote once ball makes contact with the lower floor or stops
	if pending_demote and (last_contact_pos != Vector2.ZERO or linear_velocity.length() < 50.0):
		_demote_tier()

func trigger_coworker_event() -> void:
	if coworker_event_triggered:
		return
	coworker_event_triggered = true
	
	# 1. Paper rain / burst from above the ball
	if is_instance_valid(paper_drop_particles):
		paper_drop_particles.position = Vector2(0, -45.0)
		paper_drop_particles.restart()
		paper_drop_particles.emitting = true
	
	# 2. Impact screen shake
	if is_instance_valid(beetle) and beetle.has_method("add_shake"):
		beetle.add_shake(0.7)

func _apply_size_change(target_scale: Vector2, target_radius: float, is_growing: bool) -> void:
	if is_instance_valid(size_tween) and size_tween.is_valid():
		size_tween.kill()
	size_tween = create_tween().set_parallel(true)
	var trans = Tween.TRANS_BACK if is_growing else Tween.TRANS_QUAD
	size_tween.tween_property(sprite, "scale", target_scale, 0.35)\
		.set_trans(trans)\
		.set_ease(Tween.EASE_OUT)
	
	if is_instance_valid(col_shape) and col_shape.shape is CircleShape2D:
		size_tween.tween_property(col_shape.shape, "radius", target_radius, 0.35)\
			.set_trans(trans)\
			.set_ease(Tween.EASE_OUT)

func _advance_tier() -> void:
	current_tier += 1
	var target_scale_val: float = TIERS[current_tier - 1]["scale"]
	var target_radius: float = TIERS[current_tier - 1]["radius"]
	_apply_size_change(Vector2(target_scale_val, target_scale_val), target_radius, true)
	play_sfx(SFX_TIER_UP, 0.0)
	
	# Paper drop burst from above current ball position
	if is_instance_valid(paper_drop_particles):
		paper_drop_particles.position = Vector2(0, -45.0)
		paper_drop_particles.restart()
		paper_drop_particles.emitting = true
	
	# Screen shake
	if is_instance_valid(beetle):
		beetle.add_shake(0.65)

func _demote_tier() -> void:
	pending_demote = false
	
	# Determine how many floors down the ball has plummeted
	while current_tier > 0 and global_position.y > TIERS[current_tier - 1].threshold_down:
		current_tier -= 1
		
	highest_y_since_ground = global_position.y
	
	# Reduce size to match the lower floor
	var target_scale_val: float = BASE_SCALE.x
	var target_radius: float = BASE_RADIUS
	if current_tier > 0:
		target_scale_val = TIERS[current_tier - 1]["scale"]
		target_radius = TIERS[current_tier - 1]["radius"]
	_apply_size_change(Vector2(target_scale_val, target_scale_val), target_radius, false)
	
	# Loose papers flying everywhere from current ball position!
	if is_instance_valid(paper_burst_particles):
		paper_burst_particles.position = Vector2.ZERO
		paper_burst_particles.restart()
		paper_burst_particles.emitting = true
	
	# Heavy penalty boom shake
	if is_instance_valid(beetle):
		beetle.add_shake(0.95)
		
	# Play drop voice line
	var game = get_parent()
	if is_instance_valid(game) and game.has_method("play_drop_voiceline"):
		game.play_drop_voiceline()

#---------------------------------------------------->
# Landing Slam Impact
#---------------------------------------------------->
func _on_body_entered(_body: Node) -> void:
	# Prevent spawn fall from triggering sarcastic drop voicelines
	if not spawn_settled:
		spawn_settled = true
		highest_y_since_ground = global_position.y
		return

	# Trigger demote burst if ball landed after falling below threshold
	if pending_demote:
		_demote_tier()
	else:
		# Check if the ball plummeted a substantial height and slammed down
		var fall_dist: float = global_position.y - highest_y_since_ground
		if fall_dist > 120.0 and prev_velocity.y > 140.0:
			var game = get_parent()
			if is_instance_valid(game) and game.has_method("play_drop_voiceline"):
				game.play_drop_voiceline()
				
	# Reset peak tracker once grounded
	highest_y_since_ground = global_position.y
		
	var impact_speed: float = prev_velocity.length()
	
	# Drops or hard hits
	if impact_speed > 160.0:
		var impact_pct: float = clamp((impact_speed - 120.0) / 450.0, 0.15, 1.0)
		play_sfx(SFX_LAND, clamp((impact_speed - 160.0) / 200.0, 0.0, 3.0), randf_range(0.9, 1.1))
		
		# Screen shake
		if is_instance_valid(beetle):
			beetle.add_shake(impact_pct * 0.6)
		
		# Burst landing dust at the physical contact point relative to ball
		if is_instance_valid(land_particles):
			if last_contact_pos != Vector2.ZERO:
				land_particles.position = to_local(last_contact_pos)
			else:
				land_particles.position = Vector2(0, BALL_RADIUS)
			if last_contact_normal != Vector2.ZERO:
				land_particles.direction = last_contact_normal
			land_particles.restart()
			land_particles.emitting = true
