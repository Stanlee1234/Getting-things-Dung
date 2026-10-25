extends RigidBody2D

#---------------------------------------------------->
# Height Tiers & Office Milestones
#---------------------------------------------------->
const TIERS = [
	{
		"threshold_up": 120.0,
		"threshold_down": 230.0,
	},
	{
		"threshold_up": -140.0,
		"threshold_down": -30.0,
	},
	{
		"threshold_up": -450.0,
		"threshold_down": -320.0,
	}
]

var current_tier: int = 0
const BALL_RADIUS: float = 29.0
var prev_velocity: Vector2 = Vector2.ZERO
var last_contact_pos: Vector2 = Vector2.ZERO
var last_contact_normal: Vector2 = Vector2.UP
var pending_demote: bool = false
var coworker_event_triggered: bool = false
var is_held: bool = false
var held_position: Vector2 = Vector2.ZERO
var highest_y_since_ground: float = 9999.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var land_particles: CPUParticles2D = $LandParticles
@onready var paper_drop_particles: CPUParticles2D = $PaperDropParticles
@onready var paper_burst_particles: CPUParticles2D = $PaperBurstParticles

@onready var beetle = get_parent().get_node_or_null("Beetle")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	highest_y_since_ground = global_position.y

func set_held(held: bool) -> void:
	if is_held == held:
		return
	is_held = held
	if is_held:
		held_position = global_position
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if is_held:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		var t = state.transform
		t.origin = held_position
		state.transform = t
		return

	if state.get_contact_count() > 0:
		last_contact_pos = state.get_contact_collider_position(0)
		last_contact_normal = state.get_contact_local_normal(0)
	else:
		last_contact_pos = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	prev_velocity = linear_velocity
	_check_height_tiers()
	_check_coworker_zone()
	if not is_held:
		highest_y_since_ground = min(highest_y_since_ground, global_position.y)

func _check_coworker_zone() -> void:
	if coworker_event_triggered:
		return
	var game = get_parent()
	if not is_instance_valid(game):
		return
	var cw_area = game.get_node_or_null("CoworkerArea/Area2D")
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
	# 1. Check for Climbing / Advancing Tiers (moving up in negative Y)
	if current_tier < TIERS.size():
		var next_tier = TIERS[current_tier]
		if global_position.y <= next_tier.threshold_up:
			_advance_tier()
			return
			
	# 2. Check for Falling Down (plummeting past the lower layer threshold)
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
	
	# 3. Juicy ball growth to 0.18 scale (less than 0.2 scale)
	var grow_tween = create_tween().set_parallel(true)
	grow_tween.tween_property(sprite, "scale", Vector2(0.18, 0.18), 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	
	# Expand collision shape proportionally (29.0 * (0.18 / 0.15) = 34.8)
	if is_instance_valid(col_shape) and col_shape.shape is CircleShape2D:
		grow_tween.tween_property(col_shape.shape, "radius", 34.8, 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
	
	# 4. Impact screen shake
	if is_instance_valid(beetle) and beetle.has_method("add_shake"):
		beetle.add_shake(0.7)

func _advance_tier() -> void:
	current_tier += 1
	
	# Paper drop burst from above current ball position
	if is_instance_valid(paper_drop_particles):
		paper_drop_particles.position = Vector2(0, -45.0)
		paper_drop_particles.restart()
		paper_drop_particles.emitting = true
	
	# Boom screen shake
	if is_instance_valid(beetle):
		beetle.add_shake(0.65)

func _demote_tier() -> void:
	pending_demote = false
	current_tier -= 1
	highest_y_since_ground = global_position.y
	
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
