extends Control

@onready var play_again_btn: Button = $UI/VBoxContainer/ButtonGroup/PlayAgainButton
@onready var menu_btn: Button = $UI/VBoxContainer/ButtonGroup/MenuButton
@onready var quit_btn: Button = $UI/VBoxContainer/ButtonGroup/QuitButton
@onready var content: Control = $UI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if is_instance_valid(play_again_btn):
		play_again_btn.pressed.connect(_on_play_again_pressed)
	if is_instance_valid(menu_btn):
		menu_btn.pressed.connect(_on_menu_pressed)
	if is_instance_valid(quit_btn):
		quit_btn.pressed.connect(_on_quit_pressed)
		
	# Smooth fade-in entrance
	content.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(content, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _on_play_again_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
