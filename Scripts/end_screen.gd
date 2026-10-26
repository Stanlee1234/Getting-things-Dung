extends Control

@onready var play_again_btn: Button = $UI/VBoxContainer/ButtonGroup/PlayAgainButton
@onready var menu_btn: Button = $UI/VBoxContainer/ButtonGroup/MenuButton
@onready var quit_btn: Button = $UI/VBoxContainer/ButtonGroup/QuitButton
@onready var content: Control = $UI
@onready var clear_time_label: Label = $UI/VBoxContainer/TimeContainer/ClearTimeLabel
@onready var best_time_label: Label = $UI/VBoxContainer/TimeContainer/BestTimeLabel

const GameClass = preload("res://Scripts/game.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if is_instance_valid(play_again_btn):
		play_again_btn.pressed.connect(_on_play_again_pressed)
	if is_instance_valid(menu_btn):
		menu_btn.pressed.connect(_on_menu_pressed)
	if is_instance_valid(quit_btn):
		quit_btn.pressed.connect(_on_quit_pressed)

	# Display speedrun time
	var last_time: float = GameClass.final_speedrun_time
	var pb: float = GameClass.load_best_time()
	var is_pb: bool = GameClass.is_last_run_pb
	
	if last_time > 0.0:
		if is_instance_valid(clear_time_label):
			clear_time_label.text = "CLEAR TIME: " + GameClass.format_time(last_time)
		if is_instance_valid(best_time_label):
			if is_pb:
				best_time_label.text = "★ NEW PERSONAL BEST! ★"
				best_time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			elif pb > 0.0:
				best_time_label.text = "PERSONAL BEST: " + GameClass.format_time(pb)
			else:
				best_time_label.visible = false
	else:
		if is_instance_valid(clear_time_label):
			clear_time_label.visible = false
		if is_instance_valid(best_time_label):
			if pb > 0.0:
				best_time_label.text = "PERSONAL BEST: " + GameClass.format_time(pb)
			else:
				best_time_label.visible = false
		
	# Smooth fade-in entrance
	content.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(content, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			_on_play_again_pressed()

func _on_play_again_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
