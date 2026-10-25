extends CanvasLayer

@onready var bg: ColorRect = $BlackOverlay
@onready var content: Control = $ContentContainer
@onready var play_again_btn: Button = $ContentContainer/VBoxContainer/PlayAgainButton
@onready var quit_btn: Button = $ContentContainer/VBoxContainer/QuitButton

signal credits_completed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	bg.modulate.a = 0.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.modulate.a = 0.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if is_instance_valid(play_again_btn):
		play_again_btn.pressed.connect(_on_play_again_pressed)
	if is_instance_valid(quit_btn):
		quit_btn.pressed.connect(_on_quit_pressed)

func start_fade_to_black(duration: float = 1.5) -> void:
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func show_credits(duration: float = 1.5) -> void:
	start_fade_to_black(1.0)
	await get_tree().create_timer(1.2).timeout
	
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(content, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _on_play_again_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
