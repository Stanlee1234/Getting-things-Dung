extends Node2D

@onready var voice_player: AudioStreamPlayer2D = $VoicePlayer
@onready var subtitle_label: Label = $UI/SubtitleLabel
@onready var skip_label: Label = $UI/SkipLabel
@onready var beetle = $Beetle
@onready var control_bubble = $LevelControls
@onready var jump_controls = get_node_or_null("JumpControls")
@onready var ball_controls = get_node_or_null("BallControls")

# Preload voice audio files
const INTRO_VOICE = preload("res://Assets/voicelines/introvoiceline1.mp3")
const INTRO_VOICE_2 = preload("res://Assets/voicelines/introvoiceline2.mp3")
const INTRO_VOICE_3 = preload("res://Assets/voicelines/introvoiceline3.mp3")

const DROP_VOICES = [
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline1.mp3"),
		"captions": [
			{"time": 0.0, "text": "Almost had it that time."},
			{"time": 2.2, "text": "And by almost, I mean you weren't even close..."},
			{"time": 5.2, "text": "...and now your ball's in the basement."}
		]
	},
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline2.mp3"),
		"captions": [
			{"time": 0.0, "text": "There she goes."},
			{"time": 1.4, "text": "All that huffing and puffing gone in three seconds."}
		]
	},
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline3.mp3"),
		"captions": [
			{"time": 0.0, "text": "Look at the bright side, son."},
			{"time": 2.4, "text": "Walking all the way back down is way faster than pushing it up."}
		]
	},
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline4.mp3"),
		"captions": [
			{"time": 0.0, "text": "Don't look at me like that."},
			{"time": 1.7, "text": "I'm just the guy on the intercom."},
			{"time": 3.8, "text": "You're the one who kicked it."}
		]
	}
]

# Timed captions: text changes at playback timestamps (in seconds)
var current_captions: Array = []
var is_intro_playing: bool = false
var ledge_voiceline_played: bool = false
var ball_voiceline_played: bool = false

var available_drop_indices: Array[int] = []
var last_drop_time: float = -999.0
const DROP_COOLDOWN: float = 7.0

func _ready() -> void:
	# 1. Pause game world and physics during intro
	process_mode = Node.PROCESS_MODE_ALWAYS
	voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
	voice_player.attenuation = 0.0
	voice_player.max_distance = 100000.0
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
	
	# 3. Connect voice player finished signal
	voice_player.finished.connect(_on_voice_player_finished)
	
	# Connect NarrationArea zones
	var narration_node = get_node_or_null("NarrationArea")
	if is_instance_valid(narration_node):
		var jump_area = narration_node.get_node_or_null("JumpArea")
		if is_instance_valid(jump_area):
			jump_area.body_entered.connect(_on_jump_area_body_entered)
		var ball_area = narration_node.get_node_or_null("BallArea")
		if is_instance_valid(ball_area):
			ball_area.body_entered.connect(_on_ball_area_body_entered)
		var coworker_area = narration_node.get_node_or_null("CoworkerArea")
		if is_instance_valid(coworker_area):
			coworker_area.collision_mask = coworker_area.collision_mask | 2
			coworker_area.body_entered.connect(_on_coworker_area_body_entered)
		for child in narration_node.get_children():
			if child is Area2D and child != jump_area and child != ball_area and child != coworker_area:
				child.collision_mask = child.collision_mask | 2
				child.body_entered.connect(_on_coworker_area_body_entered)
				
	# Connect CoworkerArea zones set by user
	var cw_root = get_node_or_null("CoworkerArea")
	if is_instance_valid(cw_root):
		for child in cw_root.get_children():
			if child is Area2D:
				child.collision_mask = child.collision_mask | 2
				if not child.body_entered.is_connected(_on_coworker_area_body_entered):
					child.body_entered.connect(_on_coworker_area_body_entered)
		if cw_root is Area2D:
			cw_root.collision_mask = cw_root.collision_mask | 2
			if not cw_root.body_entered.is_connected(_on_coworker_area_body_entered):
				cw_root.body_entered.connect(_on_coworker_area_body_entered)
				
	for cw in get_tree().get_nodes_in_group("coworker_zone"):
		if cw is Area2D:
			cw.collision_mask = cw.collision_mask | 2
			if not cw.body_entered.is_connected(_on_coworker_area_body_entered):
				cw.body_entered.connect(_on_coworker_area_body_entered)
	
	# 4. Define captions for introvoiceline1
	var intro_captions = [
		{"time": 0.0, "text": "Well, howdy there, new hire. Welcome to the bottom floor."},
		{"time": 4.7, "text": "Now don't let your size fool ya, "},
		{"time": 6.7, "text": "just 'cause you're three millimeters tall don't mean you get out of unpaid overtime."},
		{"time": 12.0, "text": "Go on, stretch them little legs out with Left and Right."}
	]
	
	# 5. Start the intro voice
	is_intro_playing = true
	play_voice(INTRO_VOICE, intro_captions)

func _process(_delta: float) -> void:
	if voice_player.playing:
		_update_subtitles()
	
	if is_narrating():
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			skip_current_narration()
	
	if not is_intro_playing:
		_check_ledge_trigger()
		_check_ball_trigger()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE)):
		if is_narrating():
			skip_current_narration()
			get_viewport().set_input_as_handled()

func is_narrating() -> bool:
	return is_intro_playing or voice_player.playing

func skip_current_narration() -> void:
	if is_intro_playing:
		_on_intro_finished()
	else:
		voice_player.stop()
		subtitle_label.text = ""
		current_captions = []
		if is_instance_valid(skip_label):
			skip_label.visible = false

func _on_jump_area_body_entered(body: Node2D) -> void:
	if body == beetle:
		_trigger_ledge_voiceline()

func _check_ledge_trigger() -> void:
	if ledge_voiceline_played or not is_instance_valid(beetle):
		return
	# Column -14 ledge wall starts at X = -464; trigger right as player approaches at X >= -540
	if beetle.global_position.x >= -540.0:
		_trigger_ledge_voiceline()

func _trigger_ledge_voiceline() -> void:
	if ledge_voiceline_played:
		return
	ledge_voiceline_played = true
	if is_instance_valid(jump_controls):
		jump_controls.pop_up()
	var intro2_captions = [
		{"time": 0.0, "text": "Now the corporate ladder wasn't built for a fellow your height."},
		{"time": 4.0, "text": "Tappin' jump ain't gonna cut it here."},
		{"time": 6.5, "text": "You got to plant your feet, hold down Up to hunker real low..."},
		{"time": 11.4, "text": "...and let 'er rip when you're ready to fly!"}
	]
	play_voice(INTRO_VOICE_2, intro2_captions)

func _on_ball_area_body_entered(body: Node2D) -> void:
	if body == beetle:
		_trigger_ball_voiceline()

func _check_ball_trigger() -> void:
	if ball_voiceline_played or not is_instance_valid(beetle):
		return
	# BallArea is centered at X = -36; trigger as player approaches at X >= -70
	if beetle.global_position.x >= -70.0:
		_trigger_ball_voiceline()

func _trigger_ball_voiceline() -> void:
	if ball_voiceline_played:
		return
	ball_voiceline_played = true
	if is_instance_valid(ball_controls):
		ball_controls.pop_up()
	var intro3_captions = [
		{"time": 0.0, "text": "Look at the size of that workload now."},
		{"time": 3.0, "text": "Polite pushing will get it rolling on flat ground sure, but management wants vertical results."},
		{"time": 9.8, "text": "Cozy right up against the side of that sphere till you're doing a proper dung beetle handstand..."},
		{"time": 15.6, "text": "...then hold Up, coil them hind legs until you're shaking, and launch it up the ledges!"},
		{"time": 22.2, "text": "Just don't forget to hold Shift when you inevitably lose sight of it."}
	]
	play_voice(INTRO_VOICE_3, intro3_captions)

func _on_coworker_area_body_entered(body: Node2D) -> void:
	var ball = get_node_or_null("DungBall")
	if body == ball or body.name == "DungBall":
		if is_instance_valid(ball) and ball.has_method("trigger_coworker_event"):
			ball.trigger_coworker_event()

# ==========================================
# REUSABLE ONE-PLAYER VOICE SYSTEM
# ==========================================
func play_voice(stream: AudioStream, captions: Array = []) -> void:
	if is_instance_valid(beetle):
		voice_player.global_position = beetle.global_position
	voice_player.stop()
	voice_player.stream = stream
	current_captions = captions
	subtitle_label.text = ""
	if is_instance_valid(skip_label):
		skip_label.visible = true
	voice_player.play()

func play_drop_voiceline() -> void:
	if is_intro_playing:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_drop_time < DROP_COOLDOWN:
		return
	
	last_drop_time = current_time
	
	if available_drop_indices.is_empty():
		for i in range(DROP_VOICES.size()):
			available_drop_indices.append(i)
		available_drop_indices.shuffle()
	
	var chosen_idx = available_drop_indices.pop_back()
	var drop_data = DROP_VOICES[chosen_idx]
	play_voice(drop_data["stream"], drop_data["captions"])

func _update_subtitles() -> void:
	if current_captions.is_empty():
		return
	var pos = voice_player.get_playback_position()
	for i in range(current_captions.size() - 1, -1, -1):
		if pos >= current_captions[i]["time"]:
			subtitle_label.text = current_captions[i]["text"]
			break

func _on_voice_player_finished() -> void:
	subtitle_label.text = ""
	current_captions = []
	if is_instance_valid(skip_label):
		skip_label.visible = false
	if is_intro_playing:
		_on_intro_finished()

# ==========================================
# GAME START
# ==========================================
func _on_intro_finished() -> void:
	if not is_intro_playing:
		return
	is_intro_playing = false
	voice_player.stop()
	subtitle_label.text = ""
	current_captions = []
	if is_instance_valid(skip_label):
		skip_label.visible = false
	
	# Unpause the game immediately so the ball falls down
	get_tree().paused = false
	
	# Unlock gameplay immediately (no delay)
	if is_instance_valid(beetle):
		beetle.input_enabled = true
	
	# Pop up the wobbly controls bubble!
	if is_instance_valid(control_bubble):
		control_bubble.pop_up()
