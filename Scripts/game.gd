extends Node2D

@onready var voice_player: AudioStreamPlayer2D = $VoicePlayer
@onready var subtitle_label: Label = $UI/SubtitleLabel
@onready var skip_label: Label = $UI/SkipLabel
@onready var beetle = $Beetle
@onready var control_bubble = $LevelControls

# Preload voice audio files
const INTRO_VOICE = preload("res://Assets/voicelines/introvoiceline1.mp3")

# Timed captions: text changes at playback timestamps (in seconds)
var current_captions: Array = []
var is_intro_playing: bool = false

func _ready() -> void:
	# 1. Pause game world and physics during intro
	process_mode = Node.PROCESS_MODE_ALWAYS
	voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
	$UI.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	# 2. Lock the player and ensure camera snaps to player at start
	beetle.input_enabled = false
	var pcam_group = get_node_or_null("PcamGroup")
	if is_instance_valid(pcam_group):
		pcam_group.priority = 5
	var pcam_player = get_node_or_null("PcamPlayer")
	if is_instance_valid(pcam_player):
		pcam_player.priority = 10
	
	# 3. Define captions for introvoiceline1
	var intro_captions = [
		{"time": 0.0, "text": "Well, howdy there, new hire. Welcome to the bottom floor."},
		{"time": 4.7, "text": "Now don't let your size fool ya, "},
		{"time": 6.7, "text": "just 'cause you're three millimeters tall don't mean you get out of unpaid overtime."},
		{"time": 12.0, "text": "Go on, stretch them little legs out with Left and Right."}
	]
	
	# 4. Start the intro voice
	is_intro_playing = true
	play_voice(INTRO_VOICE, intro_captions)
	voice_player.finished.connect(_on_intro_finished)

func _process(_delta: float) -> void:
	if is_intro_playing:
		_update_subtitles()
		# Let player press Space to skip the intro
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			_on_intro_finished()

# ==========================================
# REUSABLE ONE-PLAYER VOICE SYSTEM
# ==========================================
func play_voice(stream: AudioStream, captions: Array = []) -> void:
	voice_player.stop()
	voice_player.stream = stream
	current_captions = captions
	subtitle_label.text = ""
	voice_player.play()

func _update_subtitles() -> void:
	if current_captions.is_empty():
		return
	var pos = voice_player.get_playback_position()
	for i in range(current_captions.size() - 1, -1, -1):
		if pos >= current_captions[i]["time"]:
			subtitle_label.text = current_captions[i]["text"]
			break

# ==========================================
# GAME START
# ==========================================
func _on_intro_finished() -> void:
	if not is_intro_playing:
		return
	is_intro_playing = false
	voice_player.stop()
	subtitle_label.text = ""
	if is_instance_valid(skip_label):
		skip_label.visible = false
	
	# Unpause the game so the ball falls down from the sky!
	get_tree().paused = false
	
	# Wait around 2 seconds for the ball to fall down before unlocking player movement
	await get_tree().create_timer(2.0).timeout
	
	# Unlock gameplay
	if is_instance_valid(beetle):
		beetle.input_enabled = true
	
	# Pop up the wobbly controls bubble!
	if is_instance_valid(control_bubble):
		control_bubble.pop_up()
