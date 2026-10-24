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

@onready var sprite: Sprite2D = $Sprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var land_particles: CPUParticles2D = $LandParticles
@onready var paper_drop_particles: CPUParticles2D = $PaperDropParticles
@onready var paper_burst_particles: CPUParticles2D = $PaperBurstParticles

@onready var beetle = get_parent().get_node_or_null("Beetle")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() > 0:
		last_contact_pos = state.get_contact_collider_position(0)
		last_contact_normal = state.get_contact_local_normal(0)
	else:
		last_contact_pos = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	prev_velocity = linear_velocity
	_check_height_tiers()

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
	
	# Loose papers flying everywhere from current ball position!
	if is_instance_valid(paper_burst_particles):
		paper_burst_particles.position = Vector2.ZERO
		paper_burst_particles.restart()
		paper_burst_particles.emitting = true
	
	# Heavy penalty boom shake
	if is_instance_valid(beetle):
		beetle.add_shake(0.95)

#---------------------------------------------------->
# Landing Slam Impact
#---------------------------------------------------->
func _on_body_entered(_body: Node) -> void:
	# Trigger demote burst if ball landed after falling below threshold
	if pending_demote:
		_demote_tier()
		
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
