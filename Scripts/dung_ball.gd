extends RigidBody2D

var prev_velocity: Vector2 = Vector2.ZERO
@onready var land_particles: CPUParticles2D = $LandParticles
@onready var beetle = get_parent().get_node_or_null("Beetle")

func _physics_process(_delta: float) -> void:
	# Store velocity right before Godot's solver zeroes it on impact
	prev_velocity = linear_velocity

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node) -> void:
	var impact_speed: float = prev_velocity.length()
	
	# Ignore gentle rolling (only trigger on drops / hard hits above 110 px/s)
	if impact_speed > 510.0:
		var impact_pct: float = clamp((impact_speed - 100.0) / 450.0, 0.15, 1.0)
		
		# Screen shake
		if is_instance_valid(beetle):
			beetle.add_shake(impact_pct * 0.6)
		
		# Burst particles at the base of the ball
		if is_instance_valid(land_particles):
			land_particles.global_position = global_position + Vector2(0, 24)
			land_particles.restart()
			land_particles.emitting = true
