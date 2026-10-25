extends Node2D

@onready var trigger_area: Area2D = $Area2D
signal ceo_reached(body: Node2D)

func _ready() -> void:
	add_to_group("ceo_zone")
	if is_instance_valid(trigger_area):
		trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	ceo_reached.emit(body)
	var game = get_tree().root.find_child("game", true, false)
	if not is_instance_valid(game):
		game = get_tree().root.find_child("Game", true, false)
	if is_instance_valid(game) and game.has_method("_on_ceo_desk_body_entered"):
		game._on_ceo_desk_body_entered(body)
