extends CanvasLayer

@onready var panel: PanelContainer = $Control/PanelContainer
@onready var speaker_label: Label = $Control/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/SpeakerLabel
@onready var message_label: Label = $Control/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/MessageLabel
@onready var icon_label: Label = $Control/PanelContainer/MarginContainer/HBoxContainer/IconLabel

var is_showing: bool = false
var tween: Tween = null

func _ready() -> void:
	# Start off-screen
	panel.position.y = -100.0
	panel.modulate.a = 0.0

func show_dialogue(speaker: String = "Coworker Dave (Accounting)", message: String = "More paperwork for you! Let's circle back by EOD.", duration: float = 4.5) -> void:
	if is_showing and tween and tween.is_valid():
		tween.kill()
	
	is_showing = true
	speaker_label.text = speaker
	message_label.text = message
	
	panel.position.y = -100.0
	panel.modulate.a = 0.0
	
	tween = create_tween()
	# Spring slide-down from the top
	tween.tween_property(panel, "position:y", 20.0, 0.45)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
	
	# Stay for duration
	tween.tween_interval(duration)
	
	# Slide back up
	tween.tween_property(panel, "position:y", -100.0, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.25)
	
	tween.finished.connect(func(): is_showing = false)
