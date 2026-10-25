extends Node2D

@export_group("Launch Settings")
@export var launch_velocity: Vector2 = Vector2(75.0, -680.0)
@export var thrust_distance: float = 65.0

@export_group("Timing Settings")
@export var active_loop: bool = true
@export var interval: float = 2.5
@export var initial_delay: float = 0.0
@export var windup_time: float = 0.3
@export var hold_time: float = 0.2
@export var retract_time: float = 0.35

var is_winding_up: bool = false
var is_extended: bool = false

var originx: float = 0.0
var originy: float = 0.0

@onready var trigger_area: Area2D = $TriggerArea
@onready var worm_sprite: CanvasItem = _get_worm_sprite()

signal ball_launched(ball: RigidBody2D)

func _get_worm_sprite() -> CanvasItem:
	if has_node("Sprite2D"):
		return $Sprite2D
	for child in get_children():
		if child is Sprite2D or child is Polygon2D:
			return child
	return self

func _ready() -> void:
	add_to_group("worms")
	worm_sprite = _get_worm_sprite()
	originx = worm_sprite.position.x
	originy = worm_sprite.position.y
	worm_sprite.position = Vector2(originx, originy)
	
	trigger_area.body_entered.connect(_on_body_entered)
	
	if active_loop:
		_start_interval_loop()

func trigger_strike() -> void:
	if not is_winding_up and not is_extended:
		_do_launch_cycle()

func _start_interval_loop() -> void:
	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay).timeout
		if not is_inside_tree() or not active_loop:
			return
	
	while is_inside_tree() and active_loop:
		await _do_launch_cycle()
		if not is_inside_tree() or not active_loop:
			return
		
		if interval > 0.0:
			await get_tree().create_timer(interval).timeout
			if not is_inside_tree() or not active_loop:
				return

func _do_launch_cycle() -> void:
	is_winding_up = true
	
	# 1. Windup rumble/shake
	var windup_tween = create_tween()
	var shakes = 4
	for i in range(shakes):
		var rx = randf_range(-2.5, 2.5)
		windup_tween.tween_property(worm_sprite, "position:x", originx + rx, windup_time / shakes)
	windup_tween.tween_property(worm_sprite, "position:x", originx, 0.02)
	
	await windup_tween.finished
	if not is_inside_tree():
		return
	is_winding_up = false
	is_extended = true
	
	# 2. Thrust UP
	var thrust_tween = create_tween().set_parallel(true)
	thrust_tween.tween_property(worm_sprite, "position:y", originy - thrust_distance, 0.06)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)
	
	# Strike all overlapping bodies in trigger area
	_check_and_launch_bodies()
	
	await thrust_tween.finished
	if not is_inside_tree():
		return
	
	# 3. Brief hold at peak
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time).timeout
		if not is_inside_tree():
			return
	
	# 4. Retract back down to original position
	var retract_tween = create_tween().set_parallel(true)
	retract_tween.tween_property(worm_sprite, "position:y", originy, retract_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	retract_tween.tween_property(worm_sprite, "position:x", originx, retract_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	await retract_tween.finished
	if not is_inside_tree():
		return
	
	worm_sprite.position = Vector2(originx, originy)
	is_extended = false

func _on_body_entered(body: Node2D) -> void:
	# If body enters during strike or extension, launch it
	if is_extended:
		_launch_body(body)

func _check_and_launch_bodies() -> void:
	for body in trigger_area.get_overlapping_bodies():
		_launch_body(body)

func _launch_body(body: Node) -> void:
	if body is RigidBody2D:
		body.linear_velocity = launch_velocity
		body.angular_velocity = randf_range(-6.0, 6.0)
		ball_launched.emit(body)
		_apply_screen_shake()
	elif body is CharacterBody2D:
		body.velocity = launch_velocity * 0.85
		_apply_screen_shake()

func _apply_screen_shake() -> void:
	if not is_inside_tree():
		return
	var beetle = get_tree().root.find_child("Beetle", true, false)
	if is_instance_valid(beetle) and beetle.has_method("add_shake"):
		beetle.add_shake(0.65)
